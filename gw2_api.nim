# from tables import TableRef, initTable, add, pairs
import tables
from algorithm import sorted
from httpclient import newHttpClient, get
from cgi import encodeUrl
from uri import parseUri, `/`, `$`
from json import items, JsonNode, parseJson, `[]`, `$`, hasKey
from strutils import join, replace, startsWith, `%`, intToStr, spaces
from sequtils import mapIt, toSeq

const apiURL = "https://api.guildwars2.com/v2/"

type
    RequestFailed = object of Exception
    ProfessionPlayTime = tuple
        profession: string
        playTime: int64
    Attribute = object
        typ: string
        value: BiggestInt
    EquipmentDetail = object
        id: int
        name: string
        attributes: seq[Attribute]

let skinnableSlots = @["Backpack", "Coat", "Boots", "Gloves", "Helm", "HelmAquatic",
                       "Leggings", "Shoulders", "WeaponA1", "WeaponA2",
                       "WeaponB1", "WeaponB2", "WeaponAquaticA", "WeaponAquaticB"]

proc buildRequest(endpoint: string, parameters: var Table[string, string], apiToken: string = ""): JsonNode =
    var requestURL = $(parseUri(apiURL) / endpoint)
    if apiToken.len > 0:
        parameters.add("access_token", $apiToken)
    if parameters.len > 0:
        requestURL &= "?"
        var idx = 1
        for key, val in parameters.pairs:
            requestURL &= "$#=$#" % [key, val]
            if idx != parameters.len:
                requestUrl &= "&"
            inc idx

    var client = newHttpClient()
    var resp = client.get(requestURL)
    if not resp.status.startsWith("2"):
        raise newException(RequestFailed, "$#: $#" % [requestURL, resp.status])
    return parseJson(resp.body)

proc buildRequest(endpoint: string, apiToken: string = ""): JsonNode =
    var parameters = initTable[string, string]()
    return buildRequest(endpoint, parameters, apiToken)

proc collectIds(equipment: JsonNode, key: string = "id"): seq[int] =
    result = newSeq[int]()
    for eq in equipment.elems:
        if eq.hasKey(key):
            result.add(int(eq[key].num))

proc getItemDetails(equipment: JsonNode, key: string = "id", endpoint: string = "items"): Table[int, EquipmentDetail] =
    let ids = collectIds(equipment, key)
    result = initTable[int, EquipmentDetail]()
    let strIds = ids.mapIt($it).join(",")
    if strIds.len > 0:
        var parameters = {"ids": strIds}.toTable
        let payload = buildRequest(endpoint, parameters)
        for itemNode in payload.elems:
            let id = int(itemNode["id"].num)
            var attributes = newSeq[Attribute]()
            if itemNode.hasKey("details") and itemNode["details"].hasKey("infix_upgrade"):
                for attribute in itemNode["details"]["infix_upgrade"]["attributes"]:
                    attributes.add(Attribute(typ: attribute["attribute"].str, value: attribute["modifier"].num))
            var equipment = EquipmentDetail(id: id, name: itemNode["name"].str, attributes: attributes)
            result.add(id, equipment)

proc parseCharacters(apiToken: string): seq[string] =
    let payload = buildRequest("characters", apiToken=apiToken)
    return payload.mapIt(it.str)

proc formatTime(seconds: int64): string =
    result = ""
    if seconds < 60:
        result &= "$#s" % [$ seconds]
    elif seconds < 3600:
        result &= "$#m:$#s" % [$ (seconds div 60), intToStr(seconds mod 60, 2)]
    else:
        result &= "$#h:$#m:$#s" % [$ (seconds div 3600),
                                   intToStr((seconds mod 3600) div 60, 2),
                                   intToStr(seconds mod 60, 2)]

proc getCharacterProfession(apiToken: string, characterName: string): ProfessionPlayTime =
    let
        payload = buildRequest($(parseUri("characters") / encodeUrl(characterName).replace("+", "%20")), apiToken=apiToken)
        playTime = payload["age"].num
        profession = payload["profession"].str
    return (profession, playTime)

