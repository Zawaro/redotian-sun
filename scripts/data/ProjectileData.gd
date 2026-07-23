class_name ProjectileData extends Resource

## Projectile type definitions from Tiberian Sun rules.ini [Projectiles] section.
## Defines visual and behavioral properties of projectiles in flight.
## Referenced by WeaponData.projectile as a string ID.

## Identity
@export var id: String = ""
## Display name for UI (e.g., "Invisible", "Cannon Shell", "Heat Seeker").
@export var display_name: String = ""

## Trajectory — controls how the projectile travels from source to target.
# ponytail: schema-first, no consumer yet
@export var is_invisible: bool = false  ## Projectile has no visible model (hitscan-like behavior, instant hit feel).
# ponytail: schema-first, no consumer yet
@export var is_high_arc: bool = false  ## Arcs upward above the unit (elevated launch angle).
# ponytail: schema-first, no consumer yet
@export var is_very_high_arc: bool = false  ## Very high arc used by SAM sites and dedicated anti-air weapons.
# ponytail: schema-first, no consumer yet
@export var is_arcing: bool = false  ## Ballistic path with gravity — lobbed and falls toward target.
# ponytail: schema-first, no consumer yet
@export var is_floater: bool = false  ## Drifts slowly downward after reaching apex (e.g., napalm clouds).
# ponytail: schema-first, no consumer yet
@export var is_bouncy: bool = false  ## Bounces off surfaces on initial impact before detonating.

## Targeting — which unit categories this projectile can lock onto.
# ponytail: schema-first, no consumer yet
@export var targets_air: bool = false  ## Can acquire and hit air units (fighters, bombers, helicopters).
# ponytail: schema-first, no consumer yet
@export var targets_ground: bool = true  ## Can acquire and hit ground units (infantry, vehicles, buildings).
# ponytail: schema-first, no consumer yet
@export var has_proximity_fuse: bool = false  ## Detonates when near target rather than requiring a direct hit.
# ponytail: schema-first, no consumer yet
@export var is_guided: bool = false  ## Homes toward target over distance (guided/seeking projectile).

## Behavior — physical properties during flight.
## Rotation speed in degrees/sec for homing projectiles. 0 = no homing rotation.
# ponytail: schema-first, no consumer yet
@export var homing_turn_rate: int = 0
## Number of frames after firing before projectile can detonate (prevents point-blank explosions).
# ponytail: schema-first, no consumer yet
@export var arm_delay: int = 0
## Number of sub-projectiles spawned on detonation (0 = single projectile, no split).
# ponytail: schema-first, no consumer yet
@export var sub_projectile_count: int = 0
## Custom speed override in cells/tick. 0 = use the weapon's fire speed instead.
# ponytail: schema-first, no consumer yet
@export var speed_override: float = 0.0

## Visuals — appearance during flight.
# ponytail: schema-first, no consumer yet
@export var casts_shadow: bool = false  ## Renders a shadow on the ground below the projectile.
## Graphic or animation name for the projectile model (e.g., "120MM", "DRAGON").
# ponytail: schema-first, no consumer yet
@export var graphic_name: String = ""


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("ProjectileData: id is empty")
    return errors
