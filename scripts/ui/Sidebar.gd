extends Control

## Tabbed build menu sidebar with production queue, prerequisites, and angular progress.

const TAB_NAMES: Array[String] = ["Buildings", "Infantry", "Vehicles", "Special"]
const TAB_ENTITY_TYPES: Array[int] = [
    EntityData.EntityType.BUILDING,
    EntityData.EntityType.INFANTRY,
    EntityData.EntityType.VEHICLE,
    EntityData.EntityType.AIRCRAFT,
]
const CAMEO_W: int = 125
const CAMEO_H: int = 90
const GRID_COLS: int = 3
const GRID_ROWS: int = 5
const CAMEO_COLORS: Dictionary = {
    "GDI": Color(0.3, 0.4, 0.6),
    "Nod": Color(0.6, 0.3, 0.3),
    "Neutral": Color(0.5, 0.5, 0.5),
}

@onready var credits_label: Label = %CreditsLabel
@onready var sell_button: Button = %SellButton
@onready var repair_button: Button = %RepairButton
@onready var tab_buttons: Array[Button] = [
    %BuildingsTab,
    %InfantryTab,
    %VehiclesTab,
    %SpecialTab,
]
@onready var grid: GridContainer = %GridContainer
@onready var scroll_up: Button = %ScrollUp
@onready var scroll_down: Button = %ScrollDown

var _current_tab: int = 0
var _scroll_offset: int = 0
var _cameo_buttons: Array[Button] = []
var _cameo_progress: Dictionary = {}  # button → ColorRect (shader overlay)
var _flicker_tweens: Dictionary = {}  # button → Tween
var _shader: ShaderMaterial = null
var _sell_mode: bool = false
var _repair_mode: bool = false

## Debug "place anywhere" mode — direct entity placement bypassing production
var _debug_place_mode: bool = false
var _debug_skip_input: int = 0


func _ready() -> void:
    _shader = ShaderMaterial.new()
    _shader.shader = preload("res://shaders/ui/angular_progress.gdshader")

    for i in range(tab_buttons.size()):
        var btn: Button = tab_buttons[i]
        btn.pressed.connect(_on_tab_pressed.bind(i))

    scroll_up.pressed.connect(_on_scroll_up)
    scroll_down.pressed.connect(_on_scroll_down)

    sell_button.pressed.connect(_on_sell_pressed)
    repair_button.pressed.connect(_on_repair_pressed)

    var em := get_node("/root/EconomyManager")
    if em:
        em.credits_changed.connect(_on_credits_changed)
        credits_label.text = "$%d" % em.get_balance(PlayerManager.get_local_player_id())

    var ps := get_node("/root/PrerequisiteSystem") as Node
    if ps:
        ps.prerequisites_changed.connect(_on_prerequisites_changed)

    var pm := get_node("/root/ProductionManager") as Node
    if pm:
        pm.production_started.connect(_on_production_started)
        pm.production_progress.connect(_on_production_progress)
        pm.production_completed.connect(_on_production_completed)
        pm.production_cancelled.connect(_on_production_cancelled)
        pm.production_paused.connect(_on_production_paused)

    _switch_tab(0)


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("tab_buildings"):
        _switch_tab(0)
    elif event.is_action_pressed("tab_infantry"):
        _switch_tab(1)
    elif event.is_action_pressed("tab_vehicles"):
        _switch_tab(2)
    elif event.is_action_pressed("tab_special"):
        _switch_tab(3)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            _on_scroll_up()
            get_viewport().set_input_as_handled()
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _on_scroll_down()
            get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
    if not _debug_place_mode or not EntityPlacer.has_preview():
        return
    if _debug_skip_input > 0:
        _debug_skip_input -= 1
        _update_debug_preview_position()
        return

    _update_debug_preview_position()

    if Input.is_action_just_pressed("select_entity"):
        _finalize_debug_place()
    elif Input.is_action_just_pressed("deselect_entity") or Input.is_key_pressed(KEY_ESCAPE):
        exit_debug_place_mode()


func _on_tab_pressed(tab_index: int) -> void:
    _switch_tab(tab_index)


func _switch_tab(tab_index: int) -> void:
    _current_tab = tab_index
    _scroll_offset = 0
    for i in range(tab_buttons.size()):
        tab_buttons[i].button_pressed = (i == tab_index)
    _refresh_grid()


func _on_scroll_up() -> void:
    if _scroll_offset > 0:
        _scroll_offset -= GRID_COLS
        _refresh_grid()


