class_name FactoryComponent extends Node

## Building-level production interface. Declares what queue types this
## building produces and manages primary building selection.

## Queue types this building handles (e.g., ["infantry"], ["vehicle"]).
@export var produces: Array[String] = []

## Whether this factory is the primary exit for its queue type.
@export var is_primary: bool = false

## Player ID that owns this factory.
var player_id: int = -1

## Whether a unit is currently exiting (door animation + movement).
var is_busy: bool = false

## Emitted when a unit is exiting (factory is busy).
signal exit_in_progress


func _ready() -> void:
    add_to_group("factories")


func configure(data: EntityData) -> void:
    if not data.factory.is_empty():
        produces = [data.factory]
    call_deferred("_sync_player_id")


func _sync_player_id() -> void:
    var stats := get_parent().get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        player_id = stats.player_id


func set_primary() -> void:
    is_primary = true
    var factories := get_tree().get_nodes_in_group("factories")
    for f in factories:
        if f == self:
            continue
        if not f is FactoryComponent:
            continue
        var other := f as FactoryComponent
        if other.player_id != player_id:
            continue
        if other.produces != produces:
            continue
        other.is_primary = false


func on_unit_produced(entity_data: EntityData, owner_player_id: int) -> void:
    var building := get_parent() as Node3D
    if not building:
        return

    # Spawn at building center — ExitComponent will reposition if present
    var unit := EntityPlacer.place_entity(entity_data, building.global_position, owner_player_id)
    if not unit:
        return

    # Let ExitComponent handle positioning, exit movement, and rally point
    var exit := building.get_node_or_null("ExitComponent")
    if exit:
        # Only block factory during exit delay (war factory door animation)
        if exit.exit_delay > 0.0:
            is_busy = true
        if not exit.exit_completed.is_connected(_on_exit_completed):
            exit.exit_completed.connect(_on_exit_completed)
        exit.on_unit_produced(unit)

    exit_in_progress.emit()


func _on_exit_completed() -> void:
    is_busy = false
