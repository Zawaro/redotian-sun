extends Node

signal selection_changed(selected_entities: Array[SelectComponent])
signal hover_changed(entity: SelectComponent)

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

func is_entity_selected(entity: SelectComponent) -> bool:
    return selected_entities.has(entity)

func get_selected_entities():
    return selected_entities
