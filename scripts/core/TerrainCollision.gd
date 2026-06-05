extends Node

const TERRAIN_GLB_PATH: String = "res://assets/models/terrain/placeholder_terrain01.glb"

var _collision_bodies: Dictionary = {}
var _collision_parent: Node3D
var _terrain_scene: PackedScene
var _mesh_cache: Dictionary = {}

func _ready() -> void:
	_terrain_scene = load(TERRAIN_GLB_PATH) as PackedScene
	_build_mesh_cache()
	_collision_parent = Node3D.new()
	_collision_parent.name = "TerrainCollision"
	add_child(_collision_parent)
	TerrainSystem.cell_changed.connect(_on_cell_changed)
	for key in TerrainSystem.get_all_cells():
		_on_cell_changed(key, TerrainSystem.get_all_cells()[key])

func _build_mesh_cache() -> void:
	var instance := _terrain_scene.instantiate()
	_collect_meshes(instance)
	instance.queue_free()

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var clean_name := node.name.trim_suffix("_3D")
		if not _mesh_cache.has(clean_name):
			_mesh_cache[clean_name] = node.mesh.duplicate()
	for child in node.get_children():
		_collect_meshes(child)

func _exit_tree() -> void:
	if TerrainSystem.cell_changed.is_connected(_on_cell_changed):
		TerrainSystem.cell_changed.disconnect(_on_cell_changed)
	clear_all()

func create_collision(cell: Vector2i, data: Dictionary, mesh: Mesh) -> void:
	var key := _cell_key(cell)
	remove_collision(cell)
	var static_body := StaticBody3D.new()
	static_body.name = "Collision_" + key
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	var collision_shape_node := CollisionShape3D.new()
	collision_shape_node.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape_node)
	var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
	var world_pos := Pathfinder.cell_to_world(cell) - Vector3(grid_half, 0, grid_half)
	var height: int = data.get("height", 0)
	world_pos.y = height * TerrainSystem.HEIGHT_STEP
	var rotation: float = data.get("rotation", 0.0)
	static_body.rotation.y = deg_to_rad(rotation)
	static_body.position = world_pos
	_collision_parent.add_child(static_body)
	_collision_bodies[key] = static_body

func remove_collision(cell: Vector2i) -> void:
	var key := _cell_key(cell)
	var body: StaticBody3D = _collision_bodies.get(key)
	if body:
		_collision_parent.remove_child(body)
		body.queue_free()
		_collision_bodies.erase(key)

func clear_all() -> void:
	for key in _collision_bodies:
		var body: StaticBody3D = _collision_bodies[key]
		if is_instance_valid(body):
			_collision_parent.remove_child(body)
			body.queue_free()
	_collision_bodies.clear()

func _on_cell_changed(cell_key: String, cell_data: Dictionary) -> void:
	var parts := cell_key.split(",")
	if parts.size() == 2:
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if cell_data.is_empty():
			remove_collision(cell)
		else:
			var mesh_data := cell_data
			if not mesh_data.has("type"):
				mesh_data = TerrainSystem.calculate_cell_mesh(cell)
			var terrain_type: String = mesh_data.get("type", "clear")
			var variant: int = mesh_data.get("variant", 1)
			var mesh := _get_cached_mesh(terrain_type, variant)
			if mesh:
				create_collision(cell, mesh_data, mesh)

func _cell_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)

func _get_cached_mesh(terrain_type: String, variant: int) -> Mesh:
	var mesh_name := _get_mesh_name(terrain_type, variant)
	return _mesh_cache.get(mesh_name, null)

func _get_mesh_name(terrain_type: String, variant: int) -> String:
	var prefix := ""
	match terrain_type:
		"clear":
			prefix = "clear"
		"slope":
			prefix = "slope"
		"cliff":
			prefix = "cliff"
		_:
			prefix = "clear"
	return prefix + str(variant).pad_zeros(2)

func _find_mesh_node(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name.begins_with(mesh_name):
		return node
	for child in node.get_children():
		var result := _find_mesh_node(child, mesh_name)
		if result:
			return result
	return null