func _on_scroll_down() -> void:
    var entities := _get_current_entities()
    var max_offset := maxi(0, entities.size() - GRID_ROWS * GRID_COLS)
    if _scroll_offset < max_offset:
        _scroll_offset += GRID_COLS
        _refresh_grid()


func _get_current_entities() -> Array[EntityData]:
    var entity_type: int = TAB_ENTITY_TYPES[_current_tab]
    var all := EntityFactory.get_all_by_type(entity_type as EntityData.EntityType)
    var result: Array[EntityData] = []
    var ps := get_node("/root/PrerequisiteSystem") as Node
    for data in all:
        if not data.buildable:
            continue
        if _debug_place_mode:
            result.append(data)
        elif entity_type == EntityData.EntityType.BUILDING:
            result.append(data)
        elif ps and ps.can_build(PlayerManager.get_local_player_id(), data):
            result.append(data)
        elif not ps:
            result.append(data)
    return result


func _refresh_grid() -> void:
    # Kill all flicker tweens
    for btn in _flicker_tweens:
        var tw: Tween = _flicker_tweens[btn]
        if tw and tw.is_valid():
            tw.kill()
    _flicker_tweens.clear()

    # Clear grid
    for child in grid.get_children():
        child.queue_free()
    _cameo_buttons.clear()
    _cameo_progress.clear()

    var entities := _get_current_entities()
    var visible_start := _scroll_offset
    var visible_end := mini(visible_start + GRID_ROWS * GRID_COLS, entities.size())

    for i in range(visible_start, visible_end):
        var data: EntityData = entities[i]
        var btn := _create_cameo(data)
        grid.add_child(btn)
        _cameo_buttons.append(btn)

    # Fill remaining slots
    var remaining := (GRID_ROWS * GRID_COLS) - (visible_end - visible_start)
    for _j in range(remaining):
        var spacer := Control.new()
        spacer.custom_minimum_size = Vector2(CAMEO_W, CAMEO_H)
        grid.add_child(spacer)


