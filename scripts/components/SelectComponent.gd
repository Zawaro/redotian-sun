extends Node3D
class_name SelectComponent

@export var health_component: HealthComponent
@export var hit_box_component: HitboxComponent
@export var is_selectable: bool = true
@export_enum("Infantry", "Vehicle", "Structure") var select_box_type: int = 0
@export var is_selected: bool = false

@onready var hitbox_collision_shape: CollisionShape3D = hit_box_component.get_node("CollisionObject3D")

enum SelectBoxType {
    Infantry,
    Vehicle,
    Structure
}

# Health bar consists of 6 cubes per 1 cell, 1 cell equals 2 godot units
const HEALTH_BAR_CUBE_SIZE = 0.33333333
var health_bar: MeshInstance3D

func _ready():    
    match select_box_type:
        SelectBoxType.Infantry:
            # Create a small 2D select box for infantry
            var infantry_select_box = MeshInstance3D.new()
            infantry_select_box.mesh = QuadMesh.new()
            infantry_select_box.scale = Vector3(0.5, 0.5, 0.5)
            add_child(infantry_select_box)
        SelectBoxType.Vehicle:
            # Create a large 2D select box for vehicles
            var vehicle_select_box = MeshInstance3D.new()
            vehicle_select_box.mesh = QuadMesh.new()
            vehicle_select_box.scale = Vector3(1.0, 1.0, 1.0)
            add_child(vehicle_select_box)
        SelectBoxType.Structure:
            var hit_box_size = hitbox_collision_shape.shape.size
            var min_x: float = hit_box_size.x / - 2
            var max_x: float = hit_box_size.x / 2
            var min_y: float = 0.01
            var max_y: float = hit_box_size.y
            var min_z: float = hit_box_size.z / - 2
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
            building_select_box.mesh = immediate_mesh
            building_select_box.cast_shadow = false
            
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
                [Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z), Vector3(min_x, max_y - y_line_length, min_z)],
                [Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z), Vector3(min_x + x_line_length, max_y, min_z)],
                # top right
                [Vector3(max_x, max_y, min_z), Vector3(max_x, max_y - y_line_length, min_z)],
                [Vector3(max_x, max_y, min_z), Vector3(max_x - x_line_length, max_y, min_z)],
                [Vector3(max_x, max_y, min_z), Vector3(max_x, max_y, min_z + z_line_length)],
                # top left
                [Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, max_z), Vector3(min_x, max_y - y_line_length, max_z)],
                [Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, max_z), Vector3(min_x + x_line_length, max_y, max_z)],
            ]

            for line in lines:
                immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, select_box_material)
                immediate_mesh.surface_add_vertex(line[0])
                immediate_mesh.surface_add_vertex(line[1])
                immediate_mesh.surface_end()

            add_child(building_select_box)

            # draw health bar
            # health bar length that is stepped by HEALTH_BAR_CUBE_SIZE
            var health_value: float = float(health_component.current_health) / float(health_component.max_health)
            var health_bar_length = (max_z - min_z) * health_value
            var health_bar_z_pos: float = -((max_z - min_z) - health_bar_length) / 2
            health_bar = MeshInstance3D.new()
            health_bar.mesh = BoxMesh.new()
            health_bar.name = "HealthBar"
            health_bar.scale = Vector3(HEALTH_BAR_CUBE_SIZE - 0.02, HEALTH_BAR_CUBE_SIZE - 0.02, health_bar_length)
            health_bar.position = Vector3(min_x + HEALTH_BAR_CUBE_SIZE / 2, max_y - HEALTH_BAR_CUBE_SIZE / 2, health_bar_z_pos)
            health_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var health_bar_material = ORMMaterial3D.new()
            health_bar_material.albedo_color = get_health_color(health_value)
            health_bar.material_override = health_bar_material
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
            # create for loop that takes health_bar_length and substracts it by HEALTH_BAR_CUBE_SIZE and create vertex for each cube
            for i in range((health_bar_grid_length + HEALTH_BAR_CUBE_SIZE) / HEALTH_BAR_CUBE_SIZE):
                var health_bar_grid_around_lines = [
                    [Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z + i * HEALTH_BAR_CUBE_SIZE), Vector3(min_x, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE)],
                    [Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y - HEALTH_BAR_CUBE_SIZE, min_z + i * HEALTH_BAR_CUBE_SIZE), Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE)],
                    [Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z + i * HEALTH_BAR_CUBE_SIZE), Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y - HEALTH_BAR_CUBE_SIZE, min_z + i * HEALTH_BAR_CUBE_SIZE)],
                    [Vector3(min_x, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE), Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z + i * HEALTH_BAR_CUBE_SIZE)],
                ]

                for line in health_bar_grid_around_lines:
                    health_bar_grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES, health_bar_grid_material)
                    health_bar_grid_mesh.surface_add_vertex(line[0])
                    health_bar_grid_mesh.surface_add_vertex(line[1])
                    health_bar_grid_mesh.surface_end()

            var health_bar_grid_length_lines = [
                [Vector3(min_x, max_y, min_z), Vector3(min_x, max_y, max_z)],
                [Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, min_z), Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y, max_z)],
                [Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, min_z), Vector3(min_x, max_y - HEALTH_BAR_CUBE_SIZE, max_z)],
                [Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y - HEALTH_BAR_CUBE_SIZE, min_z), Vector3(min_x + HEALTH_BAR_CUBE_SIZE, max_y - HEALTH_BAR_CUBE_SIZE, max_z)],
            ]

            for line in health_bar_grid_length_lines:
                health_bar_grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES, health_bar_grid_material)
                health_bar_grid_mesh.surface_add_vertex(line[0])
                health_bar_grid_mesh.surface_add_vertex(line[1])
                health_bar_grid_mesh.surface_end()

            add_child(health_bar_grid)

func _process(_delta):
    for child in get_children():
        child.visible = is_selected

    if health_bar and hit_box_component and hit_box_component.get_child(0):
        var hit_box_collision_shape = hit_box_component.get_child(0)
        var hit_box_size = hit_box_collision_shape.shape.size
        var min_z: float = hit_box_size.z / - 2
        var max_z: float = hit_box_size.z / 2
        var health_value = float(health_component.current_health) / float(health_component.max_health)
        var health_bar_length = (max_z - min_z) * health_value
        var health_bar_z_pos = -((max_z - min_z) - health_bar_length) / 2
        health_bar.position = Vector3(health_bar.position.x, health_bar.position.y, health_bar_z_pos)
        health_bar.scale = Vector3(health_bar.scale.x, health_bar.scale.y, health_bar_length)
        var health_bar_material = health_bar.material_override
        health_bar_material.albedo_color = get_health_color(health_value)

func get_health_color(health_value: float) -> Color:
    if health_value > 0.5:
        return Color.GREEN
    elif health_value > 0.25:
        return Color.YELLOW
    elif health_value > 0.0:
        return Color.RED
    else:
        return Color.GREEN

func set_is_selected(value: bool) -> void:
    is_selected = value
    for child in get_children():
        child.visible = is_selected
        
func _on_deselected():
    is_selected = false
    for child in get_children():
        child.visible = is_selected

static func find_select_component(collider):
    var current = collider
    while current:
        if current.has_method("set_is_selected"):
            return current
        if current.has_class("SelectComponent"):
            return current
        
        for child in current.get_children():
            var found = find_select_component(child)
            if found:
                return found
        
        current = current.get_parent()
    return null
    
