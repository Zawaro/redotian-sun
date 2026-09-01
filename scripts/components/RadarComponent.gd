# ponytail: thin data wrapper, grows when radar/minimap reveal logic is implemented
class_name RadarComponent extends Node

@export var radar: bool = false


func configure(data: EntityData) -> void:
    radar = data.radar


## True only when the entity has radar capability AND is powered. Entities
## without a PowerComponent are always considered powered.
func has_radar() -> bool:
    if not radar:
        return false
    var parent := get_parent()
    if parent == null:
        return true
    var pc := parent.get_node_or_null("PowerComponent") as PowerComponent
    if pc:
        return pc.is_online
    return true
