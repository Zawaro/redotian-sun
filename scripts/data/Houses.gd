class_name Houses extends RefCounted

## Map houses (factions) — the rules-side house list, the analog of the
## Tiberian Sun rules.ini `[Houses]` section: `0=GDI, 1=Nod, 2=Neutral,
## 3=Special`. Houses are factions; multiplayer player slots are separate
## (their starts live in `start_locations` / waypoints 0-7). Placed map
## objects reference a house id from here.

enum House { GDI, NOD, NEUTRAL, SPECIAL }

const IDS: PackedStringArray = ["gdi", "nod", "neutral", "special"]
const DISPLAY_NAMES: PackedStringArray = ["GDI", "Nod", "Neutral", "Special"]


## House id for a house index, or "" when out of range.
static func id_for(index: int) -> String:
    if index < 0 or index >= IDS.size():
        return ""
    return IDS[index]


## House index for a house id, or -1 when unknown.
static func index_for(house_id: String) -> int:
    return IDS.find(house_id)


## Display name for a house id, or the id itself when unknown.
static func display_name_for(house_id: String) -> String:
    var index := index_for(house_id)
    if index < 0:
        return house_id
    return DISPLAY_NAMES[index]
