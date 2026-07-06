@tool
class_name SelectComponent extends Area3D

@export var health_component: HealthComponent
@export var is_selectable: bool = true
@export var is_selected: bool = false
@export var is_hovering: bool = false
@export_enum("Infantry", "Vehicle", "Structure") var select_box_type: int = 0
@export var selection_size := Vector3(2.0, 0.01, 2.0)
@export var outline_size := Vector3(2.0, 2.0, 2.0)

enum SelectBoxType { Infantry, Vehicle, Structure }

# Health bar consists of 6 cubes per 1 cell, 1 cell equals 2 godot units
const HEALTH_BAR_CUBE_SIZE = 0.33333333
var health_bar: MeshInstance3D
# Vehicle health bar material (stored for direct color access in update_health_bar)
var _vehicle_health_material: ORMMaterial3D

# Cached Vehicle health bar dimensions (computed in _ready from outline shape)
var VEHICLE_HEALTH_BAR_HEIGHT := 0.1


func _update_selection_shape():
    $SelectionHitbox.shape.size = selection_size


func _update_outline_shape():
    $SelectOutline.shape.size = outline_size
    $SelectOutline.position = Vector3(0, outline_size.y / 2.0, 0)


func _ready():
    self._update_selection_shape()
    self._update_outline_shape()

    if select_box_type != SelectBoxType.Structure:
        add_to_group("entities")

    if health_component is HealthComponent:
        health_component.connect("health_changed", _on_health_changed)
        # May return early for Vehicle until match branch runs below
        update_health_bar()

    var select_outline_shape = $SelectOutline.shape

    match select_box_type:
        SelectBoxType.Infantry:
            # Create a small 2D select box for infantry
            var infantry_select_box = MeshInstance3D.new()
            infantry_select_box.name = "InfantrySelectBox"
            infantry_select_box.mesh = QuadMesh.new()
            infantry_select_box.scale = Vector3(0.5, 0.5, 0.5)
            add_child(infantry_select_box)

        SelectBoxType.Vehicle:
            var outline_shape_size = $SelectOutline.shape.size
            var half_w: float = outline_shape_size.x / 2.0
            var half_h: float = outline_shape_size.y * 0.55

            var vehicle_outline_material = ORMMaterial3D.new()
            vehicle_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            vehicle_outline_material.albedo_color = Color.WHITE
            vehicle_outline_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
            vehicle_outline_material.no_depth_test = true
            vehicle_outline_material.render_priority = 10

            var vehicle_select_box: MeshInstance3D = MeshInstance3D.new()
            vehicle_select_box.name = "VehicleSelectBox"
            vehicle_select_box.mesh = ImmediateMesh.new()
            vehicle_select_box.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF

            # Outline lines for all four corners (L-shapes)
            var corner_inset = min(half_w, half_h) * 0.35
            var lines = [
                # BL corner — L shape (up + right from bottom-left vertex)
                [Vector3(-half_w, -half_h, 0), Vector3(-half_w, -half_h + corner_inset, 0)],
                [Vector3(-half_w, -half_h, 0), Vector3(-half_w + corner_inset, -half_h, 0)],
                # BR corner — L shape (up + left from bottom-right vertex)
                [Vector3(half_w, -half_h, 0), Vector3(half_w, -half_h + corner_inset, 0)],
                [Vector3(half_w, -half_h, 0), Vector3(half_w - corner_inset, -half_h, 0)],
                # TL corner — L shape (down + right from top-left vertex)
                [Vector3(-half_w, half_h, 0), Vector3(-half_w, half_h - corner_inset, 0)],
                [Vector3(-half_w, half_h, 0), Vector3(-half_w + corner_inset, half_h, 0)],
                # TR corner — L shape (down + left from top-right vertex)
                [Vector3(half_w, half_h, 0), Vector3(half_w, half_h - corner_inset, 0)],
                [Vector3(half_w, half_h, 0), Vector3(half_w - corner_inset, half_h, 0)],
            ]

            for line in lines:
                vehicle_select_box.mesh.surface_begin(
                    Mesh.PRIMITIVE_LINES, vehicle_outline_material
                )
                vehicle_select_box.mesh.surface_add_vertex(line[0])
                vehicle_select_box.mesh.surface_add_vertex(line[1])
                vehicle_select_box.mesh.surface_end()

            vehicle_select_box.position = Vector3(0, half_w * 0.33, 0)
            add_child(vehicle_select_box)

            if health_component is HealthComponent:
                # Left-edge anchored billboard quad — pivot at left edge (x=0), centered vertically
                var vehicle_health_bar: MeshInstance3D = MeshInstance3D.new()
                vehicle_health_bar.name = "HealthBar"
                health_bar = vehicle_health_bar

                var bar_material := ORMMaterial3D.new()
                bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                bar_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
                bar_material.no_depth_test = true
                bar_material.albedo_color = get_health_color(1.0)

                var fg_mesh := QuadMesh.new()
                vehicle_health_bar.mesh = fg_mesh
                health_bar.material_override = bar_material

                # Store material reference for direct access in update_health_bar()
                _vehicle_health_material = bar_material

                # Size: full width, centered on Y axis
                health_bar.mesh.size = Vector2(
                    outline_shape_size.x, VEHICLE_HEALTH_BAR_HEIGHT * 2.0
                )

                vehicle_health_bar.position = Vector3(
                    0, half_w + corner_inset + VEHICLE_HEALTH_BAR_HEIGHT + 0.12, 0
                )
                vehicle_health_bar.visible = false
                add_child(vehicle_health_bar)

        SelectBoxType.Structure:
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

            var select_box_material = ORMMaterial3D.new()
            select_box_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            select_box_material.albedo_color = Color.WHITE

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

            add_child(building_select_box)

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
                    min_x + HEALTH_BAR_CUBE_SIZE / 2,
                    max_y - HEALTH_BAR_CUBE_SIZE / 2,
                    health_bar_z_pos
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
                var health_bar_grid_length = max_x - min_x
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
                                min_x,
                                max_y - HEALTH_BAR_CUBE_SIZE,
                                min_z + i * HEALTH_BAR_CUBE_SIZE
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
                                min_x + HEALTH_BAR_CUBE_SIZE,
                                max_y,
                                min_z + i * HEALTH_BAR_CUBE_SIZE
                            )
                        ],
                        [
                            Vector3(
                                min_x,
                                max_y - HEALTH_BAR_CUBE_SIZE,
                                min_z + i * HEALTH_BAR_CUBE_SIZE
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
                                min_x + HEALTH_BAR_CUBE_SIZE,
                                max_y,
                                min_z + i * HEALTH_BAR_CUBE_SIZE
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
                    health_bar_grid_mesh.surface_begin(
                        Mesh.PRIMITIVE_LINES, health_bar_grid_material
                    )
                    health_bar_grid_mesh.surface_add_vertex(line[0])
                    health_bar_grid_mesh.surface_add_vertex(line[1])
                    health_bar_grid_mesh.surface_end()

                add_child(health_bar_grid)

    _update_visibility()


func update_health_bar():
    if not is_instance_valid(health_bar) or not health_component:
        return

    match select_box_type:
        SelectBoxType.Vehicle:
            var vehicle_health_bar_width = $SelectOutline.shape.size.x
            var current_value := (
                float(health_component.current_health) / float(health_component.max_health)
            )
            var new_width := float(vehicle_health_bar_width * clampf(current_value, 0.0, 1.0))

            # Only update size — mesh was built in _ready()
            health_bar.mesh.size = Vector2(new_width, VEHICLE_HEALTH_BAR_HEIGHT)

            # Update color based on damage state (material created once in _ready())
            if _vehicle_health_material:
                _vehicle_health_material.albedo_color = get_health_color(current_value)

            # Visibility handled by _update_visibility() and set_is_hovering() below

        SelectBoxType.Structure:
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


func _update_visibility():
    if health_bar != null:
        # Show when selected, or when hovering while not selected (and has health component)
        health_bar.visible = is_selected or (is_hovering and health_component != null)

    var health_child_name := "HealthBar"
    for child in get_children():
        if child.name == health_child_name:
            continue
        child.visible = is_selected
