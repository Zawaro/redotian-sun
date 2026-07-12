extends Node

const SPREAD_NEIGHBORS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(-1, 0),
    Vector2i(0, 1),
    Vector2i(0, -1),
    Vector2i(1, 1),
    Vector2i(1, -1),
    Vector2i(-1, 1),
    Vector2i(-1, -1),
]

const REBUILD_INTERVAL: float = 5.0

var _tree_timer: float = 0.0
var _tiberium_timer: float = 0.0
var _tree_batch_offset: int = 0
var _tiberium_batch_offset: int = 0
var _rebuild_timer: float = 0.0
var _cached_trees: Array = []
var _cached_tiberium: Array = []
var _map_half_diag: int = 640
var _play_area_half_diag: int = 256


func _ready() -> void:
    _find_bounds_system()
    _reset_tree_timer()
    _reset_tiberium_timer()
    _rebuild_cache()


func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    var rules := _get_rules()
    if not rules:
        return
    if not rules.tiberium_grows and not rules.tiberium_spreads:
        return

    _rebuild_timer -= delta
    if _rebuild_timer <= 0.0:
        _rebuild_timer = REBUILD_INTERVAL
        _rebuild_cache()

    _tree_timer -= delta
    if _tree_timer <= 0.0:
        _reset_tree_timer()
        _tick_tree_batch(rules)

    _tiberium_timer -= delta
    if _tiberium_timer <= 0.0:
        _reset_tiberium_timer()
        _tick_tiberium_batch(rules)


func _get_rules() -> GlobalRules:
    var ef := Engine.get_main_loop().root.get_node_or_null("EntityFactory") as EntityFactory
    if ef:
        return ef.get_global_rules()
    return null


func _find_bounds_system() -> void:
    var tree := get_tree()
    if not tree:
        return
    var root := tree.current_scene
    if not root:
        return
    var bs := root.get_node_or_null("BoundsSystem")
    if bs and bs is BoundsSystem:
        _map_half_diag = int(bs.map_size.x * Pathfinder.SQRT2 / 2.0)
        _play_area_half_diag = int(bs.visible_bounds_size.x * Pathfinder.SQRT2 / 2.0)


func _rebuild_cache() -> void:
    _cached_trees = _get_trees()
    _cached_tiberium = _get_tiberium()


func _reset_tree_timer() -> void:
    var rules := _get_rules()
    var base: float = 180.0
    if rules:
        base = rules.tree_growth_rate * 60.0
    _tree_timer = base


func _reset_tiberium_timer() -> void:
    var rules := _get_rules()
    var base: float = 300.0
    if rules:
        base = rules.growth_rate * 60.0
    _tiberium_timer = base


func _tick_tree_batch(rules: GlobalRules) -> void:
    if _cached_trees.is_empty():
        return

    var batch_size: int = rules.growth_batch_trees
    var start := _tree_batch_offset
    var end := mini(start + batch_size, _cached_trees.size())

    for i in range(start, end):
        var tree_node = _cached_trees[i]
        if is_instance_valid(tree_node):
            _process_tree(tree_node as Node3D, rules)

    _tree_batch_offset = end % maxi(_cached_trees.size(), 1)


func _tick_tiberium_batch(rules: GlobalRules) -> void:
    if _cached_tiberium.is_empty():
        return

    var batch_size: int = rules.growth_batch_crystals
    var start := _tiberium_batch_offset
    var end := mini(start + batch_size, _cached_tiberium.size())

    for i in range(start, end):
        var tib_node = _cached_tiberium[i]
        if is_instance_valid(tib_node):
            _process_tiberium(tib_node as Node3D, rules)

    _tiberium_batch_offset = end % maxi(_cached_tiberium.size(), 1)


func _process_tree(tree_node: Node3D, rules: GlobalRules) -> void:
    var tree_comp := tree_node.get_node_or_null("TiberiumTreeComponent") as TiberiumTreeComponent
    if not tree_comp:
        return
    if tree_comp.spawned_entity_id.is_empty() or tree_comp.node_count <= 0:
        return

    var tree_cell := Pathfinder.world_to_cell(tree_node.global_position)

    _spawn_in_radius(tree_comp, tree_cell, rules.tree_spawn_radius, rules)

    var radius_sq: float = float(tree_comp.radius_cells) * float(tree_comp.radius_cells)
    for tib_node in _cached_tiberium:
        if not is_instance_valid(tib_node):
            continue
        var tib_comp := tib_node.get_node_or_null("TiberiumComponent") as TiberiumComponent
        if not tib_comp or tib_comp.amount >= tib_comp.max_amount:
            continue
        var tib_cell := Pathfinder.world_to_cell(tib_node.global_position)
        var dx: float = float(tib_cell.x - tree_cell.x)
        var dz: float = float(tib_cell.y - tree_cell.y)
        if dx * dx + dz * dz > radius_sq:
            continue
        var grow_amount: int = ceili(float(tib_comp.max_amount) * 0.1)
        tib_comp.amount = mini(tib_comp.amount + grow_amount, tib_comp.max_amount)
        tib_comp._update_visual()


