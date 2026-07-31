class_name WarheadData extends Resource

## Identity
@export_group("Identity")
@export var id: String = ""
## Display name for UI (e.g., "Small Arms", "High Explosive").
@export var display_name: String = ""

## Damage
@export_group("Damage")
## Multiplier applied to base weapon damage (1.0 = full damage, 0.5 = half).
@export var damage_modifier: float = 1.0
## Splash radius in cells — area of effect around impact point.
@export var splash_radius: float = 0.0
## Animation played on the target when this warhead kills (e.g., "PIFF", "EXPLOMED").
@export var kill_animation: String = ""

@export_group("Armor Multipliers")
## Armor effectiveness multipliers keyed by armor type id (from GlobalRules.armor_types).
## Each value is a percentage of base damage applied to that armor type, e.g.
## SA = {"none": 1.0, "wood": 0.6, "light": 0.4, "heavy": 0.25, "concrete": 0.1}.
## Values may exceed 1.0 (overkill warheads like Fire) or be 0.0 (no damage).
@export var armor_damage_multipliers: Dictionary = {}

## Terrain/effect flags from rules.ini
@export_group("Terrain and Effect Flags")
@export var can_damage_walls: bool = false  ## Can damage walls
@export var can_damage_wood: bool = false  ## Can damage wood/trees
@export var can_damage_tiberium: bool = false  ## Can damage tiberium crystals
@export var sets_on_fire: bool = false  ## Sets targets on fire
@export var is_conventional: bool = false  ## Standard explosive (affects debris, rubble)
@export var produces_sparks: bool = false  ## Produces spark particles on impact
@export var rocks_target: bool = false  ## Rocks the target on impact (visual shake)

## Infantry death type — determines which death animation plays (1–5).
## 0 = no special death, 1 = small puff, 2 = medium explosion, 3 = gory,
## 4 = fire/burn, 5 = special (e.g., obelisk disintegration).
@export_group("Infantry Death")
@export var infantry_death_type: int = 0
## Damage multiplier against prone (crawling) infantry. 1.0 = full damage.
@export var prone_damage_modifier: float = 1.0

## Visual effects
@export_group("Visual Effects")
## Animation list played on the target when hit (e.g., "PIFF", "PFFT").
@export var hit_animation: String = ""
## Whether this warhead deforms terrain on impact (craters, scorch marks).
@export var deforms_terrain: bool = false
## Minimum damage threshold required to trigger terrain deformation.
@export var deform_threshold: int = 0
## Whether the projectile renders as a bright/glowing effect on impact.
@export var bright: bool = false


func get_armor_multiplier(armor_type: String) -> float:
    return float(armor_damage_multipliers.get(armor_type, 1.0))


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("WarheadData: id is empty")
    if damage_modifier < 0.0:
        errors.append("%s: damage_modifier must be >= 0" % id)
    if armor_damage_multipliers.is_empty():
        errors.append("%s: armor_damage_multipliers must not be empty" % id)
    if Engine.is_editor_hint():
        return errors
    var main_loop := Engine.get_main_loop()
    if not main_loop:
        return errors
    var entity_factory: Node = main_loop.root.get_node_or_null("EntityFactory")
    var rules: GlobalRules = entity_factory.get_global_rules() if entity_factory else null
    if not rules:
        return errors
    var armor_ids: Array[String] = rules.get_armor_ids()
    for armor_id in armor_ids:
        if not armor_damage_multipliers.has(armor_id):
            errors.append(
                "%s: armor_damage_multipliers missing entry for armor type '%s'" % [id, armor_id]
            )
    for key in armor_damage_multipliers:
        if not armor_ids.has(key):
            errors.append(
                "%s: armor_damage_multipliers references unknown armor type '%s'" % [id, key]
            )
    return errors
