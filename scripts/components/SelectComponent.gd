@tool
class_name SelectComponent extends Area3D

signal selection_state_changed(select_comp: SelectComponent)

@export_group("Selection")
@export var health_component: HealthComponent
@export var is_selectable: bool = true
@export var is_drag_selectable: bool = true
@export var is_selected: bool = false
@export var is_hovering: bool = false
@export_enum("Infantry", "Vehicle", "Structure") var select_box_type: int = 0
@export var selection_size := Vector3(2.0, 0.01, 2.0)
@export var outline_size := Vector3(2.0, 2.0, 2.0)
@export var outline_2d_size := Vector2.ZERO
@export var vertical_offset: float = 0.0

enum SelectBoxType { Infantry, Vehicle, Structure }

const HEALTH_BAR_CUBE_SIZE = 0.33333333
## Move-target line lifetime and fade tail (seconds). The line is an order
## acknowledgement glyph: short-lived, fading out over the tail.
const MOVE_LINE_DURATION := 0.3
const FADE_WINDOW := 0.1
## Shared white unshaded material for building select boxes — one per game
## instead of one fresh material per building.
static var _shared_select_box_material: ORMMaterial3D = null
var health_bar: MeshInstance3D
var _building_select_box: MeshInstance3D
var _health_bar_grid: MeshInstance3D
var _rally_component: RallyPointComponent = null
var _move_line_timer: Timer = null
var _movement_controller: MovementController = null
var _combat_component: CombatComponent = null


func _update_selection_shape():
    $SelectionHitbox.shape.size = selection_size


func _update_outline_shape():
    $SelectOutline.shape.size = outline_size
    $SelectOutline.position = Vector3(0, outline_size.y / 2.0, 0)