func _spawn_in_radius(
    tree_comp: TiberiumTreeComponent,
    center: Vector2i, radius: int, rules: GlobalRules
) -> void:
    for dx in range(-radius, radius + 1):
        for dz in range(-radius, radius + 1):
            if dx * dx + dz * dz > radius * radius:
                continue
            var cell := center + Vector2i(dx, dz)
            if not _is_in_bounds(cell):
                continue
            if _is_cell_blocked_for_tiberium(cell):
                continue
            var existing := _find_tiberium_at_cell(cell)
            if existing:
                _grow_entry(existing)
            else:
                _spawn_at_cell(cell, tree_comp, rules.spread_amount)


func _process_tiberium(tib_node: Node3D, rules: GlobalRules) -> void:
    var tib_comp := tib_node.get_node_or_null("TiberiumComponent") as TiberiumComponent
    if not tib_comp:
        return

    if tib_comp.amount < tib_comp.max_amount:
        var grow_amount: int = ceili(float(tib_comp.max_amount) * 0.05)
        tib_comp.amount = mini(tib_comp.amount + grow_amount, tib_comp.max_amount)
        tib_comp._update_visual()

    if tib_comp.spread_count < rules.spread_max:
        _try_spread_from(tib_node, tib_comp, rules)


func _try_spread_from(
    tib_node: Node3D, tib_comp: TiberiumComponent, rules: GlobalRules
) -> void:
    var tib_cell := Pathfinder.world_to_cell(tib_node.global_position)
    var neighbor: Vector2i = SPREAD_NEIGHBORS[randi() % SPREAD_NEIGHBORS.size()]
    var target_cell := tib_cell + neighbor

    if not _is_in_bounds(target_cell):
        return

    if _is_cell_blocked_for_tiberium(target_cell):
        return

    var existing := _find_tiberium_at_cell(target_cell)
    if existing:
        _grow_entry(existing)
        return

    var tree_comp := _find_nearest_tree_comp(tib_node.global_position)
    if not tree_comp:
        return

    _spawn_at_cell(target_cell, tree_comp, rules.spread_amount)
    tib_comp.spread_count += 1


func _find_nearest_tree_comp(world_pos: Vector3) -> TiberiumTreeComponent:
    var nearest: TiberiumTreeComponent = null
    var best_dist_sq: float = INF
    for tree in _cached_trees:
        if not is_instance_valid(tree):
            continue
        var d_sq: float = world_pos.distance_squared_to(tree.global_position)
        if d_sq < best_dist_sq:
            best_dist_sq = d_sq
            nearest = tree.get_node_or_null("TiberiumTreeComponent") as TiberiumTreeComponent
    return nearest


func _spawn_at_cell(cell: Vector2i, tree_comp: TiberiumTreeComponent, amount: int) -> void:
    var entity := EntityFactory.create_entity(
        tree_comp.spawned_entity_id,
        {
            "tiberium_amount": amount,
            "tiberium_max_amount": tree_comp.max_amount_per_node,
            "tiberium_type": tree_comp.tiberium_type,
            "tiberium_regrowth_rate": tree_comp.regrowth_rate,
        }
    )
    if not entity:
        return

    var world_pos := Pathfinder.cell_to_world(cell)
    entity.position = world_pos
    if not _cached_trees.is_empty():
        var first_tree = _cached_trees[0]
        if is_instance_valid(first_tree):
            var parent: Node = (first_tree as Node3D).get_parent() as Node
            if parent:
                parent.add_child(entity)


func _grow_entry(entry: Dictionary) -> void:
    var tib_node: Node3D = entry.get("node")
    if tib_node:
        var tib_comp := tib_node.get_node_or_null("TiberiumComponent") as TiberiumComponent
        if tib_comp and tib_comp.amount < tib_comp.max_amount:
            var grow_amount: int = ceili(float(tib_comp.max_amount) * 0.1)
            tib_comp.amount = mini(tib_comp.amount + grow_amount, tib_comp.max_amount)
            tib_comp._update_visual()


func _find_tiberium_entry(entries: Array) -> Dictionary:
    for entry in entries:
        var node: Node3D = entry.get("node")
        if is_instance_valid(node) and node.get_node_or_null("TiberiumComponent"):
            return entry
    return {}


func _find_tiberium_at_cell(cell: Vector2i) -> Dictionary:
    for entity in get_tree().get_nodes_in_group("tiberium"):
        if not is_instance_valid(entity):
            continue
        var ecell := Pathfinder.world_to_cell(entity.global_position)
        if ecell == cell:
            return {"node": entity}
    return {}


func _is_in_bounds(cell: Vector2i) -> bool:
    var cx := absf(float(cell.x) + 0.5)
    var cz := absf(float(cell.y) + 0.5)
    return cx + cz <= float(_play_area_half_diag)


func _is_cell_blocked_for_tiberium(cell: Vector2i) -> bool:
    if not SpatialHash.instance:
        return false
    var key: int = SpatialHash.instance._cell_key(cell)
    if SpatialHash.instance._building_cells.has(key):
        return true
    if SpatialHash.instance._bib_cells.has(key):
        return true
    if SpatialHash.instance.is_cell_blocked(cell):
        return true
    return false


func _get_trees() -> Array:
    return get_tree().get_nodes_in_group("tiberium_trees")


func _get_tiberium() -> Array:
    return get_tree().get_nodes_in_group("tiberium")
