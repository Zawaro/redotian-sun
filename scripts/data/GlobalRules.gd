class_name GlobalRules extends Resource

## Veterancy
@export_group("Veterancy")
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
@export_group("Repair and Refit")
@export var refund_percent: float = 0.5
@export var reload_rate: float = 0.5
@export var repair_percent: float = 0.2
@export var repair_rate: float = 0.016
@export var repair_step: int = 8
@export var unit_repair_rate: float = 0.016
@export var infantry_repair_rate: float = 0.001
@export var infantry_repair_step: int = 1

## Income and production
@export_group("Income and Production")
@export var build_speed: float = 0.4
@export var buildup_time: float = 0.06
## Minutes between crystal timer ticks (randomized ±60s).
@export var growth_rate: float = 5.0
## Whether resource crystals grow denser over time.
@export var resource_grows: bool = true
## Whether resources spread into adjacent cells.
@export var resource_spreads: bool = true
@export var starting_credits: int = 0
@export var harvester_fill_rate: float = 2.0
@export var separate_aircraft: bool = true
@export var survivor_rate: float = 0.4
@export var survivor_divisor: int = 100
@export var placement_delay: float = 0.05
@export var weed_capacity: int = 56

## Transports
@export_group("Transports")
## Seconds between passenger ejects while a transport unloads (one passenger per interval).
@export var unload_interval: float = 0.25

## Tiberium growth
@export_group("Tiberium Growth")
## Minutes between tree timer ticks (randomized ±60s).
@export var tree_growth_rate: float = 3.0
## Radius (cells) around tree where new resource crystals spawn (e.g. 3 = 7x7 area).
@export var tree_spawn_radius: int = 3
## Trees processed per tree timer tick.
@export var growth_batch_trees: int = 10
## Resource entities processed per resource timer tick.
@export var growth_batch_crystals: int = 500
## Bales of resource created when spreading to a new cell (0.01-0.5).
@export var spread_amount: float = 0.5
## Max times a single resource entity can spread before it only self-grows.
@export var spread_max: int = 3

## Computer and movement controls
@export_group("Computer and Movement Controls")
@export var base_bias: int = 2
@export var base_defense_delay: float = 0.25
@export var close_enough: float = 2.25
@export var damage_delay: float = 1.0
@export var game_speed_bias: float = 1.0
@export var stray: float = 2.0
@export var flight_level: int = 600

## Hover vehicle characteristics
@export_group("Hover Vehicle Characteristics")
@export var hover_height: int = 120
@export var hover_dampen: float = 0.4
@export var hover_bob: float = 0.04
@export var hover_boost: float = 1.5
@export var hover_acceleration: float = 0.02
@export var hover_brake: float = 0.03

## Production and power effects
@export_group("Production and Power Effects")
## TS rules.ini [General] MultipleFactory=.4 — speed bonus per extra factory.
@export var multiple_factory: float = 0.4
@export var min_production_speed: float = 0.5
## TS rules.ini [General] WorstLowPowerBuildRate=.3 — production rate at full blackout.
@export var worst_low_power_build_rate_coefficient: float = 0.3
## TS rules.ini [General] BestLowPowerBuildRate=.75 — production rate just below full power.
@export var best_low_power_build_rate_coefficient: float = 0.75

## Movement coefficients
@export_group("Movement Coefficients")
@export var tracked_uphill: float = 0.5
@export var tracked_downhill: float = 1.1
@export var wheeled_uphill: float = 0.5
@export var wheeled_downhill: float = 1.2
## Weight threshold for breakable-surface (ice) damage, from rules.ini [General].
@export var ice_cracking_weight: float = 2.0
## Extra pathfinding cost for traversing bib cells. High enough to divert
## ordinary traffic around building pads, low enough that dockers (harvesters)
## and emergency crossers can still pass.
@export var bib_cost_penalty: float = 6.0
## Ramp constants for locomotor Accelerate/Decelerate flags (time-based, scale-free).
@export var ramp_accel_time: float = 0.75
@export var ramp_decel_time: float = 0.5
@export var ramp_crawl_fraction: float = 0.15

@export_group("Cell Occupancy")
## Max units whose Locomotor has shares_cell = true that may occupy one cell.
@export var shared_slots_per_cell: int = 3

@export_group("Land Types")
## Land type registry — maps land type id to LandType resource.
@export var land_types: Dictionary = {}

@export_group("Locomotors")
## Locomotor registry — maps locomotor id to Locomotor resource.
@export var locomotors: Dictionary = {}

@export_group("Combat Damage")
## Minimum damage after all adjustments, from rules.ini [CombatDamage] MinDamage.
@export var min_damage: int = 1
## Maximum damage after all adjustments, from rules.ini [CombatDamage] MaxDamage.
@export var max_damage: int = 1000

@export_group("Armor Types")
## Armor type registry — maps armor type id to ArmorType resource.
@export var armor_types: Dictionary = {}

@export_group("Warheads")
## Warhead registry — maps warhead id to WarheadData resource.
@export var warheads: Dictionary = {}

@export_group("Projectiles")
## Projectile registry — maps projectile id to ProjectileData resource.
@export var projectiles: Dictionary = {}
## Fallback flight speed in world units per second when neither
## ProjectileData.speed_override nor WeaponData.speed is set.
@export var default_projectile_speed: float = 12.0

