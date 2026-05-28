extends Node

@export var enabled: bool = true

var _meshes: Dictionary = {}
var _cached_immeshes: Dictionary = {}
var _cached_materials: Dictionary = {}

func _get_or_create_material(material_name: String, color: Color) -> ORMMaterial3D:
	var key: String = material_name
	if _cached_materials.has(key):
		return _cached_materials[key]
	var mat := ORMMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	_cached_materials[key] = mat
	return mat

func draw_path(entity_id: String, start_pos: Vector3, waypoints: PackedVector3Array, reached_index: int) -> void:
	if not enabled:
		return

	var mesh_instance: MeshInstance3D
	if not _meshes.has(entity_id):
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "DebugPath_" + entity_id
		mesh_instance.top_level = true
		add_child(mesh_instance)
		_meshes[entity_id] = mesh_instance
	else:
		mesh_instance = _meshes[entity_id]

	var immesh: ImmediateMesh
	if _cached_immeshes.has(entity_id):
		immesh = _cached_immeshes[entity_id]
		immesh.clear_surfaces()
	else:
		immesh = ImmediateMesh.new()
		_cached_immeshes[entity_id] = immesh
	mesh_instance.mesh = immesh

	var reached_material := _get_or_create_material("reached", Color(0.5, 0.5, 0.5, 0.6))
	var remaining_material := _get_or_create_material("remaining", Color(0.0, 1.0, 0.0, 0.8))

	var start := start_pos
	start.y = 0.1
	var prev_point: Vector3 = mesh_instance.to_local(start)

	for i in waypoints.size():
		var wp_world := waypoints[i]
		wp_world.y = 0.1
		var wp_local := mesh_instance.to_local(wp_world)
		var mat := reached_material if i < reached_index else remaining_material

		immesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
		immesh.surface_add_vertex(prev_point)
		immesh.surface_add_vertex(wp_local)
		immesh.surface_end()

		prev_point = wp_local


func clear_path(entity_id: String) -> void:
	if not _meshes.has(entity_id):
		return
	var mesh_instance: MeshInstance3D = _meshes[entity_id]
	if is_instance_valid(mesh_instance):
		remove_child(mesh_instance)
		mesh_instance.queue_free()
	_meshes.erase(entity_id)
	_cached_immeshes.erase(entity_id)


func clear_all() -> void:
	for entity_id in _meshes.keys():
		clear_path(entity_id)