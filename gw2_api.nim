# from tables import TableRef, initTable, add, pairs
import tables
from httpclient import request
from uri import parseUri, `/`, `$`
from json import items, JsonNode, parseJson, `[]`
from strutils import join, replace, `%`
from sequtils import mapIt

const apiURL = "https://api.guildwars2.com/v2/"

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
    return parseJson(resp.body)

proc buildRequest(endpoint: string, apiToken: string = ""): JsonNode =
    var parameters = initTable[string, string]()
    return buildRequest(endpoint, parameters, apiToken)

proc getItemDetails(ids: seq[int]): Table[int, string] =
    let strIds = ids.mapIt(string, $it).join(",")
    var parameters = {"ids": strIds}.toTable
    result = initTable[int, string]()

    let payload = buildRequest("items", parameters)
    for itemNode in payload.elems:
        result.add(int(itemNode["id"].num), itemNode["name"].str)

proc parseCharacters(apiToken: string): seq[string] =
    let payload = buildRequest("characters", apiToken=apiToken)
    return payload.mapIt(string, it.str)

proc getCharacterDetails(apiToken: string, characterName: string): string =
    let
        payload = buildRequest($(parseUri("characters") / characterName.replace(" ", "%20")), apiToken=apiToken)
        name = payload["name"].str

        deaths = payload["deaths"].num
        age = payload["age"].num
        avgLifeSpan = age div deaths

        level = payload["level"].num
        gender = payload["gender"].str
        race = payload["race"].str
        profession = payload["profession"].str
        equipment = payload["equipment"]
        equipmentDetails = getItemDetails(equipment.mapIt(int, int(it["id"].num)))
    var
        res: seq[string] = newSeq[string]()

    res.add("$# ($#):" % [name, $ level])
    res.add("    Level $# $# $#" % [gender, race, profession])
    res.add("    Average life-span: $#s" % [$avgLifeSpan])

    res.add("    Equipment:")
    for equip in equipment:
        let
            id = int(equip["id"].num)
            slot = equip["slot"].str
            name = equipmentDetails[id]
        if equipmentDetails.hasKey(id):
            res.add("        $#: $#" % [slot, name])
        else:
            res.add("        $#: $#" % [slot, $ id])
    return res.join("\n")

when isMainModule:
    import os
    var apiToken = ""
    if paramCount() > 0:
        let apiToken = paramStr(1)
        if paramCount() > 1:
            let characterName = paramStr(2)
            echo getCharacterDetails(apiToken, characterName)
        else:
            let characterNames = parseCharacters(apiToken)
            for characterName in characterNames:
                echo getCharacterDetails(apiToken, characterName)
