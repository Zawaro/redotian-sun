# /scripts/core/SelectionManager.gd
extends Node
class_name SelectionManager

signal selection_changed()
signal unit_selected(unit: SelectComponent)
signal unit_deselected(unit: SelectComponent)

var selected_units: Array[SelectComponent] = []

func _ready():
    print("✅ SelectionManager loaded successfully!")

func add_unit(unit: SelectComponent):
    if unit and not selected_units.has(unit):
        selected_units.append(unit)
        
        # Enable selection visuals via method call
        if unit.has_method("set_is_selected"):
            unit.set_is_selected(true)
            
        emit_signal("unit_selected", unit)

func remove_unit(unit: SelectComponent):
    if unit in selected_units:
        selected_units.erase(unit)
        
        # Disable selection visuals via method call
        if unit.has_method("set_is_selected"):
            unit.set_is_selected(false)
            
        emit_signal("unit_deselected", unit)

func clear_selection():
    for unit in selected_units:
        if unit.has_method("set_is_selected"):
            unit.set_is_selected(false)
    selected_units.clear()
    emit_signal("selection_changed")

func toggle_unit(unit: SelectComponent, shift_pressed: bool = false):
    if shift_pressed and Input.is_key_pressed(KEY_SHIFT):
        # Add to selection (multi-select)
        add_unit(unit)
    else:
        if selected_units.size() == 1 and selected_units[0] == unit:
            remove_unit(unit)  # Deselect clicked unit
        else:
            clear_selection()
            add_unit(unit)

func get_selected_units():
    return selected_units