func _ready():
    # _process only drives the move-target line; keep it off until the line shows
    # so every SelectComponent (units + structures) isn't ticked just to early-return.
    set_process(false)
    self._update_selection_shape()
    self._update_outline_shape()

    if select_box_type != SelectBoxType.Structure:
        var entity_root := get_parent()
        if entity_root:
            if not entity_root.is_in_group("selectable"):
                entity_root.add_to_group("selectable")
            if not entity_root.is_in_group("entities"):
                entity_root.add_to_group("entities")
            if not entity_root.is_in_group("drag_selectable"):
                entity_root.add_to_group("drag_selectable")

    if health_component is HealthComponent:
        health_component.connect("health_changed", _on_health_changed)
        update_health_bar()

    var select_outline_shape = $SelectOutline.shape

    if select_box_type == SelectBoxType.Structure:
        var hit_box_size = select_outline_shape.size
        var min_x: float = hit_box_size.x / -2
        var max_x: float = hit_box_size.x / 2
        var min_y: float = 0.01
        var max_y: float = hit_box_size.y
        var min_z: float = hit_box_size.z / -2
        var max_z: float = hit_box_size.z / 2

        var x_line_length = min((max_x - min_x) / 4, 1)
        var y_line_length = min((max_y - min_y) / 4, 0.5)
        var z_line_length = min((max_z - min_z) / 4, 1)

        if _shared_select_box_material == null:
            _shared_select_box_material = ORMMaterial3D.new()
            _shared_select_box_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            _shared_select_box_material.albedo_color = Color.WHITE
        var select_box_material: ORMMaterial3D = _shared_select_box_material

        # Create a 3D select box for buildings
        var building_select_box = MeshInstance3D.new()
        var immediate_mesh = ImmediateMesh.new()
        building_select_box.name = "BuildingSelectBox"
        building_select_box.mesh = immediate_mesh
        building_select_box.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF

        # Generate the lines for the select box
        var lines = [
            [Vector3(min_x, min_y, min_z), Vector3(min_x, min_y + y_line_length, min_z)],
            [Vector3(min_x, min_y, min_z), Vector3(min_x + x_line_length, min_y, min_z)],
            [Vector3(min_x, min_y, min_z), Vector3(min_x, min_y, min_z + z_line_length)],
            [Vector3(max_x, min_y, min_z), Vector3(max_x, min_y + y_line_length, min_z)],
            [Vector3(max_x, min_y, min_z), Vector3(max_x - x_line_length, min_y, min_z)],
            [Vector3(max_x, min_y, min_z), Vector3(max_x, min_y, min_z + z_line_length)],
            [Vector3(min_x, min_y, max_z), Vector3(min_x, min_y + y_line_length, max_z)],
            [Vector3(min_x, min_y, max_z), Vector3(min_x + x_line_length, min_y, max_z)],
            [Vector3(min_x, min_y, max_z), Vector3(min_x, min_y, max_z - z_line_length)],
            [Vector3(max_x, min_y, max_z), Vector3(max_x, min_y + y_line_length, max_z)],
            [Vector3(max_x, min_y, max_z), Vector3(max_x - x_line_length, min_y, max_z)],
            [Vector3(max_x, min_y, max_z), Vector3(max_x, min_y, max_z - z_line_length)],
            # top up
            [
                Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z),
                Vector3(min_x, max_y - y_line_length, min_z)
            ],
            [
                Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z),
                Vector3(min_x + x_line_length, max_y, min_z)
            ],
            # top right
            [Vector3(max_x, max_y, min_z), Vector3(max_x, max_y - y_line_length, min_z)],
            [Vector3(max_x, max_y, min_z), Vector3(max_x - x_line_length, max_y, min_z)],
            [Vector3(max_x, max_y, min_z), Vector3(max_x, max_y, min_z + z_line_length)],
            # top left
            [
                Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, max_z),
                Vector3(min_x, max_y - y_line_length, max_z)
            ],
            [
                Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, max_z),
                Vector3(min_x + x_line_length, max_y, max_z)
            ],
        ]

        for line in lines:
            immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, select_box_material)
            immediate_mesh.surface_add_vertex(line[0])
            immediate_mesh.surface_add_vertex(line[1])
            immediate_mesh.surface_end()

            # draw health bar
            # health bar length that is stepped by HEALTH_BAR_CUBE_SIZE

            # draw health bar grid

            # Create vertex for each health bar cube segment
        add_child(building_select_box)
        _building_select_box = building_select_box

        if health_component:
            # draw health bar
            # health bar length that is stepped by HEALTH_BAR_CUBE_SIZE
            var health_value: float = (
                float(health_component.current_health) / float(health_component.max_health)
            )
            var health_bar_length = (max_z - min_z) * health_value
            var health_bar_z_pos: float = -((max_z - min_z) - health_bar_length) / 2
            health_bar = MeshInstance3D.new()
            health_bar.mesh = BoxMesh.new()
            health_bar.name = "HealthBar"
            health_bar.scale = Vector3(
                HEALTH_BAR_CUBE_SIZE - 0.02, HEALTH_BAR_CUBE_SIZE - 0.02, health_bar_length
            )
            health_bar.position = Vector3(
                min_x + HEALTH_BAR_CUBE_SIZE / 2, max_y - HEALTH_BAR_CUBE_SIZE / 2, health_bar_z_pos
            )
            health_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var health_bar_material = ORMMaterial3D.new()
            health_bar_material.albedo_color = get_health_color(health_value)
            health_bar.material_override = health_bar_material
            health_bar.visible = false
            add_child(health_bar)

            # draw health bar grid
            var health_bar_grid_material = ORMMaterial3D.new()
            health_bar_grid_material.albedo_color = Color(0, 0, 0)
            health_bar_grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            var health_bar_grid_length = max_z - min_z
            var health_bar_grid = MeshInstance3D.new()
            var health_bar_grid_mesh = ImmediateMesh.new()
            health_bar_grid.mesh = health_bar_grid_mesh
            health_bar_grid.cast_shadow = false
            # Create vertex for each health bar cube segment
            var health_bar_grid_segments: int = int(
                ceil(health_bar_grid_length / HEALTH_BAR_CUBE_SIZE)
            )
            for i in range(health_bar_grid_segments):
                var health_bar_grid_around_lines = [
                    [
                        Vector3(
                            min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z + i * HEALTH_BAR_CUBE_SIZE
                        ),
                        Vector3(min_x, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE)
                    ],
                    [
                        Vector3(
                            min_x + HEALTH_BAR_CUBE_SIZE,
                            max_y - HEALTH_BAR_CUBE_SIZE,
                            min_z + i * HEALTH_BAR_CUBE_SIZE
                        ),
                        Vector3(
                            min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE
                        )
                    ],
                    [
                        Vector3(
                            min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z + i * HEALTH_BAR_CUBE_SIZE
                        ),
                        Vector3(
                            min_x + HEALTH_BAR_CUBE_SIZE,
                            max_y - HEALTH_BAR_CUBE_SIZE,
                            min_z + i * HEALTH_BAR_CUBE_SIZE
                        )
                    ],
                    [
                        Vector3(min_x, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE),
                        Vector3(
                            min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE
                        )
                    ],
                ]

                for line in health_bar_grid_around_lines:
                    health_bar_grid_mesh.surface_begin(
                        Mesh.PRIMITIVE_LINES, health_bar_grid_material
                    )
                    health_bar_grid_mesh.surface_add_vertex(line[0])
                    health_bar_grid_mesh.surface_add_vertex(line[1])
                    health_bar_grid_mesh.surface_end()
            var health_bar_grid_length_lines = [
                [Vector3(min_x, max_y, min_z), Vector3(min_x, max_y, max_z)],
                [
                    Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z),
                    Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, max_z)
                ],
                [
                    Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z),
                    Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, max_z)
                ],
                [
                    Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y - HEALTH_BAR_CUBE_SIZE, min_z),
                    Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y - HEALTH_BAR_CUBE_SIZE, max_z)
                ],
            ]

            for line in health_bar_grid_length_lines:
                health_bar_grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES, health_bar_grid_material)
                health_bar_grid_mesh.surface_add_vertex(line[0])
                health_bar_grid_mesh.surface_add_vertex(line[1])
                health_bar_grid_mesh.surface_end()
            add_child(health_bar_grid)
            _health_bar_grid = health_bar_grid

    # Rally line — green line from building center to rally point, drawn via the
    # shared MoveLineRenderer (change-only: re-registered when the rally point moves).
    var building := get_parent()
    if building:
        _rally_component = (building.get_node_or_null("RallyPointComponent") as RallyPointComponent)
        if _rally_component:
            _rally_component.rally_point_changed.connect(_on_rally_point_changed)

    # Move target line — green line from a moving unit to its destination cell,
    # drawn via the shared MoveLineRenderer (registered while the line is shown).
    var entity := get_parent()
    if entity:
        _movement_controller = entity.get_node_or_null("MovementController") as MovementController
        _combat_component = entity.get_node_or_null("CombatComponent") as CombatComponent
        if _movement_controller:
            _movement_controller.movement_started.connect(_on_movement_started)

            var timer := Timer.new()
            timer.name = "MoveTargetLineTimer"
            timer.one_shot = true
            timer.wait_time = MOVE_LINE_DURATION
            timer.timeout.connect(_on_move_line_timeout)
            add_child(timer)
            _move_line_timer = timer

    _update_visibility()


