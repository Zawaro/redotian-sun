# ponytail: thin data wrapper, grows when entity inspection UI or stat modifiers are needed
class_name StatsComponent extends Node

## Emitted when the derived rank changes (kill promotion or an assigned rank).
signal veterancy_changed(level: int)

@export_group("Stats")
@export var id: String = ""
@export var display_name: String = ""
@export var entity_type: int = 0
@export var armor: String = "none"
@export var cost: int = 0
@export var tech_level: int = -1
@export var sight: int = 1
@export var owner_faction: PackedStringArray = []
@export var points: int = 0
## Veteran rank: 0 = rookie, 1 = veteran, 2 = elite. Derived from experience.
@export var veteran_level: int = 0
## Player who owns this entity instance (-1 = unset).
@export var player_id: int = -1
## Whether this entity can crush infantry underfoot.
@export var crusher: bool = false
## Whether this entity can be crushed by larger units.
@export var crushable: bool = false
## Mass — drives breakable-surface (ice) damage. Does not affect speed.
@export var weight: float = 1.0

## Engine-fixed rank thresholds (experience figures; independent of veteran_cap).
const VETERAN_EXPERIENCE := 1.0
const ELITE_EXPERIENCE := 2.0

## Per-instance combat experience. Rank is read off this figure.
var experience: float = 0.0
## Whether kills earned by this entity accumulate experience. Derived by type.
var trainable: bool = false


func configure(data: EntityData) -> void:
    id = data.id
    display_name = data.display_name
    entity_type = data.entity_type
    armor = data.armor
    cost = data.cost
    tech_level = data.tech_level
    sight = data.sight
    owner_faction = data.owner
    points = data.points
    crusher = data.crusher
    crushable = data.crushable
    weight = data.weight
    # Units earn experience by default; buildings opt in (OpenTS Trainable default).
    trainable = data.trainable or is_unit_type(data.entity_type)
    var rules := GlobalRules.get_current()
    if rules and rules.initial_veteran:
        # Elite is the fixed threshold 2, not veteran_cap (rank sources ignore the cap).
        experience = ELITE_EXPERIENCE
    _recompute_rank()


## Credits this entity with a kill worth `victim_cost`. Caller is responsible for
## the trainable, ownership and zero-guard gates (see VeterancySystem).
func add_kill_experience(victim_cost: int) -> void:
    var rules := GlobalRules.get_current()
    if not rules or rules.veteran_ratio <= 0.0 or cost <= 0:
        return
    experience += float(victim_cost) / (float(cost) * rules.veteran_ratio)
    experience = minf(experience, float(rules.veteran_cap))
    _recompute_rank()


func is_infantry() -> bool:
    return entity_type == EntityData.EntityType.INFANTRY


func is_vehicle() -> bool:
    return entity_type == EntityData.EntityType.VEHICLE


func is_structure() -> bool:
    return entity_type == EntityData.EntityType.BUILDING


func is_aircraft() -> bool:
    return entity_type == EntityData.EntityType.AIRCRAFT


func is_unit() -> bool:
    return is_unit_type(entity_type)


## Shared mobile-unit predicate for data-only call sites (no instance needed).
static func is_unit_type(type: int) -> bool:
    return (
        type == EntityData.EntityType.INFANTRY
        or type == EntityData.EntityType.VEHICLE
        or type == EntityData.EntityType.AIRCRAFT
    )


func validate(data: EntityData) -> PackedStringArray:
    var errors: PackedStringArray = []
    if data.id.is_empty():
        errors.append("StatsComponent: id is empty")
    return errors


func _recompute_rank() -> void:
    var new_level := 0
    if experience >= ELITE_EXPERIENCE:
        new_level = 2
    elif experience >= VETERAN_EXPERIENCE:
        new_level = 1
    if new_level != veteran_level:
        veteran_level = new_level
        veterancy_changed.emit(veteran_level)
