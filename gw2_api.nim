# from tables import TableRef, initTable, add, pairs
import tables
from httpclient import request
from uri import parseUri, `/`, `$`
from json import items, JsonNode, parseJson, `[]`, `$`, hasKey
from strutils import join, replace, startsWith, `%`, intToStr
from sequtils import mapIt

const apiURL = "https://api.guildwars2.com/v2/"

type RequestFailed = object of Exception

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

    var resp = request(requestURL)
    if not resp.status.startsWith("2"):
        raise newException(RequestFailed, resp.status)
    return parseJson(resp.body)

proc buildRequest(endpoint: string, apiToken: string = ""): JsonNode =
    var parameters = initTable[string, string]()
    return buildRequest(endpoint, parameters, apiToken)

proc collectIds(equipment: JsonNode, key: string = "id"): seq[int] =
    result = newSeq[int]()
    for eq in equipment.elems:
        if eq.hasKey(key):
            result.add(int(eq[key].num))

proc getItemDetails(equipment: JsonNode, key: string = "id", endpoint: string = "items"): Table[int, string] =
    let ids = collectIds(equipment, key)
    result = initTable[int, string]()
    let strIds = ids.mapIt(string, $it).join(",")
    if strIds.len > 0:
        var parameters = {"ids": strIds}.toTable
        let payload = buildRequest(endpoint, parameters)
        for itemNode in payload.elems:
            result.add(int(itemNode["id"].num), itemNode["name"].str)

proc parseCharacters(apiToken: string): seq[string] =
    let payload = buildRequest("characters", apiToken=apiToken)
    return payload.mapIt(string, it.str)

let skinnableSlots = @["Backpack", "Coat", "Boots", "Gloves", "Helm", "HelmAquatic",
                       "Leggings", "Shoulders", "WeaponA1", "WeaponA2",
                       "WeaponB1", "WeaponB2", "WeaponAquaticA", "WeaponAquaticB"]

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

proc getCharacterDetails(apiToken: string, characterName: string): string =
    let
        payload = buildRequest($(parseUri("characters") / characterName.replace(" ", "%20")), apiToken=apiToken)
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
    res.add("    Level $# $# $#" % [gender, race, profession])
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
                line &= " $#" % [skinDetails[skin]]
        if equipmentDetails.hasKey(id):
            if slot in skinnableSlots:
                line &= " ($#)" % [equipmentDetails[id]]
            else:
                line &= " $#" % [equipmentDetails[id]]
        res.add(line)
    return res.join("\n")

when isMainModule:
    import os
    var apiToken = ""
    if paramCount() > 0:
        try:
            let apiToken = paramStr(1)
            if paramCount() > 1:
                let characterName = paramStr(2)
                echo getCharacterDetails(apiToken, characterName)
            else:
                let characterNames = parseCharacters(apiToken)
                for characterName in characterNames:
                    echo getCharacterDetails(apiToken, characterName)
        except RequestFailed:
            echo "Request Failed:"
            echo getCurrentExceptionMsg()
