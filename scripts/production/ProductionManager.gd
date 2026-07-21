extends Node

## ProductionManager autoload — manages production queues per player per factory type,
## handles timers, cost deduction/refund, and unit spawning on completion.

signal production_started(queue_key: String)
signal production_progress(queue_key: String, progress: float)
signal production_completed(queue_key: String, entity_data: EntityData)
signal production_cancelled(queue_key: String)
signal production_paused(queue_key: String)

## queue_key → Array[ProductionQueue]
var _queues: Dictionary = {}

## queue_key → currently building item index
var _active_index: Dictionary = {}

## queue_key → float (fractional credit accumulator for gradual deduction)
var _deduction_accums: Dictionary = {}

## queue_key → bool (true when a building completed and is waiting to be placed)
var _waiting_for_placement: Dictionary = {}

## player_id → Array[EntityData] of completed buildings waiting to be placed
var _ready_to_place: Dictionary = {}

const MAX_STACK: int = 25


func _ready() -> void:
    var bm := get_node_or_null("/root/BuildingManager")
    if bm:
        bm.build_mode_changed.connect(_on_build_mode_changed)


func _on_build_mode_changed(is_active: bool) -> void:
    if not is_active:
        # Build mode exited (ESC or placement cancelled) — unblock all queues
        for key in _waiting_for_placement:
            _waiting_for_placement[key] = false


func start_production(player_id: int, entity_data: EntityData, count: int = 1) -> bool:
    var queue_type := entity_data.buildable_queue
    if queue_type.is_empty():
        return false

    var ps := get_node("/root/PrerequisiteSystem")
    if ps and not ps.can_build(player_id, entity_data):
        return false

    # Check if player can afford (deduction happens gradually during production)
    var em := get_node("/root/EconomyManager") as EconomyManager
    if not em or not em.can_afford(player_id, entity_data.cost):
        return false

    var key := _queue_key(player_id, queue_type)
    if not _queues.has(key):
        _queues[key] = []
    var queue: Array = _queues[key]

    # Stack: increment count if last item is same entity
    if queue.size() > 0:
        var last: ProductionQueue = queue.back() as ProductionQueue
        if last.entity_data.id == entity_data.id:
            last.count = mini(last.count + count, MAX_STACK)
            production_started.emit(key)
            return true

    var item := ProductionQueue.new(entity_data, count)
    queue.append(item)

    # If this is the first item, activate it
    if queue.size() == 1:
        _active_index[key] = 0

    production_started.emit(key)
    return true


func cancel_production(player_id: int, queue_key: String, index: int, count: int = 1) -> void:
    if not _queues.has(queue_key):
        return
    var queue: Array = _queues[queue_key]
    if index < 0 or index >= queue.size():
        return
    var item: ProductionQueue = queue[index] as ProductionQueue

    # Decrement or remove
    if count >= item.count:
        # Removing entirely — refund only what was actually deducted
        var em := get_node("/root/EconomyManager") as EconomyManager
        if em and item.deducted > 0.0:
            em.add(player_id, int(item.deducted), "cancel:%s" % item.entity_data.id)
        queue.remove_at(index)
        # Adjust active index
        var active: int = _active_index.get(queue_key, 0)
        if index < active:
            _active_index[queue_key] = active - 1
        elif index == active and active >= queue.size():
            _active_index[queue_key] = maxi(0, queue.size() - 1)
    else:
        # Just decrement count — no refund for waiting items
        item.count -= count

    # Clean up empty queues
    if queue.is_empty():
        _queues.erase(queue_key)
        _active_index.erase(queue_key)
        _deduction_accums.erase(queue_key)
        _waiting_for_placement.erase(queue_key)

    production_cancelled.emit(queue_key)


func pause_production(queue_key: String, index: int) -> void:
    if not _queues.has(queue_key):
        return
    var queue: Array = _queues[queue_key]
    if index < 0 or index >= queue.size():
        return
    var item: ProductionQueue = queue[index] as ProductionQueue
    item.is_paused = true
    production_paused.emit(queue_key)


