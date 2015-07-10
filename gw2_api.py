from json import loads
from urllib import urlencode
from urllib2 import urlopen
from os.path import join as url_join




API_URL = "https://api.guildwars2.com/v2/"

def build_request(endpoint, parameters=None, api_token=""):
    if parameters is None: parameters = {}
    request_url = url_join(API_URL, endpoint)
    if api_token:
        parameters["access_token"] = api_token
    if parameters:
        request_url += "?" + urlencode(parameters)


    print request_url, parameters



    resp = urlopen(request_url)
    return loads(resp.read())





def get_item_details(ids):
    parameters = {"ids": ",".join(str(id) for id in ids)}
    res = {}

    payload = build_request("items", parameters)
    for item_node in payload:
        res[item_node["id"]] = item_node["name"]
    return res

def parse_characters(api_token):
    payload = build_request("characters", api_token=api_token)
    return payload

def get_character_details(api_token, character_name):
    payload = build_request(url_join("characters", character_name.replace(" ", "%20")),
                            api_token=api_token)
    name = payload["name"]

    deaths = payload["deaths"]
    age = payload["age"]
    avg_life_span = age / deaths

    level = payload["level"]
    gender = payload["gender"]
    race = payload["race"]
    profession = payload["profession"]
    equipment = payload["equipment"]
    equipment_details = get_item_details([node["id"] for node in equipment])

    res = []

    res.append("%s (%s):" % (name, level))
    res.append("    Level %s %s %s" % (gender, race, profession))
    res.append("    Average life-span: %ss" % avg_life_span)

    res.append("    Equipment:")
    for equip in equipment:

        id = equip["id"]
        slot = equip["slot"]
        name = equipment_details.get(id)
        if equipment_details.has_key(id):
            res.append("         %s: %s" % (slot, name))
        else:
            res.append("         %s: %s" % (slot, id))
    return "\n".join(res)

if __name__ == "__main__":
    import sys
    api_token = ""
    if len(sys.argv) > 1:
        api_token = sys.argv[1]
        if len(sys.argv) > 2:
            character_name = sys.argv[2]
            print get_character_details(api_token, character_name)
        else:
            character_names = parse_characters(api_token)
            for chracter_name in character_names:
                print get_character_details(api_token, character_name)