func _create_cameo(data: EntityData) -> Button:
    var btn := Button.new()
    btn.custom_minimum_size = Vector2(CAMEO_W, CAMEO_H)
    btn.size_flags_horizontal = Control.SIZE_FILL
    btn.size_flags_vertical = Control.SIZE_FILL

    var color := _get_cameo_color(data)
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(2)
    style.set_content_margin_all(0)
    btn.add_theme_stylebox_override("normal", style)
    btn.add_theme_stylebox_override("focus", style)

    var hover_style := style.duplicate()
    hover_style.bg_color = color.lightened(0.2)
    btn.add_theme_stylebox_override("hover", hover_style)

    var pressed_style := style.duplicate()
    pressed_style.bg_color = color.darkened(0.2)
    btn.add_theme_stylebox_override("pressed", pressed_style)

    # Name label
    var label := Label.new()
    label.text = data.display_name
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.anchor_left = 0.0
    label.anchor_top = 0.65
    label.anchor_right = 1.0
    label.anchor_bottom = 1.0
    label.offset_left = 2.0
    label.offset_top = 0.0
    label.offset_right = -2.0
    label.offset_bottom = -2.0
    label.grow_horizontal = Control.GROW_DIRECTION_BOTH
    label.grow_vertical = Control.GROW_DIRECTION_END
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color.WHITE)
    btn.add_child(label)

    # Cost label
    var cost_label := Label.new()
    cost_label.text = "$%d" % data.cost
    cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cost_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    cost_label.anchor_left = 0.0
    cost_label.anchor_top = 0.0
    cost_label.anchor_right = 1.0
    cost_label.anchor_bottom = 0.35
    cost_label.offset_left = 2.0
    cost_label.offset_top = 2.0
    cost_label.offset_right = -2.0
    cost_label.offset_bottom = -2.0
    cost_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
    cost_label.grow_vertical = Control.GROW_DIRECTION_END
    cost_label.add_theme_font_size_override("font_size", 11)
    cost_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
    btn.add_child(cost_label)

    # Angular progress overlay
    var progress_rect := ColorRect.new()
    progress_rect.custom_minimum_size = Vector2(CAMEO_W, CAMEO_H)
    progress_rect.anchor_right = 1.0
    progress_rect.anchor_bottom = 1.0
    progress_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
    progress_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
    progress_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress_rect.material = _shader.duplicate()
    progress_rect.visible = false
    btn.add_child(progress_rect)
    _cameo_progress[btn] = progress_rect

    # Check build limit
    var ps := get_node("/root/PrerequisiteSystem")
    if ps and data.build_limit > 0:
        var count: int = ps.get_build_count(PlayerManager.get_local_player_id(), data.id)
        if count >= data.build_limit:
            btn.modulate = Color(0.4, 0.4, 0.4, 0.6)

    btn.gui_input.connect(_on_cameo_gui_input.bind(data))
    btn.set_meta("entity_id", data.id)

    # Show progress gradient if item has partial progress
    var current_progress := _get_item_progress(data)
    if current_progress > 0.0 and progress_rect.material:
        progress_rect.visible = true
        (progress_rect.material as ShaderMaterial).set_shader_parameter(
            "progress", current_progress
        )

    # Queue overlay for non-active queued items
    if _is_queued_non_active(data):
        var queue_overlay := ColorRect.new()
        queue_overlay.color = Color(1, 1, 1, 0.15)
        queue_overlay.custom_minimum_size = Vector2(CAMEO_W, CAMEO_H)
        queue_overlay.anchor_right = 1.0
        queue_overlay.anchor_bottom = 1.0
        queue_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
        queue_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
        queue_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(queue_overlay)

    # Ready-to-place overlay for buildings
    if data.entity_type == EntityData.EntityType.BUILDING and _is_ready_to_place(data):
        var ready_label := Label.new()
        ready_label.text = "Ready"
        ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ready_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        ready_label.anchor_left = 0.0
        ready_label.anchor_top = 0.0
        ready_label.anchor_right = 1.0
        ready_label.anchor_bottom = 0.65
        ready_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
        ready_label.grow_vertical = Control.GROW_DIRECTION_BOTH
        ready_label.add_theme_font_size_override("font_size", 16)
        ready_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
        ready_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(ready_label)

        # Flicker tween for Ready state
        var flicker := create_tween()
        flicker.set_loops()
        flicker.tween_property(btn, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.4)
        flicker.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)
        _flicker_tweens[btn] = flicker

    # On hold overlay for paused items
    elif _is_paused(data):
        var hold_label := Label.new()
        hold_label.text = "On hold"
        hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hold_label.anchor_left = 0.0
        hold_label.anchor_top = 0.0
        hold_label.anchor_right = 1.0
        hold_label.anchor_bottom = 0.65
        hold_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
        hold_label.grow_vertical = Control.GROW_DIRECTION_BOTH
        hold_label.add_theme_font_size_override("font_size", 14)
        hold_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
        hold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(hold_label)

    # Placing state — 2 steps brighter
    elif _is_placing(data):
        btn.modulate = Color(1.5, 1.5, 1.5, 1.0)

    # Queue count display
    var queue_count := _get_queue_count(data)
    if queue_count >= 1:
        var count_label := Label.new()
        count_label.text = str(queue_count)
        count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        count_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
        count_label.anchor_left = 0.7
        count_label.anchor_top = 0.0
        count_label.anchor_right = 1.0
        count_label.anchor_bottom = 0.35
        count_label.offset_left = 0.0
        count_label.offset_top = 2.0
        count_label.offset_right = -2.0
        count_label.offset_bottom = 0.0
        count_label.grow_horizontal = Control.GROW_DIRECTION_END
        count_label.grow_vertical = Control.GROW_DIRECTION_END
        count_label.add_theme_font_size_override("font_size", 14)
        count_label.add_theme_color_override("font_color", Color.WHITE)
        count_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
        count_label.add_theme_constant_override("shadow_offset_x", 1)
        count_label.add_theme_constant_override("shadow_offset_y", 1)
        count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(count_label)

    var time_str := "%.0fs" % data.get_build_time()
    btn.tooltip_text = "%s\n$%d\nTime: %s" % [data.display_name, data.cost, time_str]
    return btn


func _get_cameo_color(data: EntityData) -> Color:
    for faction in CAMEO_COLORS:
        if data.owner.has(faction):
            return CAMEO_COLORS[faction]
    return Color.GRAY


func _is_ready_to_place(data: EntityData) -> bool:
    var pm := get_node("/root/ProductionManager")
    if not pm:
        return false
    var ready_buildings: Array = pm.get_ready_buildings(PlayerManager.get_local_player_id())
    for item in ready_buildings:
        if (item as EntityData).id == data.id:
            return true
    return false


func _get_queue_items_for_entity(data: EntityData) -> Array:
    var pm := get_node("/root/ProductionManager")
    if not pm:
        return []
    var queue_key: String = pm.get_queue_key(
        PlayerManager.get_local_player_id(), data.buildable_queue
    )
    return pm.get_queue_items(queue_key)


