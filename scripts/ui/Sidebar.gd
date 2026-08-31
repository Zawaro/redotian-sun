extends Control

## Tabbed build menu sidebar with production queue, prerequisites, and angular progress.

const TAB_NAMES: Array[String] = ["Buildings", "Infantry", "Vehicles", "Special"]
const TAB_ENTITY_TYPES: Dictionary = {
    0: [EntityData.EntityType.BUILDING],
    1: [EntityData.EntityType.INFANTRY],
    2: [EntityData.EntityType.VEHICLE, EntityData.EntityType.AIRCRAFT],
    3: [],
}
const CAMEO_W: int = 125
const CAMEO_H: int = 90
const GRID_COLS: int = 3
const GRID_ROWS: int = 5
const CAMEO_COLORS: Dictionary = {
    "GDI": Color(0.3, 0.4, 0.6),
    "Nod": Color(0.6, 0.3, 0.3),
    "Neutral": Color(0.5, 0.5, 0.5),
}

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
var _grid_dirty: bool = false

## Credit counter animation lives on the CreditCounter script attached to
## %CreditsLabel (scenes/ui/Sidebar.tscn); the Sidebar keeps no counter state.


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
    # Button visuals sync from the mode owner's signal — sell/repair state is
    # OrderSystem's active generator type; the Sidebar keeps no mode booleans.
    OrderSystem.generator_changed.connect(_sync_action_buttons)
    # Placing mode refreshes the grid (all entities shown while armed).
    EntityPlacer.placing_mode_changed.connect(_on_placing_mode_changed)

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
    _prewarm_available_models()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("tab_buildings"):
        _switch_tab(0)
    elif event.is_action_pressed("tab_infantry"):
        _switch_tab(1)
    elif event.is_action_pressed("tab_vehicles"):
        _switch_tab(2)
    elif event.is_action_pressed("tab_special"):
        _switch_tab(3)
    elif event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            if get_global_rect().has_point(get_viewport().get_mouse_position()):
                _on_scroll_up()
                get_viewport().set_input_as_handled()
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if get_global_rect().has_point(get_viewport().get_mouse_position()):
                _on_scroll_down()
                get_viewport().set_input_as_handled()


func _on_tab_pressed(tab_index: int) -> void:
    _switch_tab(tab_index)


func _switch_tab(tab_index: int) -> void:
    _current_tab = tab_index
    _scroll_offset = 0
    for i in range(tab_buttons.size()):
        tab_buttons[i].button_pressed = (i == tab_index)
    _queue_refresh()


func _on_scroll_up() -> void:
    if _scroll_offset > 0:
        _scroll_offset -= GRID_COLS
        _queue_refresh()


func _on_scroll_down() -> void:
    var entities := _get_current_entities()
    var max_offset := maxi(0, entities.size() - GRID_ROWS * GRID_COLS)
    if _scroll_offset < max_offset:
        _scroll_offset += GRID_COLS
        _queue_refresh()


func _get_current_entities() -> Array[EntityData]:
    var types: Array = TAB_ENTITY_TYPES.get(_current_tab, [])
    var result: Array[EntityData] = []
    var ps := get_node("/root/PrerequisiteSystem") as Node
    for etype in types:
        var all := EntityFactory.get_all_by_type(etype as EntityData.EntityType)
        for data in all:
            if not data.buildable:
                continue
            if ps and ps.can_build(PlayerManager.get_local_player_id(), data):
                result.append(data)
            elif not ps:
                result.append(data)
    return result


## Coalesce the many production/prerequisite signals into a single deferred
## grid rebuild per frame instead of rebuilding on every trigger.


func _queue_refresh() -> void:
    if _grid_dirty:
        return
    _grid_dirty = true
    _refresh_grid.call_deferred()


func _refresh_grid() -> void:
    _grid_dirty = false
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
    var pm := get_node_or_null("/root/ProductionManager") as ProductionManager
    if not pm:
        # Autoloads make this unreachable in-game; hand back the dressed button
        # (progress/overlays missing) instead of a null the grid would crash on.
        return btn
    var player_id := PlayerManager.get_local_player_id()
    var current_progress := pm.get_item_progress(player_id, data)
    if current_progress > 0.0 and progress_rect.material:
        progress_rect.visible = true
        (progress_rect.material as ShaderMaterial).set_shader_parameter(
            "progress", current_progress
        )

    # Queue overlay for non-active queued items
    if _is_queued_non_active(pm, data):
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
    if (
        data.entity_type == EntityData.EntityType.BUILDING
        and pm.is_ready_to_place(player_id, data.id)
    ):
        _add_ready_overlay(btn)

    # Ready-to-spawn overlay for units that failed to spawn
    elif pm.is_ready_to_spawn(player_id, data.id):
        _add_ready_overlay(btn)

    # On hold overlay for paused items
    elif _is_paused(pm, data):
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
    var queue_count := pm.get_queue_count(player_id, data)
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

    var rules := GlobalRules.get_current()
    var build_time := data.get_build_time(rules.build_speed) if rules else data.get_build_time()
    var time_str := "%.0fs" % build_time
    btn.tooltip_text = "%s\n$%d\nTime: %s" % [data.display_name, data.cost, time_str]
    return btn