@export_group("Resource Types")
## Resource type definitions — maps resource ID to ResourceType.
## Each holds value, grow_rate, spread_amount, spread_max, color.
@export var resource_types: Dictionary = {}

## Misc
@export_group("Misc")
@export var shroud_enabled: bool = true
@export var fog_of_war: bool = false
@export var shroud_grows: bool = false
@export var shroud_growth_interval: float = 10.0
@export var visceroids: bool = false
@export var meteorites: bool = false
@export var crew_escape: float = 0.5
@export var camera_range: int = 9
@export var maximum_queued_objects: int = 4


func get_armor_type(armor_type_id: String) -> ArmorType:
    return armor_types.get(armor_type_id) as ArmorType


## Returns the active GlobalRules resource loaded by the EntityFactory autoload,
## or null when unavailable (editor context, tests before autoloads exist).
static func get_current() -> GlobalRules:
    var main_loop := Engine.get_main_loop()
    if not main_loop:
        return null
    var root: Node = main_loop.root
    var entity_factory: Node = root.get_node_or_null("EntityFactory")
    if entity_factory and entity_factory.has_method("get_global_rules"):
        return entity_factory.get_global_rules() as GlobalRules
    return null


func get_armor_ids() -> Array[String]:
    var result: Array[String] = []
    for key in armor_types:
        result.append(String(key))
    return result


func get_warhead(warhead_id: String) -> WarheadData:
    return warheads.get(warhead_id) as WarheadData


func get_projectile(projectile_id: String) -> ProjectileData:
    return projectiles.get(projectile_id) as ProjectileData


## Shared damage math for both dispatch paths (direct hitscan fallback and
## projectile payloads): warhead armor multiplier for the victim's armor type,
## clamped to [min_damage, max_damage]; a zero multiplier means no damage.
## Returns base_damage unchanged when no rules are active. Single source of
## truth so the two paths cannot drift.
static func compute_warhead_damage(base_damage: int, warhead_id: String, armor_id: String) -> int:
    var rules := get_current()
    if not rules:
        return base_damage
    var mult := rules.get_warhead_armor_multiplier(warhead_id, armor_id)
    if mult > 0.0:
        return clampi(roundi(base_damage * mult), rules.min_damage, rules.max_damage)
    return 0


func get_land_type(land_type_id: String) -> LandType:
    return land_types.get(land_type_id) as LandType


func get_locomotor(locomotor_id: String) -> Locomotor:
    return locomotors.get(locomotor_id) as Locomotor


## Validates every registered Locomotor's terrain speed keys against the land
## type registry. Returns errors for unknown land type references.
func validate_locomotor_keys() -> PackedStringArray:
    var errors: PackedStringArray = []
    for key in locomotors:
        var lm := locomotors[key] as Locomotor
        if lm:
            for land_id in lm.terrain_speeds:
                if not land_types.has(land_id):
                    errors.append("Locomotor %s: unknown land type %s" % [lm.id, land_id])
    return errors


## Validates every registered warhead's armor multiplier keys against the armor
## type registry. Returns errors for missing and unknown armor entries.
func validate_warhead_armor_keys() -> PackedStringArray:
    var errors: PackedStringArray = []
    var armor_ids := get_armor_ids()
    for warhead in warheads.values():
        var wh := warhead as WarheadData
        if wh:
            errors.append_array(wh.validate_against_armor(armor_ids))
    return errors


## Validates the cell-occupancy configuration. Returns errors when the shared
## per-cell slot count is below the minimum of 1.
func validate_cell_occupancy() -> PackedStringArray:
    var errors: PackedStringArray = []
    if shared_slots_per_cell < 1:
        errors.append("shared_slots_per_cell must be >= 1, got %d" % shared_slots_per_cell)
    return errors


func _veteran_multiplier(base: float, level: int) -> float:
    return 1.0 + base * float(clampi(level, 0, veteran_cap))


## Combat damage multiplier for a veteran level (level clamped to veteran_cap).
func get_veteran_combat_multiplier(level: int) -> float:
    return _veteran_multiplier(veteran_combat, level)


## Speed multiplier for a veteran level (level clamped to veteran_cap).
func get_veteran_speed_multiplier(level: int) -> float:
    return _veteran_multiplier(veteran_speed, level)


## Armor (incoming damage) multiplier for a veteran level (level clamped to veteran_cap).
func get_veteran_armor_multiplier(level: int) -> float:
    return _veteran_multiplier(-veteran_armor, level)


## Returns the damage multiplier a warhead applies against a given armor type,
## defaulting to 1.0 (full damage) for unknown warheads or armor types.
func get_warhead_armor_multiplier(warhead_id: String, armor_type: String) -> float:
    var warhead := get_warhead(warhead_id)
    if not warhead:
        return 1.0
    return warhead.get_armor_multiplier(armor_type)


func get_resource_type(id: String) -> ResourceType:
    return resource_types.get(id) as ResourceType


func get_resource_category(resource_id: String) -> String:
    var rt := get_resource_type(resource_id)
    if rt and not rt.category.is_empty():
        return rt.category
    return resource_id


func get_subtypes(category_id: String) -> Array[String]:
    var result: Array[String] = []
    for id in resource_types:
        var rt: ResourceType = resource_types[id]
        if rt.category == category_id or rt.parent_type == category_id:
            result.append(id)
    return result