func _is_paused(data: EntityData) -> bool:
    var items := _get_queue_items_for_entity(data)
    for item in items:
        var pq: ProductionQueue = item as ProductionQueue
        if pq.entity_data.id == data.id and pq.is_paused:
            return true
    return false


func _is_queued_non_active(data: EntityData) -> bool:
    var pm := get_node("/root/ProductionManager")
    if not pm:
        return false
    var queue_key: String = pm.get_queue_key(
        PlayerManager.get_local_player_id(), data.buildable_queue
    )
    var items: Array = pm.get_queue_items(queue_key)
    var active_idx: int = pm.get_active_index(queue_key)
    for i in range(items.size()):
        var pq: ProductionQueue = items[i] as ProductionQueue
        if pq.entity_data.id == data.id and i != active_idx:
            return true
    return false


func _is_placing(data: EntityData) -> bool:
    var bm := get_node("/root/BuildingManager") as BuildingManager
    return bm and bm.is_build_mode and bm.current_building_type == data


func _get_queue_count(data: EntityData) -> int:
    var items := _get_queue_items_for_entity(data)
    var total := 0
    for item in items:
        var pq: ProductionQueue = item as ProductionQueue
        if pq.entity_data.id == data.id:
            total += pq.count
    return total


func _get_item_progress(data: EntityData) -> float:
    var items := _get_queue_items_for_entity(data)
    for item in items:
        var pq: ProductionQueue = item as ProductionQueue
        if pq.entity_data.id == data.id:
            return pq.progress
    return 0.0


func _on_cameo_gui_input(event: InputEvent, data: EntityData) -> void:
    if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
        return
    var mb := event as InputEventMouseButton

    if mb.button_index == MOUSE_BUTTON_LEFT:
        var debug_menu := get_tree().get_first_node_in_group("debug_menu")
        if debug_menu and debug_menu.place_anywhere:
            _start_debug_place(data)
            get_viewport().set_input_as_handled()
            return
        var pm := get_node("/root/ProductionManager") as ProductionManager
        if not pm:
            return
        _handle_left_click(pm, data, mb.shift_pressed)
        get_viewport().set_input_as_handled()
    elif mb.button_index == MOUSE_BUTTON_RIGHT:
        var pm := get_node("/root/ProductionManager") as ProductionManager
        if not pm:
            return
        _handle_right_click(pm, data, mb.shift_pressed)
        get_viewport().set_input_as_handled()


func _handle_left_click(pm: ProductionManager, data: EntityData, shift: bool) -> void:
    # Building ready to place → enter build mode
    if data.entity_type == EntityData.EntityType.BUILDING and _is_ready_to_place(data):
        pm.place_ready_building(PlayerManager.get_local_player_id(), data.id)
        return

    # Check if item is already in queue — resume if paused
    var factory_type := data.buildable_queue
    var queue_key: String = pm.get_queue_key(PlayerManager.get_local_player_id(), factory_type)
    var items: Array = pm.get_queue_items(queue_key)
    for i in range(items.size()):
        var item: ProductionQueue = items[i] as ProductionQueue
        if item.entity_data.id == data.id and item.is_paused:
            pm.resume_production(queue_key, i)
            return

    # No prerequisites + no factory → fall back to direct placement
    var debug_menu := get_tree().get_first_node_in_group("debug_menu")
    if debug_menu and debug_menu.no_prereqs and not factory_type.is_empty():
        if not _factory_exists_for_queue(factory_type):
            _start_debug_place(data)
            return

    # Not in queue or not paused — start/stack production
    var count := 5 if shift else 1
    pm.start_production(PlayerManager.get_local_player_id(), data, count)


func _handle_right_click(pm: ProductionManager, data: EntityData, shift: bool) -> void:
    # Ready-to-place building → cancel and refund
    if data.entity_type == EntityData.EntityType.BUILDING and _is_ready_to_place(data):
        pm.cancel_ready_building(PlayerManager.get_local_player_id(), data.id)
        return

    var factory_type := data.buildable_queue
    var queue_key: String = pm.get_queue_key(PlayerManager.get_local_player_id(), factory_type)
    var items: Array = pm.get_queue_items(queue_key)
    for i in range(items.size()):
        var item: ProductionQueue = items[i] as ProductionQueue
        if item.entity_data.id == data.id:
            if shift:
                var cancel_count := 5 if item.count > 5 else item.count
                pm.cancel_production(
                    PlayerManager.get_local_player_id(), queue_key, i, cancel_count
                )
            elif item.is_paused:
                pm.cancel_production(PlayerManager.get_local_player_id(), queue_key, i, 1)
            elif i == pm.get_active_index(queue_key):
                pm.pause_production(queue_key, i)
            else:
                pm.cancel_production(PlayerManager.get_local_player_id(), queue_key, i, 1)
            break


