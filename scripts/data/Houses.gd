class_name Houses extends RefCounted

## Map houses (factions) — the rules-side house list, the analog of the
## Tiberian Sun rules.ini `[Houses]` section. Houses are factions; multiplayer
## player slots are a separate axis (their starts live in `start_locations` /
## waypoints 0-7, assigned at game setup). Placed map objects reference a house
## id from here.
##
## The ordered ids and display names are projected from the loaded
## `FactionCatalog` roster (ascending `Faction.order`), not hardcoded. The ids
## match the ownership strings shipped in `EntityData.owner` — do not introduce
## new casing.
##
## When no factions are loaded the roster is empty: `id_for` returns "" and
## `index_for` returns -1.

static var _ids: PackedStringArray = PackedStringArray()
static var _display_names: PackedStringArray = PackedStringArray()


## Replaces the roster from an ordered faction list. Called by `FactionCatalog`
## after each load; ordering is the list's order (already sorted by `order`).
static func apply_roster(factions: Array) -> void:
    var ids := PackedStringArray()
    var names := PackedStringArray()
    for faction in factions:
        var f := faction as Faction
        if f == null:
            continue
        ids.append(f.id)
        names.append(f.display_name)
    _ids = ids
    _display_names = names


## Clears the roster. Called by `FactionCatalog` on content reset.
static func clear_roster() -> void:
    _ids = PackedStringArray()
    _display_names = PackedStringArray()


## The ordered house ids, or an empty array when no roster is loaded.
## Returns a copy — packed arrays are passed by reference, so a caller must
## not be able to mutate the roster through this accessor.
static func ids() -> PackedStringArray:
    return _ids.duplicate()


## House id for a house index, or "" when out of range.
static func id_for(index: int) -> String:
    if index < 0 or index >= _ids.size():
        return ""
    return _ids[index]


## House index for a house id, or -1 when unknown.
static func index_for(house_id: String) -> int:
    return _ids.find(house_id)


## Display name for a house id, or the id itself when unknown.
static func display_name_for(house_id: String) -> String:
    var index := index_for(house_id)
    if index < 0:
        return house_id
    return _display_names[index]
