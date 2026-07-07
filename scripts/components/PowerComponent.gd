# ponytail: thin data wrapper, grows when power grid connections are implemented
class_name PowerComponent extends Node

@export var power: int = 0
@export var powered: bool = false


func configure(data: EntityData) -> void:
    power = data.power
    powered = data.powered


func is_powered() -> bool:
    return powered


func get_power_output() -> int:
    return power