func resume_production(queue_key: String, index: int) -> void:
    if not _queues.has(queue_key):
        return
    var queue: Array = _queues[queue_key]
    if index < 0 or index >= queue.size():
        return
    var item: ProductionQueue = queue[index] as ProductionQueue
    item.is_paused = false
    production_paused.emit(queue_key)


func get_progress(queue_key: String) -> float:
    if not _queues.has(queue_key):
        return 0.0
    var queue: Array = _queues[queue_key]
    var active: int = _active_index.get(queue_key, 0)
    if active >= queue.size():
        return 0.0
    var item: ProductionQueue = queue[active] as ProductionQueue
    return item.progress


func get_queue_items(queue_key: String) -> Array:
    return _queues.get(queue_key, [])


func get_active_index(queue_key: String) -> int:
    return _active_index.get(queue_key, 0)


func get_queue_key(player_id: int, factory_type: String) -> String:
    return _queue_key(player_id, factory_type)


func _process(delta: float) -> void:
    for key in _queues.keys():
        # Don't produce next item while a building is waiting to be placed
        if _waiting_for_placement.get(key, false):
            continue

        var queue: Array = _queues[key]
        var active: int = _active_index.get(key, 0)
        if active >= queue.size():
            continue
        var item: ProductionQueue = queue[active] as ProductionQueue
        if item.is_paused:
            continue

        var speed := _get_production_speed(key)
        var build_time: float = item.entity_data.get_build_time()
        if build_time <= 0.0:
            _complete_item(key, active)
            continue

        item.progress += (delta * speed) / build_time
        production_progress.emit(key, item.progress)

        # Gradual deduction: credits per second = cost / build_time * speed
        var player_id := int(key.get_slice(":", 0))
        var deduction_rate: float = float(item.entity_data.cost) * speed / build_time
        var accum: float = _deduction_accums.get(key, 0.0) + deduction_rate * delta
        var to_deduct := int(accum)
        if to_deduct > 0:
            var em := get_node("/root/EconomyManager") as EconomyManager
            if em:
                em.deduct(player_id, to_deduct, "prod:%s" % item.entity_data.id)
                item.deducted += to_deduct
                accum -= to_deduct
        _deduction_accums[key] = accum

        if item.progress >= 1.0:
            _complete_item(key, active)


func _complete_item(key: String, index: int) -> void:
    var queue: Array = _queues[key]
    if index >= queue.size():
        return
    var item: ProductionQueue = queue[index] as ProductionQueue
    var entity_data: EntityData = item.entity_data

    # Deduct any remaining balance (avoids floating-point rounding issues)
    var player_id := int(key.get_slice(":", 0))
    var remaining := entity_data.cost - int(item.deducted)
    if remaining > 0:
        var em := get_node("/root/EconomyManager") as EconomyManager
        if em:
            em.deduct(player_id, remaining, "prod:%s" % entity_data.id)
            item.deducted += remaining

    # Decrement count
    if item.count > 1:
        item.count -= 1
        item.progress = 0.0
        item.deducted = 0.0
        _deduction_accums[key] = 0.0
    else:
        queue.remove_at(index)

    # Buildings go to ready-to-place state; units spawn immediately
    if entity_data.entity_type == EntityData.EntityType.BUILDING:
        _add_ready_to_place(player_id, entity_data)
        _waiting_for_placement[key] = true
    else:
        _spawn_unit(entity_data, player_id)

    production_completed.emit(key, entity_data)

    # Clean up empty queues
    if queue.is_empty():
        _queues.erase(key)
        _active_index.erase(key)
        _deduction_accums.erase(key)
        # Keep _waiting_for_placement until the building is actually placed
    else:
        var active: int = _active_index.get(key, 0)
        if active >= queue.size():
            _active_index[key] = maxi(0, queue.size() - 1)