func _on_credits_changed(player_id: int, new_balance: int, _reason: String) -> void:
    if player_id != PlayerManager.get_local_player_id():
        return
    credits_label.text = "$%d" % new_balance


func _on_prerequisites_changed(_player_id: int) -> void:
    _refresh_grid()


func _on_production_started(_queue_key: String) -> void:
    _refresh_grid()


func _on_production_progress(queue_key: String, progress: float) -> void:
    # Update the angular progress overlay on the matching cameo
    var pm := get_node("/root/ProductionManager") as ProductionManager
    if not pm:
        return
    var active_idx := pm.get_active_index(queue_key)
    var items := pm.get_queue_items(queue_key)
    if active_idx >= items.size():
        return
    var item: ProductionQueue = items[active_idx] as ProductionQueue
    for btn in _cameo_buttons:
        if btn.get_meta("entity_id", "") == item.entity_data.id:
            var rect: ColorRect = _cameo_progress.get(btn)
            if rect and rect.material:
                rect.visible = true
                (rect.material as ShaderMaterial).set_shader_parameter("progress", progress)
            break


func _on_production_completed(_queue_key: String, _entity_data: EntityData) -> void:
    _refresh_grid()


func _on_production_cancelled(_queue_key: String) -> void:
    _refresh_grid()


func _on_production_paused(_queue_key: String) -> void:
    _refresh_grid()


func _on_sell_pressed() -> void:
    _sell_mode = not _sell_mode
    _repair_mode = false
    sell_button.button_pressed = _sell_mode
    repair_button.button_pressed = false


func _on_repair_pressed() -> void:
    _repair_mode = not _repair_mode
    _sell_mode = false
    repair_button.button_pressed = _repair_mode
    sell_button.button_pressed = false


func is_sell_mode() -> bool:
    return _sell_mode


func is_repair_mode() -> bool:
    return _repair_mode


func exit_action_mode() -> void:
    _sell_mode = false
    _repair_mode = false
    sell_button.button_pressed = false
    repair_button.button_pressed = false


# --- Debug "place anywhere" mode ---


func enter_debug_place_mode() -> void:
    _debug_place_mode = true
    _refresh_grid()


func exit_debug_place_mode() -> void:
    _debug_place_mode = false
    EntityPlacer.cancel_preview()


func _factory_exists_for_queue(factory_type: String) -> bool:
    var bm := get_node("/root/BuildingManager") as BuildingManager
    if not bm:
        return false
    for entry in bm.get_all_buildings():
        var btype: EntityData = entry.get("type") as EntityData
        if btype and btype.factory == factory_type:
            return true
    return false


func _start_debug_place(data: EntityData) -> void:
    exit_debug_place_mode()
    _debug_place_mode = true
    EntityPlacer.start_preview(data)
    _debug_skip_input = 1


func _finalize_debug_place() -> void:
    if not EntityPlacer.has_preview():
        exit_debug_place_mode()
        return
    EntityPlacer.finalize_preview(PlayerManager.get_local_player_id())
    exit_debug_place_mode()


func _update_debug_preview_position() -> void:
    if not EntityPlacer.has_preview():
        return
    var cam := _get_camera_3d()
    if not cam:
        return
    var mouse_pos := get_viewport().get_mouse_position()
    var from := cam.project_ray_origin(mouse_pos)
    var dir := cam.project_ray_normal(mouse_pos).normalized()
    var ground_plane := Plane(Vector3.UP, 0.0)
    var intersection = ground_plane.intersects_ray(from, dir)
    if intersection == null:
        return
    var hit_pos := intersection as Vector3
    for i in 4:
        var terrain_y := TerrainSystem.get_height_at_world_smooth(hit_pos)
        var adjusted := Plane(Vector3.UP, terrain_y)
        var new_hit = adjusted.intersects_ray(from, dir)
        if new_hit == null:
            break
        hit_pos = new_hit as Vector3
    EntityPlacer.update_preview_position(hit_pos)


func _get_camera_3d() -> Camera3D:
    var root := get_tree().current_scene
    if not root:
        return null
    var cam_ctrl := root.get_node_or_null("Camera")
    if not cam_ctrl:
        return null
    return cam_ctrl.get_node_or_null("Camera3D") as Camera3D
