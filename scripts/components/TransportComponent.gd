class_name TransportComponent extends Node

signal cargo_changed(current: float, capacity: int, type_id: String)
signal passenger_changed(current: int, max_passengers: int)

## Number of infantry passengers this unit can carry.
@export var passengers: int = 0
## Dock type ID this unit docks with (e.g. "PROC" for refinery).
@export var dock: String = ""
## Whether this unit is a harvester (auto-docks when full).
@export var harvester: bool = false
## Maximum resource bales this unit can carry.
@export var storage: int = 0
## Animation scale key for pip overlays on the sidebar.
@export var pip_scale: String = ""

## Cargo hold — dictionary mapping resource_type_id to bale amount (e.g. {"tiberium_green": 14.5}).
var cargo: Dictionary = {}
## Current number of infantry passengers aboard.
var current_passengers: int = 0


func configure(data: EntityData) -> void:
    passengers = data.passengers
    dock = data.dock
    harvester = data.harvester
    storage = data.storage
    pip_scale = data.pip_scale


func can_carry() -> bool:
    return passengers > 0


func is_harvester() -> bool:
    return harvester


func get_cargo_total() -> float:
    var total := 0.0
    for amount in cargo.values():
        total += amount
    return total


func get_cargo_value(global_rules: GlobalRules) -> int:
    var total := 0.0
    for type_id in cargo:
        var rt: ResourceType = global_rules.get_resource_type(type_id)
        if rt:
            total += cargo[type_id] * rt.value
    return int(total)


## Add resource bales to cargo. Returns actual bales added (limited by remaining capacity).
func add_cargo(type_id: String, amount: float) -> float:
    var space := float(storage) - get_cargo_total()
    var actual := minf(amount, space)
    if actual > 0.0:
        cargo[type_id] = cargo.get(type_id, 0.0) + actual
        cargo_changed.emit(get_cargo_total(), storage, type_id)
    return actual


## Remove resource bales from cargo. Returns actual bales removed.
func remove_cargo(type_id: String, amount: float) -> float:
    var available: float = cargo.get(type_id, 0.0)
    var actual := minf(amount, available)
    if actual > 0.0:
        cargo[type_id] = available - actual
        if cargo[type_id] <= 0.0:
            cargo.erase(type_id)
        cargo_changed.emit(get_cargo_total(), storage, type_id)
    return actual


## Add a passenger. Returns false if at capacity.
func add_passenger() -> bool:
    if current_passengers >= passengers:
        return false
    current_passengers += 1
    passenger_changed.emit(current_passengers, passengers)
    return true


## Remove a passenger. Returns false if empty.
func remove_passenger() -> bool:
    if current_passengers <= 0:
        return false
    current_passengers -= 1
    passenger_changed.emit(current_passengers, passengers)
    return true