func _get_cameo_color(data: EntityData) -> Color:
    for faction in CAMEO_COLORS:
        if data.owner.has(faction):
            return CAMEO_COLORS[faction]
    return Color.GRAY


func _is_placing(data: EntityData) -> bool:
    var bm := get_node("/root/BuildingManager") as BuildingManager
    return bm and bm.is_build_mode and bm.current_building_type == data


func _is_paused(pm: ProductionManager, data: EntityData) -> bool:
    var items: Array = pm.get_queue_items(
        pm.get_queue_key(PlayerManager.get_local_player_id(), data.buildable_queue)
    )
    for item in items:
        var pq: ProductionQueue = item as ProductionQueue
        if pq.entity_data.id == data.id and pq.is_paused:
            return true
    return false


func _is_queued_non_active(pm: ProductionManager, data: EntityData) -> bool:
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


func _on_cameo_gui_input(event: InputEvent, data: EntityData) -> void:
    if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
        return
    var mb := event as InputEventMouseButton

    # Place-anywhere cheat: the cameo arms a free-placement session directly,
    # bypassing production routing entirely.
    var debug_menu := get_tree().get_first_node_in_group("debug_menu")
    if debug_menu and debug_menu.place_anywhere:
        EntityPlacer.start_placing(data)
        get_viewport().set_input_as_handled()
        return

    var pm := get_node_or_null("/root/ProductionManager") as ProductionManager
    if not pm:
        return
    pm.handle_cameo_click(
        PlayerManager.get_local_player_id(), data, mb.button_index, mb.shift_pressed
    )
    get_viewport().set_input_as_handled()


func _on_prerequisites_changed(_player_id: int) -> void:
    _queue_refresh()
    _prewarm_available_models()


func _prewarm_available_models() -> void:
    var paths: PackedStringArray = []
    for entity_data in _get_current_entities():
        if entity_data.art_data and not entity_data.art_data.model_path.is_empty():
            var mp: String = entity_data.art_data.model_path
            if not BatchLoader.is_loaded(mp) and mp not in paths:
                paths.append(mp)
        # Also pre-warm deploy/undeploy target models.
        for target_id in [entity_data.deploys_into, entity_data.undeploys_into]:
            if target_id.is_empty():
                continue
            var target_data := EntityFactory.get_entity_data(target_id)
            if (
                target_data
                and target_data.art_data
                and not target_data.art_data.model_path.is_empty()
            ):
                var tp: String = target_data.art_data.model_path
                if not BatchLoader.is_loaded(tp) and tp not in paths:
                    paths.append(tp)
    if not paths.is_empty():
        BatchLoader.preload_batch(paths)


func _on_production_started(_queue_key: String) -> void:
    _queue_refresh()


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
    _queue_refresh()


func _on_production_cancelled(_queue_key: String) -> void:
    _queue_refresh()


func _on_production_paused(_queue_key: String) -> void:
    _queue_refresh()


func _on_sell_pressed() -> void:
    # Toggling the active mode off cancels; arming a mode only swaps the
    # generator — button visuals come back through generator_changed.
    if OrderSystem.is_sell_mode():
        OrderSystem.cancel()
    else:
        OrderSystem.set_generator(SellOrderGenerator.new())


func _on_repair_pressed() -> void:
    if OrderSystem.is_repair_mode():
        OrderSystem.cancel()
    else:
        OrderSystem.set_generator(RepairOrderGenerator.new())


func _sync_action_buttons() -> void:
    sell_button.button_pressed = OrderSystem.is_sell_mode()
    repair_button.button_pressed = OrderSystem.is_repair_mode()


func _on_placing_mode_changed(_active: bool) -> void:
    _queue_refresh()


func _add_ready_overlay(btn: Button) -> void:
    var label := Label.new()
    label.text = "Ready"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.anchor_left = 0.0
    label.anchor_top = 0.0
    label.anchor_right = 1.0
    label.anchor_bottom = 0.65
    label.grow_horizontal = Control.GROW_DIRECTION_BOTH
    label.grow_vertical = Control.GROW_DIRECTION_BOTH
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(label)
    var flicker := create_tween()
    flicker.set_loops()
    flicker.tween_property(btn, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.4)
    flicker.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)
    _flicker_tweens[btn] = flicker
