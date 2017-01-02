# from tables import TableRef, initTable, add, pairs
import tables
from algorithm import sorted
from httpclient import newHttpClient, get
from cgi import encodeUrl
from uri import parseUri, `/`, `$`
from json import items, JsonNode, parseJson, `[]`, `{}`, `$`, hasKey, JArray
from strutils import join, replace, startsWith, `%`, intToStr, spaces
from sequtils import mapIt, toSeq, concat, deduplicate, distribute

const apiURL = "https://api.guildwars2.com/v2/"

type
    RequestFailed = object of Exception
    ProfessionPlayTime = tuple
        profession: string
        playTime: int64
    Attribute = object
        typ: string
        value: BiggestInt
    LoadoutDetail = object
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

proc collectIds(character: JsonNode, loadoutKey: string = "equipment", key: string = "id"): seq[int] =
    var ids = newSeq[int]()
    try:
        let loadout = character[loadoutKey]
        if loadout.kind == JArray:
            for ld in loadout.elems:
                if ld.hasKey(key):
                    ids.add(int(ld[key].num))
        else:
            ids.add(int(loadout.num))
    except KeyError:
        discard
    return ids

proc getLoadoutDetails(ids: seq[int], endpoint: string): Table[int, LoadoutDetail] =
    result = initTable[int, LoadoutDetail]()
    var numSubs = ids.len div 100
    if numSubs == 0:
        numSubs = 1
    for subIds in distribute(ids, numSubs):
        let strIds = subIds.mapIt($it).join(",")
        if strIds.len > 0:
            var parameters = {"ids": strIds}.toTable
            let payload = buildRequest(endpoint, parameters)
            for itemNode in payload.elems:
                let id = int(itemNode["id"].num)
                var attributes = newSeq[Attribute]()
                if itemNode.hasKey("details") and itemNode["details"].hasKey("infix_upgrade"):
                    for attribute in itemNode["details"]["infix_upgrade"]["attributes"]:
                        attributes.add(Attribute(typ: attribute["attribute"].str, value: attribute["modifier"].num))
                var loadout = LoadoutDetail(id: id, name: itemNode["name"].str, attributes: attributes)
                result.add(id, loadout)

proc collectLoadoutDetails(characters: seq[JsonNode], loadoutKey: string = "equipment", key: string = "id", endpoint: string = "items"): Table[int, LoadoutDetail] =
    var ids = newSeq[int]();
    for character in characters:
        ids = ids.concat(collectIds(character, loadoutKey, key))
    return getLoadoutDetails(deduplicate(ids), endpoint)

proc collectItemDetails(characters: seq[JsonNode]): Table[int, LoadoutDetail] =
    return collectLoadoutDetails(characters)

proc collectSkinDetails(characters: seq[JsonNode]): Table[int, LoadoutDetail] =
    return collectLoadoutDetails(characters, "equipment", "skin", "skins")

proc collectTitleDetails(characters: seq[JsonNode]): Table[int, LoadoutDetail] =
    return collectLoadoutDetails(characters, "title", "id", "titles")

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

proc getAllCharacters(apiToken: string): seq[JsonNode] =
    var parameters = {"page": "0"}.toTable
    return buildRequest("characters", parameters, apiToken=apiToken).elems

proc getCharacterNames(apiToken: string): seq[string] =
    return getAllCharacters(apiToken).mapIt($it["name"])

proc getCharacter(apiToken: string, name: string): JsonNode =
    return buildRequest($(parseUri("characters") / encodeUrl(name).replace("+", "%20")), apiToken=apiToken)

proc getCharacterProfession(payload: JsonNode): ProfessionPlayTime =
    let
        playTime = payload["age"].num
        profession = payload["profession"].str
    return (profession, playTime)

proc formatCharacterDetails(character: JsonNode,
                            equipmentDetails: Table[int, LoadoutDetail],
                            skinDetails: Table[int, LoadoutDetail],
                            titleDetails: Table[int, LoadoutDetail]): string =
    let
        name = character["name"].str

        deaths = character["deaths"].num
        age = character["age"].num
        level = character["level"].num
        gender = character["gender"].str
        race = character["race"].str
        profession = character["profession"].str
        equipment = character["equipment"]
        titleKey = character{"title"}
    var
        avgLifeSpan: int64 = 0
        res: seq[string] = newSeq[string]()
        title = ""
        titleId = 0

    if deaths > 0:
        avgLifeSpan = age div deaths

    if not titleKey.isNil:
        titleId = int(titleKey.num)
    if titleDetails.hasKey(titleId):
        title = titleDetails[titleId].name
        res.add("\"$#\" $# ($#):" % [title, name, $ level])
    else:
        res.add("$# ($#):" % [name, $ level])

    res.add("    $# $# $#" % [gender, race, profession])
    res.add("    Playtime: $#" % [formatTime(age)])
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

proc getPlayTime(allCharacters: seq[JsonNode]): string =
    var
        playTimeByProfession = initTable[string, int64]()
        totalPlayTime: int64 = 0
        res: seq[string] = newSeq[string]()

    for character in allCharacters:
        let
            (profession, playTime) = getCharacterProfession(character)
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
                    echo getCharacterNames(apiToken)
                elif paramStr(2) == "--playTime":
                    echo getPlayTime(getAllCharacters(apiToken))
                else:
                    let
                        characterName = paramStr(2)
                        character = getCharacter(apiToken, characterName)
                    var characters = newSeq[JsonNode]()
                    characters.add(character)
                    let
                        itemDetails = collectItemDetails(characters)
                        skinDetails = collectSkinDetails(characters)
                        titleDetails = collectTitleDetails(characters)
                    echo formatCharacterDetails(character, itemDetails, skinDetails, titleDetails)
            else:
                let
                    characters = getAllCharacters(apiToken)
                    itemDetails = collectItemDetails(characters)
                    skinDetails = collectSkinDetails(characters)
                    titleDetails = collectTitleDetails(characters)
                for character in characters:
                    echo formatCharacterDetails(character, itemDetails, skinDetails, titleDetails)
        except RequestFailed:
            echo "Request Failed:"
            echo getCurrentExceptionMsg()
