class_name CellReservation extends Node

## Single source of truth for in-flight infantry sub-slot claims.
## Present occupancy is derived from the SpatialHash grid; this registry holds
## claims only for units en route to a cell (the "coming" half of the split).

const NUM_SLOTS: int = CellSubPositions.NUM_SLOTS

static var instance: CellReservation

var _claims: Dictionary = {}
var _connected_owners: Dictionary = {}


func _enter_tree() -> void:
    instance = self


func reserve_sub_slot(cell: Vector2i, owner: Node3D, preferred_slot: int = -1) -> int:
    var key := CellUtil.cell_key(cell)
    var cell_claims: Array = _claims.get(key, [])
    for i in cell_claims.size():
        if cell_claims[i] == owner:
            return i
    release_all(owner)
    cell_claims = _claims.get(key, [])
    var slot: int = preferred_slot
    if slot < 0 or not _is_slot_free(cell, owner, slot):
        slot = _first_free_slot(cell, owner)
    if slot < 0:
        return -1
    while cell_claims.size() <= slot:
        cell_claims.append(null)
    cell_claims[slot] = owner
    _claims[key] = cell_claims
    _connect_cleanup(owner)
    return slot


func release_sub_slot(cell: Vector2i, owner: Node3D) -> void:
    var key := CellUtil.cell_key(cell)
    if not _claims.has(key):
        return
    var cell_claims: Array = _claims[key]
    var changed := false
    for i in cell_claims.size():
        if cell_claims[i] == owner:
            cell_claims[i] = null
            changed = true
    if changed and not _has_valid_claim(cell_claims):
        _claims.erase(key)


func release_all(owner: Node3D) -> void:
    for key in _claims.keys():
        var cell_claims: Array = _claims[key]
        var changed := false
        for i in cell_claims.size():
            if cell_claims[i] == owner:
                cell_claims[i] = null
                changed = true
        if changed and not _has_valid_claim(cell_claims):
            _claims.erase(key)


func clear() -> void:
    _claims.clear()


func get_slot_owner(cell: Vector2i, slot: int) -> Node3D:
    var cell_claims: Array = _claims.get(CellUtil.cell_key(cell), [])
    if slot < 0 or slot >= cell_claims.size():
        return null
    var owner = cell_claims[slot]
    if owner and is_instance_valid(owner):
        return owner as Node3D
    return null


func get_available_sub_slot(cell: Vector2i) -> int:
    for i in NUM_SLOTS:
        if get_slot_owner(cell, i) == null:
            return i
    return -1


func get_claim_count(cell: Vector2i) -> int:
    return _valid_claim_count(_claims.get(CellUtil.cell_key(cell), []))


func is_cell_full(cell: Vector2i) -> bool:
    var idle := 0
    if SpatialHash.instance:
        idle = SpatialHash.instance.get_infantry_count(cell)
    return idle + get_claim_count(cell) >= NUM_SLOTS


func _first_free_slot(cell: Vector2i, owner: Node3D) -> int:
    for i in NUM_SLOTS:
        if _is_slot_free(cell, owner, i):
            return i
    return -1


func _is_slot_free(cell: Vector2i, owner: Node3D, slot: int) -> bool:
    if get_slot_owner(cell, slot) != null:
        return false
    if not SpatialHash.instance:
        return true
    for entry in SpatialHash.instance.get_entries(cell):
        if entry["node"] == owner:
            continue
        var mc: Node = entry["mc"]
        if mc and mc.has_method("get_assigned_slot") and int(mc.get_assigned_slot()) == slot:
            return false
    return true


func _valid_claim_count(cell_claims: Array) -> int:
    var count := 0
    for owner in cell_claims:
        if owner and is_instance_valid(owner):
            count += 1
    return count


func _has_valid_claim(cell_claims: Array) -> bool:
    for owner in cell_claims:
        if owner and is_instance_valid(owner):
            return true
    return false


func _connect_cleanup(owner: Node3D) -> void:
    if _connected_owners.has(owner):
        return
    owner.tree_exited.connect(_on_owner_freed.bind(owner))
    _connected_owners[owner] = true


func _on_owner_freed(owner: Node3D) -> void:
    release_all(owner)
    _connected_owners.erase(owner)