func _spawn_unit(entity_data: EntityData, player_id: int) -> void:
    var factory := _find_primary_factory(player_id, entity_data.buildable_queue)
    if not factory:
        push_warning("[ProductionManager] No factory found for %s" % entity_data.id)
        return

    var unit := EntityFactory.create_entity(entity_data.id)
    if not unit:
        return

    var stats := unit.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        stats.player_id = player_id

    var spawn_cell := _find_exit_cell(factory)
    var world_pos := Pathfinder.cell_to_world(spawn_cell)
    unit.position = world_pos
    factory.get_parent().add_child(unit)


func _find_primary_factory(_player_id: int, factory_type: String) -> Node3D:
    var bm := get_node("/root/BuildingManager") as BuildingManager
    if not bm:
        return null
    for entry in bm.get_all_buildings():
        var btype: EntityData = entry.get("type") as EntityData
        if btype and btype.factory == factory_type:
            var bnode = entry.get("node")
            if bnode and bnode is Node3D:
                return bnode as Node3D
    return null


func _find_exit_cell(factory: Node3D) -> Vector2i:
    var cell := Pathfinder.world_to_cell(factory.global_position)
    for radius in range(1, 6):
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                if abs(dx) != radius and abs(dz) != radius:
                    continue
                var candidate := cell + Vector2i(dx, dz)
                var key := SpatialHash.instance._cell_key(candidate)
                if SpatialHash.instance.get_building_cells().has(key):
                    continue
                if SpatialHash.instance.is_cell_blocked(candidate):
                    continue
                var cell_type := TerrainSystem.get_cell_type(candidate)
                if cell_type != "" and cell_type != "clear":
                    continue
                return candidate
    return cell


func _get_production_speed(queue_key: String) -> float:
    var player_id := int(queue_key.get_slice(":", 0))
    var factory_type := queue_key.get_slice(":", 1)
    var count := _count_factories(player_id, factory_type)
    return 1.0 + (count - 1) * 0.25


func _count_factories(_player_id: int, factory_type: String) -> int:
    var bm := get_node("/root/BuildingManager") as BuildingManager
    if not bm:
        return 1
    var count := 0
    for entry in bm.get_all_buildings():
        var btype: EntityData = entry.get("type") as EntityData
        if btype and btype.factory == factory_type:
            count += 1
    return maxi(count, 1)


func _queue_key(player_id: int, factory_type: String) -> String:
    return "%d:%s" % [player_id, factory_type]


func _add_ready_to_place(player_id: int, entity_data: EntityData) -> void:
    if not _ready_to_place.has(player_id):
        _ready_to_place[player_id] = []
    (_ready_to_place[player_id] as Array).append(entity_data)


func get_ready_buildings(player_id: int) -> Array:
    return _ready_to_place.get(player_id, [])


func place_ready_building(player_id: int, entity_id: String) -> bool:
    if not _ready_to_place.has(player_id):
        return false
    var list: Array = _ready_to_place[player_id]
    for i in range(list.size()):
        var data: EntityData = list[i] as EntityData
        if data.id == entity_id:
            list.remove_at(i)
            if list.is_empty():
                _ready_to_place.erase(player_id)
            var bm := get_node("/root/BuildingManager") as BuildingManager
            if bm:
                bm.set_skip_next_deduction()
                bm.enter_build_mode(data)
            return true
    return false


func cancel_ready_building(player_id: int, entity_id: String) -> bool:
    if not _ready_to_place.has(player_id):
        return false
    var list: Array = _ready_to_place[player_id]
    for i in range(list.size()):
        var data: EntityData = list[i] as EntityData
        if data.id == entity_id:
            list.remove_at(i)
            if list.is_empty():
                _ready_to_place.erase(player_id)
            # Refund the full cost — production already deducted it gradually,
            # but the building was never placed, so refund entirely
            var em := get_node("/root/EconomyManager") as EconomyManager
            if em:
                em.add(player_id, data.cost, "cancel_ready:%s" % data.id)
            clear_waiting_for_placement(player_id)
            production_cancelled.emit("%d:%s" % [player_id, data.buildable_queue])
            return true
    return false


func clear_waiting_for_placement(player_id: int) -> void:
    for key in _waiting_for_placement.keys():
        if key.begins_with("%d:" % player_id):
            _waiting_for_placement[key] = false
