extends Node

signal selection_changed(selected_entities: Array[SelectComponent])
signal hover_changed(entity: SelectComponent)

const CELL_SIZE: float = 2.0

var selected_entities: Array[SelectComponent] = []
var is_hovering: bool = false
var hovered_entity: SelectComponent = null

func _ready():
    if not Engine.is_editor_hint():
        print("✅ SelectionManager loaded successfully!")

func select_entity(entity: SelectComponent, shift_pressed: bool = false):
    if not entity:
        return
    
    # Shift pressed + already selected: toggle off (deselect)
    if shift_pressed and entity in selected_entities:
        remove_entity(entity)
        return
    
    # Shift pressed + not selected: add to selection (multi-select)
    if shift_pressed:
        add_entity(entity)
    else:
        deselect_all()
        add_entity(entity)

func deselect_entity(entity: SelectComponent):
    remove_entity(entity)

func deselect_all():
    for entity in selected_entities:
        if entity.has_method("set_is_selected"):
            entity.set_is_selected(false)
    selected_entities.clear()
    emit_signal("selection_changed", [])

func add_entity(entity: SelectComponent):
    if entity and not selected_entities.has(entity):
        selected_entities.append(entity)
        
        # Enable selection visuals via method call
        if entity.has_method("set_is_selected"):
            entity.set_is_selected(true)
            
        emit_signal("selection_changed", selected_entities.duplicate())

func remove_entity(entity: SelectComponent):
    if entity in selected_entities:
        selected_entities.erase(entity)
        
        # Disable selection visuals via method call
        if entity.has_method("set_is_selected"):
            entity.set_is_selected(false)
            
        emit_signal("selection_changed", selected_entities.duplicate())

func toggle_entity(entity: SelectComponent):
    if entity in selected_entities:
        remove_entity(entity)
    else:
        add_entity(entity)

func set_hover_preview(enabled: bool, entity: SelectComponent = null):
    is_hovering = enabled
    
    # Deselect previous hover target
    if hovered_entity and hovered_entity != entity:
        hovered_entity.set_is_hovering(false)
        hovered_entity = null
        
    if enabled and entity:
        hovered_entity = entity
        hovered_entity.set_is_hovering(true)
        emit_signal("hover_changed", entity)

func clear_hover_preview():
    set_hover_preview(false, null)


# Task 3.2: Public method to broadcast move command to all selected entities with MovementController.
## Iterates over existing selection data structure — no new tracking structures introduced.
func request_move(target_position: Vector3) -> void:
    var offsets := _compute_spread(selected_entities.size(), CELL_SIZE)
    for i in selected_entities.size():
        _on_request_move(selected_entities[i], target_position + offsets[i])


# Task 3.3: Private method to forward move command from SelectionManager to individual entities.
## Finds the parent node of select_component, checks for MovementController child, calls set_target_position.
func _on_request_move(select_comp: SelectComponent, position: Vector3) -> void:
    var parent := select_comp.get_parent() as Node
    if not is_instance_valid(parent):
        return
    
    # Task 3.4 (partial): Entities without MovementController are silently skipped — no error or crash.
    if not parent.has_node("MovementController"):
        return
    
    var movement_controller = parent.get_node("MovementController")
    if is_instance_valid(movement_controller):
        movement_controller.set_target_position(position)


func is_entity_selected(entity: SelectComponent) -> bool:
    return selected_entities.has(entity)

func get_selected_entities():
    return selected_entities


## Compute cell-aligned spiral offsets so each unit gets its own destination.
## Cards are filled before diagonals within each ring layer.
func _compute_spread(count: int, cell_size: float) -> Array[Vector3]:
    var offsets: Array[Vector3] = [Vector3.ZERO]
    if count <= 1:
        return offsets

    var radius := 1
    while offsets.size() < count:
        # Cardinals first: up, down, left, right (relative to ring origin)
        var cardinals := [
            Vector3(radius, 0, 0),
            Vector3(-radius, 0, 0),
            Vector3(0, 0, radius),
            Vector3(0, 0, -radius),
        ]
        for off in cardinals:
            offsets.append(off * cell_size)
            if offsets.size() >= count:
                break
        if offsets.size() >= count:
            break

        # Diagonals: fill remaining positions in this ring layer
        for dx in range(-radius, radius + 1):
            var clamped := false
            for dz in range(-radius, radius + 1):
                if abs(dx) == radius and abs(dz) == radius:
                    offsets.append(Vector3(dx, 0, dz) * cell_size)
                    if offsets.size() >= count:
                        clamped = true
                        break
            if clamped:
                break

        radius += 1

    return offsets
