@tool
class_name SelectComponent extends Area3D

@export var health_component: HealthComponent
@export var is_selectable: bool = true
@export var is_drag_selectable: bool = true
@export var is_selected: bool = false
@export var is_hovering: bool = false
@export_enum("Infantry", "Vehicle", "Structure") var select_box_type: int = 0
@export var selection_size := Vector3(2.0, 0.01, 2.0)
@export var outline_size := Vector3(2.0, 2.0, 2.0)
@export var outline_2d_size := Vector2.ZERO

enum SelectBoxType { Infantry, Vehicle, Structure }

const HEALTH_BAR_CUBE_SIZE = 0.33333333
var health_bar: MeshInstance3D
var _building_select_box: MeshInstance3D
var _health_bar_grid: MeshInstance3D


func _update_selection_shape():
    $SelectionHitbox.shape.size = selection_size


func _update_outline_shape():
    $SelectOutline.shape.size = outline_size
    $SelectOutline.position = Vector3(0, outline_size.y / 2.0, 0)


func _ready():
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


func _update_visibility():
    var show := is_selected or is_hovering
    if _building_select_box:
        _building_select_box.visible = is_selected
    if health_bar:
        health_bar.visible = show
    if _health_bar_grid:
        _health_bar_grid.visible = show
    for child in get_children():
        if child != _building_select_box and child != health_bar and child != _health_bar_grid:
            child.visible = show
