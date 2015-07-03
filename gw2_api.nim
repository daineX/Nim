import httpclient
import uri
import json
import strutils
import sequtils

const apiURL = "https://api.guildwars2.com/v2/"

proc buildRequest(endpoint: string, apiToken: string): Response =
    let requestURL = $(parseUri(apiURL) / endpoint)
    return request(requestURL & "?access_token=" & apiToken)

proc parseCharacters(apiToken: string): seq[string] =
    let
        resp = buildRequest("characters", apiToken)
        payload = parseJson(resp.body)
    return payload.mapIt(string, $(it.str))

proc main(apiToken: string): string =
    return parseCharacters(apiToken).join(", ")

when isMainModule:
    import os
    var apiToken = ""
    if paramCount() > 0:
        apiToken = paramStr(1)
        echo main(apiToken)