proc getCharacterDetails(apiToken: string, characterName: string): string =
    let
        payload = buildRequest($(parseUri("characters") / encodeUrl(characterName).replace("+", "%20")), apiToken=apiToken)
        name = payload["name"].str

        deaths = payload["deaths"].num
        age = payload["age"].num
        level = payload["level"].num
        gender = payload["gender"].str
        race = payload["race"].str
        profession = payload["profession"].str
        equipment = payload["equipment"]
        equipmentDetails = getItemDetails(equipment)
        skinDetails = getItemDetails(equipment, "skin", "skins")
    var
        avgLifeSpan: int64 = 0
        res: seq[string] = newSeq[string]()

    if deaths > 0:
        avgLifeSpan = age div deaths

    res.add("$# ($#):" % [name, $ level])
    res.add("    $# $# $#" % [gender, race, profession])
    res.add("    Age: $#" % [formatTime(age)])
    res.add("    Deaths: $#" % [$ deaths])
    res.add("    Average life-span: $#" % [formatTime(avgLifeSpan)])

    res.add("    Equipment:")
    for equip in equipment:
        let
            id = int(equip["id"].num)
            slot = equip["slot"].str
        var line = "        $#:" % [slot]
        if equip.hasKey("skin"):
            let skin = int(equip["skin"].num)
            if skinDetails.hasKey(skin):
                line &= " $#" % [skinDetails[skin].name]
        if equipmentDetails.hasKey(id):
            if slot in skinnableSlots:
                line &= " ($#)" % [equipmentDetails[id].name]
            else:
                line &= " $#" % [equipmentDetails[id].name]
            var attrs = newSeq[string]()
            for attribute in equipmentDetails[id].attributes:
                attrs.add("$#: $#" % [attribute.typ, $ attribute.value])
            if attrs.len > 0:
                line &= " ($#)" % [attrs.join(", ")]
        res.add(line)
    return res.join("\n")

proc pad(a, b: string, minWidth: int): int =
    result = minWidth - a.len - b.len
    if result < 1:
        result = 1

proc getPlayTime(apiToken: string, characterNames: seq[string]): string =
    var
        playTimeByProfession = initTable[string, int64]()
        totalPlayTime: int64 = 0
        res: seq[string] = newSeq[string]()

    for characterName in characterNames:
        let
            (profession, playTime) = getCharacterProfession(apiToken, characterName)
        if playTimeByProfession.hasKey(profession):
            playTimeByProfession[profession] += playTime
        else:
            playTimeByProfession[profession] = playTime
        totalPlayTime += playTime
    let
        title = "Total play-time"
        formattedPlayTime = formatTime(totalPlayTime)
        padding = pad(title, formattedPlayTime, 30)
    res.add("$#:$#$#" % [title, spaces(padding), formattedPlayTime])
    var sortedByPlayTime = (toSeq(playTimeByProfession.pairs)
                            .sorted do (x, y: ProfessionPlayTime) -> int:
                                -cmp(x.playTime, y.playTime))
    for profession_playtime in sortedByPlayTime:
        let
            (profession, playtime) = profession_playtime
            formattedAge = formatTime(playTime)
            padding = pad(profession, formattedAge, 30)
        res.add("$#:$#$#" % [profession, spaces(padding), formattedAge])
    return res.join("\n")

when isMainModule:
    import os
    var apiToken = ""
    if paramCount() > 0:
        try:
            let apiToken = paramStr(1)
            if paramCount() > 1:
                if paramStr(2) == "--list":
                    echo parseCharacters(apiToken)
                elif paramStr(2) == "--playTime":
                    let characterNames = parseCharacters(apiToken)
                    echo getPlayTime(apiToken, characterNames)
                else:
                    let characterName = paramStr(2)
                    echo getCharacterDetails(apiToken, characterName)
            else:
                let characterNames = parseCharacters(apiToken)
                for characterName in characterNames:
                    echo getCharacterDetails(apiToken, characterName)
        except RequestFailed:
            echo "Request Failed:"
            echo getCurrentExceptionMsg()
