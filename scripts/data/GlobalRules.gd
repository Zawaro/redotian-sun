class_name GlobalRules extends Resource

## Veterancy
@export var veteran_ratio: float = 10.0
@export var veteran_cap: int = 2
@export var initial_veteran: bool = false

## Veterancy multipliers per level
@export var veteran_combat: float = 0.25
@export var veteran_speed: float = 0.30
@export var veteran_sight: float = 0.0
@export var veteran_armor: float = 0.25
@export var veteran_rof: float = 0.20

## Repair and refit
@export var refund_percent: float = 0.5
@export var reload_rate: float = 0.5
@export var repair_percent: float = 0.2
@export var repair_rate: float = 0.016
@export var repair_step: int = 8
@export var unit_repair_rate: float = 0.016
@export var infantry_repair_rate: float = 0.001
@export var infantry_repair_step: int = 1

## Income and production
@export var build_speed: float = 0.8
@export var buildup_time: float = 0.06
## Minutes between crystal timer ticks (randomized ±60s).
@export var growth_rate: float = 5.0
## Whether tiberium crystals grow denser over time.
@export var tiberium_grows: bool = true
## Whether tiberium spreads into adjacent cells.
@export var tiberium_spreads: bool = true
@export var starting_credits: int = 0
@export var tiberium_value: float = 1.0
@export var harvester_fill_rate: float = 2.0
@export var separate_aircraft: bool = true
@export var survivor_rate: float = 0.4
@export var survivor_divisor: int = 100
@export var placement_delay: float = 0.05
@export var weed_capacity: int = 56

## Tiberium growth
## Minutes between tree timer ticks (randomized ±60s).
@export var tree_growth_rate: float = 3.0
## Radius (cells) around tree where new tiberium spawns (e.g. 3 = 7x7 area).
@export var tree_spawn_radius: int = 3
## Trees processed per tree timer tick.
@export var growth_batch_trees: int = 10
## Tiberium entities processed per tiberium timer tick.
@export var growth_batch_crystals: int = 500
## Tiberium amount for a newly spawned entity from spreading.
@export var spread_amount: int = 50
## Max times a single tiberium entity can spread before it only self-grows.
@export var spread_max: int = 3

## Computer and movement controls
@export var base_bias: int = 2
@export var base_defense_delay: float = 0.25
@export var close_enough: float = 2.25
@export var damage_delay: float = 1.0
@export var game_speed_bias: float = 1.0
@export var stray: float = 2.0
@export var flight_level: int = 600

## Hover vehicle characteristics
@export var hover_height: int = 120
@export var hover_dampen: float = 0.4
@export var hover_bob: float = 0.04
@export var hover_boost: float = 1.5
@export var hover_acceleration: float = 0.02
@export var hover_brake: float = 0.03

## Production and power effects
@export var multiple_factory: float = 0.5
@export var min_production_speed: float = 0.5

## Movement coefficients
@export var tracked_uphill: float = 0.5
@export var tracked_downhill: float = 1.1
@export var wheeled_uphill: float = 0.5
@export var wheeled_downhill: float = 1.2

## Armor types (customizable dictionary)
@export var armor_types: Dictionary = {
    "none": {"modifier": 1.0},
    "wood": {"modifier": 0.7},
    "light": {"modifier": 0.6},
    "heavy": {"modifier": 0.4},
    "concrete": {"modifier": 0.3},
}

## Misc
@export var fog_of_war: bool = false
@export var visceroids: bool = false
@export var meteorites: bool = false
@export var crew_escape: float = 0.5
@export var camera_range: int = 9
@export var maximum_queued_objects: int = 4


func get_armor_modifier(armor_type: String) -> float:
    if armor_types.has(armor_type):
        return armor_types[armor_type].get("modifier", 1.0)
    return 1.0
