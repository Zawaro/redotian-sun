extends Node

## PrerequisiteSystem autoload — tracks player-owned buildings and checks
## prerequisites for entity buildability.

signal prerequisites_changed(player_id: int)

## player_id → { entity_id → count }
var _player_buildings: Dictionary = {}


func register_building(player_id: int, entity_data: EntityData) -> void:
    if not _player_buildings.has(player_id):
        _player_buildings[player_id] = {}
    var buildings: Dictionary = _player_buildings[player_id]
    var eid: String = entity_data.id
    buildings[eid] = buildings.get(eid, 0) + 1
    prerequisites_changed.emit(player_id)


func unregister_building(player_id: int, entity_data: EntityData) -> void:
    if not _player_buildings.has(player_id):
        return
    var buildings: Dictionary = _player_buildings[player_id]
    var eid: String = entity_data.id
    if buildings.has(eid):
        buildings[eid] -= 1
        if buildings[eid] <= 0:
            buildings.erase(eid)
    prerequisites_changed.emit(player_id)


func can_build(player_id: int, entity_data: EntityData) -> bool:
    # Cheat mode: bypass all checks
    var debug_menu := get_tree().get_first_node_in_group("debug_menu")
    if debug_menu and debug_menu.no_prereqs:
        return true

    # Build limit check
    if entity_data.build_limit > 0:
        var count := get_build_count(player_id, entity_data.id)
        if count >= entity_data.build_limit:
            return false

    # Prerequisite (OR) — must own at least one
    if entity_data.prerequisite.size() > 0:
        var has_one := false
        if _player_buildings.has(player_id):
            for prereq in entity_data.prerequisite:
                if _player_buildings[player_id].has(prereq):
                    has_one = true
                    break
        if not has_one:
            return false

    # Prerequisite necessary (AND) — must own all
    if _player_buildings.has(player_id):
        for prereq in entity_data.prerequisite_necessary:
            if not _player_buildings[player_id].has(prereq):
                return false
    elif entity_data.prerequisite_necessary.size() > 0:
        return false

    return true


func get_build_count(player_id: int, entity_id: String) -> int:
    if not _player_buildings.has(player_id):
        return 0
    return _player_buildings[player_id].get(entity_id, 0)


func get_player_buildings(player_id: int) -> Dictionary:
    return _player_buildings.get(player_id, {})
