# ponytail: thin data wrapper, grows when power grid connections are implemented
class_name PowerComponent extends Node

## Emitted when the owning player's grid crosses the low-power boundary.
signal power_state_changed(is_online: bool)

@export var power: int = 0
## Data flag: this structure requires power to function (shuts down in low power).
@export var powered: bool = false

## Runtime grid state — true unless the owner's grid is in deficit.
## Deliberately not `is_powered`: that name means the data flag.
var is_online: bool = true


func configure(data: EntityData) -> void:
    power = data.power
    powered = data.powered


func is_powered() -> bool:
    return powered


func get_power_output() -> int:
    return power


## Called by PowerGrid when the owning player's grid crosses the low-power
## boundary. Emits only on an actual state change.
func set_online(online: bool) -> void:
    if is_online == online:
        return
    is_online = online
    power_state_changed.emit(is_online)
