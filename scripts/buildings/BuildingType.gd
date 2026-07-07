class_name BuildingType extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var footprint: Vector2i = Vector2i(2, 2)
@export var scene: PackedScene
@export var cameo: Texture2D
@export var cost: int = 0
@export var build_time: float = 0.0
