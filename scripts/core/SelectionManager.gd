@tool
extends Node
class_name SelectionManager

signal selection_changed(selected_units: Array[SelectComponent])
signal hover_changed(entity: SelectComponent)

var selected_units: Array[SelectComponent] = []
var is_hovering: bool = false
var hovered_entity: SelectComponent = null

func _ready():
    print("✅ SelectionManager loaded successfully!")

func select_unit(unit: SelectComponent, shift_pressed: bool = false):
    if not unit:
        return
    
    # Shift pressed + already selected: toggle off (deselect)
    if shift_pressed and unit in selected_units:
        remove_unit(unit)
        return
    
    # Shift pressed + not selected: add to selection (multi-select)
    if shift_pressed:
        add_unit(unit)
    else:
        deselect_all()
        add_unit(unit)

func deselect_unit(unit: SelectComponent):
    remove_unit(unit)

func deselect_all():
    for unit in selected_units:
        if unit.has_method("set_is_selected"):
            unit.set_is_selected(false)
    selected_units.clear()
    emit_signal("selection_changed", [])

func add_unit(unit: SelectComponent):
    if unit and not selected_units.has(unit):
        selected_units.append(unit)
        
        # Enable selection visuals via method call
        if unit.has_method("set_is_selected"):
            unit.set_is_selected(true)
            
        emit_signal("selection_changed", selected_units.duplicate())

func remove_unit(unit: SelectComponent):
    if unit in selected_units:
        selected_units.erase(unit)
        
        # Disable selection visuals via method call
        if unit.has_method("set_is_selected"):
            unit.set_is_selected(false)
            
        emit_signal("selection_changed", selected_units.duplicate())

func toggle_unit(unit: SelectComponent):
    if unit in selected_units:
        remove_unit(unit)
    else:
        add_unit(unit)

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

func is_unit_selected(unit: SelectComponent) -> bool:
    return selected_units.has(unit)

func get_selected_units():
    return selected_units
