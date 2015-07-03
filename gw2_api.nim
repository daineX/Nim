import httpclient
import uri
import json
import strutils

const apiURL = "https://api.guildwars2.com/v2/"

proc buildRequest(endpoint: string, apiToken: string): Response =
    let requestURL = $(parseUri(apiURL) / endpoint)
    return request(requestURL & "?access_token=" & apiToken)

proc parseCharacters(apiToken: string): seq[string] =
    let
        resp = buildRequest("characters", apiToken)
        payload = parseJson(resp.body)
    var res =  newSeq[string]()
    for name in payload:
        res.add(name.str)
    return res

proc main(apiToken: string): string =
    return parseCharacters(apiToken).join(", ")

when isMainModule:
    import os
    var apiToken = ""
    if paramCount() > 0:
        apiToken = paramStr(1)
        echo main(apiToken)
