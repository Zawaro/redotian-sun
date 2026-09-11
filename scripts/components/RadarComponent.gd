class_name RadarComponent extends Node

## Emitted when the entity's effective radar state flips — including flips
## driven by power changes. Not emitted for the initial seeded state.
signal radar_state_changed(is_active: bool)

@export var radar: bool = false

## Cached effective state; compared to `has_radar()` so the signal fires only on
## an actual flip.
var _is_active: bool = false
var _power: PowerComponent = null


func configure(data: EntityData) -> void:
    radar = data.radar
    # Seed silently — configure runs before _ready on the spawn path, and a
    # component that arrives already powered down must not announce a flip that
    # never happened.
    _is_active = has_radar()


func _ready() -> void:
    _resolve_power()
    _is_active = has_radar()


## Resolves and subscribes to the sibling PowerComponent. Absent in tests and
## on radar entities that do not require power; `has_radar()` treats that as
## always powered.
func _resolve_power() -> void:
    var parent := get_parent()
    if parent == null:
        return
    _power = parent.get_node_or_null("PowerComponent") as PowerComponent
    if _power and not _power.power_state_changed.is_connected(_on_power_state_changed):
        _power.power_state_changed.connect(_on_power_state_changed)


func _on_power_state_changed(_is_online: bool) -> void:
    var active := has_radar()
    if active == _is_active:
        return
    _is_active = active
    radar_state_changed.emit(_is_active)


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
