from json import loads
from urllib import urlencode, quote
from urllib2 import urlopen
from os.path import join as url_join

API_URL = "https://api.guildwars2.com/v2/"

def build_request(endpoint, parameters=None, api_token=""):
    if parameters is None:
        parameters = {}
    request_url = url_join(API_URL, endpoint)
    if api_token:
        parameters["access_token"] = api_token
    if parameters:
        request_url += "?" + urlencode(parameters)

    resp = urlopen(request_url)
    return loads(resp.read())

def get_equipment_details(equipment):
    details = {equip["id"]: equip for equip in equipment}
    parameters = {"ids": ",".join(str(id) for id in details.iterkeys())}

    for item in build_request("items", parameters):
        details[item["id"]].update(item)
    return details

def parse_characters(api_token):
    return build_request("characters", api_token=api_token)

def get_character_details(api_token, character_name):
    payload = build_request(url_join("characters", quote(character_name)),
                            api_token=api_token)
    name = payload["name"]

    deaths = payload["deaths"]
    age = payload["age"]
    avg_life_span = age / deaths

    level = payload["level"]
    gender = payload["gender"]
    race = payload["race"]
    profession = payload["profession"]
    equipment_details = get_equipment_details(payload["equipment"])

    res = []
    res.append("%s (%s):" % (name, level))
    res.append("    Level %s %s %s" % (gender, race, profession))
    res.append("    Average life-span: %ss" % avg_life_span)

    res.append("    Equipment:")
    for id, equip in equipment_details.iteritems():
        slot = equip["slot"]
        name = equip.get("name", id)
        res.append("         %s: %s" % (slot, name))
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
            for chracter_name in parse_characters(api_token):
                print get_character_details(api_token, character_name)
