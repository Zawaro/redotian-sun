extends Node3D

@export var terrain_json_path: String = "res://assets/test_terrain.json"

func _ready() -> void:
	_load_terrain()

func _load_terrain() -> void:
	if FileAccess.file_exists(terrain_json_path):
		TerrainSystem.import_from_json(terrain_json_path)
		return
	_create_test_terrain()

func _create_test_terrain() -> void:
	# Build a 6x6 plateau centered on the map, raised to height 2
	var half := floori(TerrainSystem.grid_cells * 0.5)
	for x in range(half - 3, half + 3):
		for z in range(half - 3, half + 3):
			TerrainSystem.raise_cell(Vector2i(x, z))
			TerrainSystem.raise_cell(Vector2i(x, z))

	# Export the test terrain for reuse
	TerrainSystem.export_to_json(terrain_json_path)