# ponytail: thin data wrapper, grows when radar/minimap reveal logic is implemented
class_name RadarComponent extends Node

@export var radar: bool = false


func configure(data: EntityData) -> void:
    radar = data.radar


func has_radar() -> bool:
    return radar
