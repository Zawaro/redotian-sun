class_name WarheadData extends Resource

## Identity
@export var id: String = ""
## Display name for UI (e.g., "Small Arms", "High Explosive").
@export var display_name: String = ""

## Damage
## Multiplier applied to base weapon damage (1.0 = full damage, 0.5 = half).
@export var damage_modifier: float = 1.0
## Splash radius in cells — area of effect around impact point.
@export var splash_radius: float = 0.0
## Animation played on the target when this warhead kills (e.g., "PIFF", "EXPLOMED").
@export var kill_animation: String = ""

## Armor effectiveness multipliers: [none, wood, light, heavy, concrete].
## Each value is a percentage (0.0–1.0) of base damage applied to that armor type.
## Example: SA = [1.0, 0.6, 0.4, 0.25, 0.1] — shreds infantry, tickles tanks.
@export var armor_damage_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0])

## Terrain/effect flags from rules.ini
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
@export var infantry_death_type: int = 0
## Damage multiplier against prone (crawling) infantry. 1.0 = full damage.
@export var prone_damage_modifier: float = 1.0

## Visual effects
## Animation list played on the target when hit (e.g., "PIFF", "PFFT").
@export var hit_animation: String = ""
## Whether this warhead deforms terrain on impact (craters, scorch marks).
@export var deforms_terrain: bool = false
## Minimum damage threshold required to trigger terrain deformation.
@export var deform_threshold: int = 0
## Whether the projectile renders as a bright/glowing effect on impact.
@export var bright: bool = false


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("WarheadData: id is empty")
    if damage_modifier < 0.0:
        errors.append("%s: damage_modifier must be >= 0" % id)
    if armor_damage_multipliers.size() != 5:
        errors.append("%s: armor_damage_multipliers must have 5 elements [none,wood,light,heavy,concrete]" % id)
    return errors