func update_health_bar():
    if not is_instance_valid(health_bar) or not health_component:
        return

    if select_box_type == SelectBoxType.Structure:
        var select_outline_shape = $SelectOutline.shape
        var hit_box_size = select_outline_shape.size
        var min_z: float = hit_box_size.z / -2
        var max_z: float = hit_box_size.z / 2
        var health_value = (
            float(health_component.current_health) / float(health_component.max_health)
        )
        var health_bar_length = (max_z - min_z) * health_value
        var health_bar_z_pos = -((max_z - min_z) - health_bar_length) / 2
        health_bar.position = Vector3(
            health_bar.position.x, health_bar.position.y, health_bar_z_pos
        )
        health_bar.scale = Vector3(health_bar.scale.x, health_bar.scale.y, health_bar_length)
        var health_bar_material = health_bar.material_override
        health_bar_material.albedo_color = get_health_color(health_value)


func _on_health_changed(_new_health, _old_health) -> void:
    update_health_bar()


func get_health_color(health_value: float) -> Color:
    if health_value > 0.5:
        return Color.GREEN
    elif health_value > 0.25:
        return Color.YELLOW
    elif health_value > 0.0:
        return Color.RED
    else:
        return Color(0.5, 0.0, 0.0)  # dark red for dead units instead of green


func set_is_hovering(value: bool):
    is_hovering = value
    _update_visibility()


