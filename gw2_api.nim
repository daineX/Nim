from httpclient import request
from uri import parseUri, `/`, `$`
from json import items, JsonNode, parseJson, `[]`
from strutils import join, replace, `%`
from sequtils import mapIt

const apiURL = "https://api.guildwars2.com/v2/"

proc buildRequest(endpoint: string, apiToken: string): JsonNode =
    let
        requestURL = $(parseUri(apiURL) / endpoint)
        resp = request(requestURL & "?access_token=" & apiToken)
    return parseJson(resp.body)

proc parseCharacters(apiToken: string): seq[string] =
    let
        payload = buildRequest("characters", apiToken)
    return payload.mapIt(string, it.str)

proc getCharacterDetails(apiToken: string, characterName: string): string =
    let
        payload = buildRequest($(parseUri("characters") / characterName.replace(" ", "%20")), apiToken)
        name = payload["name"].str

        deaths = payload["deaths"].num
        age = payload["age"].num
        avgLifeSpan = age div deaths

        level = payload["level"].num
        gender = payload["gender"].str
        race = payload["race"].str
        profession = payload["profession"].str
    var
        res: seq[string] = newSeq[string]()
    res.add("$# ($#):" % [name, $ level])
    res.add("\tLevel $# $# $#" % [gender, race, profession])
    res.add("\tAverage life-span: $#s" % [$avgLifeSpan])

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
