class_name CellReservation extends Node

## Single source of truth for in-flight sharer sub-slot claims.
## Present occupancy is derived from the SpatialHash grid; this registry holds
## claims only for units en route to a cell (the "coming" half of the split).

static var instance: CellReservation

var _claims: Dictionary = {}
var _claimant_cells: Dictionary = {}


func _enter_tree() -> void:
    instance = self


func reserve_sub_slot(cell: Vector2i, claimant: Node3D, preferred_slot: int = -1) -> int:
    var key := CellUtil.cell_key(cell)
    var cell_claims: Array = _claims.get(key, [])
    for i in cell_claims.size():
        if cell_claims[i] == claimant:
            return i
    release_all(claimant)
    cell_claims = _claims.get(key, [])
    var slot: int = preferred_slot
    if slot < 0 or not _is_slot_free(cell, claimant, slot):
        slot = _first_free_slot(cell, claimant)
    if slot < 0:
        return -1
    while cell_claims.size() <= slot:
        cell_claims.append(null)
    cell_claims[slot] = claimant
    _claims[key] = cell_claims
    _track_cell(claimant, key)
    _connect_cleanup(claimant)
    return slot


func release_sub_slot(cell: Vector2i, claimant: Node3D) -> void:
    _remove_claimant_from_cell(CellUtil.cell_key(cell), claimant)


func release_all(claimant: Node3D) -> void:
    var cells: Dictionary = _claimant_cells.get(claimant, {})
    for key in cells.keys():
        _remove_claimant_from_cell(key, claimant)
    _claimant_cells.erase(claimant)


func clear() -> void:
    _claims.clear()
    _claimant_cells.clear()


func get_slot_owner(cell: Vector2i, slot: int) -> Node3D:
    var cell_claims: Array = _claims.get(CellUtil.cell_key(cell), [])
    if slot < 0 or slot >= cell_claims.size():
        return null
    var claimant = cell_claims[slot]
    if claimant and is_instance_valid(claimant):
        return claimant as Node3D
    return null


func get_available_sub_slot(cell: Vector2i) -> int:
    for i in CellSubPositions.get_slot_count():
        if get_slot_owner(cell, i) == null:
            return i
    return -1


func get_claim_count(cell: Vector2i) -> int:
    return _valid_claim_count(_claims.get(CellUtil.cell_key(cell), []))


func is_cell_full(cell: Vector2i) -> bool:
    var idle := 0
    if SpatialHash.instance:
        idle = SpatialHash.instance.get_shared_cell_count(cell)
    return idle + get_claim_count(cell) >= CellSubPositions.get_slot_count()


func _first_free_slot(cell: Vector2i, claimant: Node3D) -> int:
    for i in CellSubPositions.get_slot_count():
        if _is_slot_free(cell, claimant, i):
            return i
    return -1


func _is_slot_free(cell: Vector2i, claimant: Node3D, slot: int) -> bool:
    if get_slot_owner(cell, slot) != null:
        return false
    if not SpatialHash.instance:
        return true
    for entry in SpatialHash.instance.get_entries(cell):
        if entry["node"] == claimant:
            continue
        var mc: Node = entry["mc"]
        if not mc or not mc.has_method("get_assigned_slot"):
            continue
        # MOVING/WAIT units are covered by their claim, not their position.
        if mc.has_method("is_moving") and mc.is_moving():
            continue
        if int(mc.get_assigned_slot()) == slot:
            return false
    return true


func _valid_claim_count(cell_claims: Array) -> int:
    var count := 0
    for claimant in cell_claims:
        if claimant and is_instance_valid(claimant):
            count += 1
    return count


func _has_valid_claim(cell_claims: Array) -> bool:
    for claimant in cell_claims:
        if claimant and is_instance_valid(claimant):
            return true
    return false


func _remove_claimant_from_cell(key: int, claimant: Node3D) -> void:
    if not _claims.has(key):
        return
    var cell_claims: Array = _claims[key]
    var changed := false
    for i in cell_claims.size():
        if cell_claims[i] == claimant:
            cell_claims[i] = null
            changed = true
    if changed:
        if not _has_valid_claim(cell_claims):
            _claims.erase(key)
        _forget_cell(claimant, key)


func _track_cell(claimant: Node3D, key: int) -> void:
    if not _claimant_cells.has(claimant):
        _claimant_cells[claimant] = {}
    _claimant_cells[claimant][key] = true


func _forget_cell(claimant: Node3D, key: int) -> void:
    if not _claimant_cells.has(claimant):
        return
    var cells: Dictionary = _claimant_cells[claimant]
    cells.erase(key)
    if cells.is_empty():
        _claimant_cells.erase(claimant)


func _connect_cleanup(claimant: Node3D) -> void:
    # Every move order re-reserves while the owner stays in the tree; a fresh
    # bind compares equal to the stored connection, so this is the dedupe.
    if claimant.tree_exited.is_connected(_on_owner_freed.bind(claimant)):
        return
    claimant.tree_exited.connect(_on_owner_freed.bind(claimant))


func _on_owner_freed(claimant: Node3D) -> void:
    # One connection per owner lifetime: leaving the tree (e.g. boarding a
    # transport) drops the claims AND the cleanup hook; a later re-add re-arms
    # it via reserve_sub_slot, so the connect never doubles up.
    claimant.tree_exited.disconnect(_on_owner_freed.bind(claimant))
    release_all(claimant)