func set_is_selected(value: bool):
    is_selected = value
    _update_visibility()
    _update_move_line_on_select()
    selection_state_changed.emit(self)


func _update_move_line_on_select() -> void:
    # Show the line while the unit is moving OR while it has an active attack
    # target, so an in-range attacker re-selected mid-fight still shows it.
    if is_selected and _movement_controller:
        if _movement_controller.is_moving() or _has_active_attack_target():
            _show_move_line()
            return
    _hide_move_line()


func _on_movement_started() -> void:
    if is_selected:
        _show_move_line()


func _on_move_line_timeout() -> void:
    _unregister_line()


func _show_move_line() -> void:
    if not _move_line_timer:
        return
    _register_line()
    _move_line_timer.start()


func _hide_move_line() -> void:
    if _move_line_timer:
        _move_line_timer.stop()
    if not _rally_line_active():
        _unregister_line()


func _has_active_attack_target() -> bool:
    return _combat_component != null and is_instance_valid(_combat_component.get_target())


func _get_move_line_endpoint() -> Vector3:
    # While attacking, point the line at the enemy entity (tracking it as it
    # moves) instead of the fixed approach stop position.
    if _has_active_attack_target():
        return _combat_component.get_target().global_position
    return _movement_controller.get_target_position()


## Pulled each frame by the shared MoveLineRenderer for registered sources.
## Returns the world-space line geometry (or {} when nothing should be drawn).
## The move-target endpoint is snapped to its destination cell center (y kept);
## the rally endpoint is the raw rally position.
func get_line_render_data() -> Dictionary:
    if not is_selected:
        return {}
    if _rally_line_active():
        return {
            "origin": _line_origin(),
            "target": _rally_component.get_target_position(),
            "alpha": 1.0,
            "marker_half": 0.6,
            "marker_diamond": true,
        }
    if _move_line_active():
        var target := _get_move_line_endpoint()
        var center := CellUtil.cell_to_world(CellUtil.world_to_cell(target))
        center.y = target.y  # cell_to_world zeroes y; keep the waypoint's terrain height
        return {
            "origin": _line_origin(),
            "target": center,
            "alpha": _line_alpha(),
            "marker_half": 0.125,
            "marker_diamond": false,
        }
    return {}


func _line_origin() -> Vector3:
    var parent := get_parent() as Node3D
    if is_instance_valid(parent):
        return parent.global_position
    return Vector3.ZERO


## Fade the line out over the tail of its one-shot lifetime.
func _line_alpha() -> float:
    if not _move_line_timer:
        return 1.0
    var remaining := _move_line_timer.time_left
    if remaining >= FADE_WINDOW:
        return 1.0
    return maxf(remaining / FADE_WINDOW, 0.0)


func _move_line_active() -> bool:
    return (
        _movement_controller != null
        and (_movement_controller.is_moving() or _has_active_attack_target())
    )


func _rally_line_active() -> bool:
    return _rally_component != null and _rally_component.has_rally_point()


func _register_line() -> void:
    var renderer := _line_renderer()
    if renderer:
        renderer.register(self)


func _unregister_line() -> void:
    var renderer := _line_renderer()
    if renderer:
        renderer.unregister(self)


func _line_renderer() -> Node:
    var tree := get_tree()
    if tree:
        return tree.get_root().get_node_or_null("MoveLineRenderer")
    return null


func _update_visibility():
    var vis := is_selected or is_hovering
    if _building_select_box:
        _building_select_box.visible = is_selected
    if health_bar:
        health_bar.visible = vis
    if _health_bar_grid:
        _health_bar_grid.visible = vis
    for child in get_children():
        if (
            child != _building_select_box
            and child != health_bar
            and child != _health_bar_grid
            and child != _move_line_timer
        ):
            child.visible = vis
    if _rally_component:
        var has_rally := is_selected and _rally_component.has_rally_point()
        if has_rally:
            _register_line()
        elif not _move_line_active():
            _unregister_line()


func _on_rally_point_changed(_point: Vector2i) -> void:
    if _rally_component:
        var has_rally := is_selected and _rally_component.has_rally_point()
        if has_rally:
            _register_line()
        else:
            _unregister_line()
