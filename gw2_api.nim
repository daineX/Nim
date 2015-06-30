import httpclient
import uri

const apiURL = "https://api.guildwars2.com/v2/"

proc buildRequest(endpoint: string, apiToken: string): Response =
    let requestURL = $(parseUri(apiURL) / endpoint)
    echo requestURL
    return request(requestURL & "?access_token=" & apiToken)

proc main(apiToken: string): string =
    let resp = buildRequest("account", apiToken)
    return resp.body

when isMainModule:
    import os
    var apiToken = ""
    if paramCount() > 0:
        apiToken = paramStr(1)
        echo main(apiToken)
