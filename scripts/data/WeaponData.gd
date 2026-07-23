class_name WeaponData extends Resource

## Identity
@export var id: String = ""
## Display name for UI (e.g., "Minigun", "90mm Cannon").
@export var display_name: String = ""

## Damage
@export var damage: int = 0
## Rate of fire — shots per minute (higher = faster). TS formula: ROF = 60 / seconds_between_shots.
@export var rate_of_fire: float = 1.0
## Maximum engagement range in cells.
@export var attack_range: float = 1.0
## Minimum range — unit cannot fire closer than this (e.g., artillery).
@export var minimum_range: float = 0.0

## Warhead ID reference (e.g., "SA", "HE", "AP").
@export var warhead: String = "HE"
## Projectile ID reference (e.g., "Invisible", "Cannon", "AAHeatSeeker2").
@export var projectile: String = ""

## Fire position offset (Front-Length-Height) in voxels relative to the unit.
@export var fire_offset: Vector3 = Vector3.ZERO
## Barrel length in voxels — affects muzzle flash position and line-of-sight origin.
@export var barrel_length: float = 0.0

## Targeting flags
@export var anti_air: bool = false
@export var anti_ground: bool = true

## Burst count — number of shots per attack cycle (e.g., Burst=2 fires two rounds then pauses).
@export var burst: int = 1

## Lobber — projectile arcs upward then drops (artillery-style trajectory).
@export var is_lobber: bool = false
## Charges — weapon must charge before firing (e.g., Obelisk of Light).
@export var requires_charge: bool = false
## Is laser — renders as a continuous laser beam instead of projectile.
@export var is_laser: bool = false

## Splash radius in cells (0 = no splash damage).
@export var splash_radius: float = 0.0
## Ammo count (-1 = unlimited).
@export var ammo: int = -1

## Animation name played when this weapon fires (e.g., "GUNFIRE", "MGUN-N").
@export var fire_animation: String = ""
## Sound report(s) played when firing — comma-separated IDs (e.g., "INFGUN3,GOSTGUN1").
@export var sound_report: String = ""

## Ambient damage per tick — used for continuous-damage weapons (e.g., sonic, flame).
## Separate from per-shot damage; applied while the weapon is active.
@export var ambient_damage: int = 0

## Special weapon types
## Fires a hitscan railgun beam (instant hit, no projectile travel).
@export var is_railgun: bool = false
## Fires a continuous sonic wave (area damage in a line).
@export var is_sonic: bool = false
## Speed boost applied to the unit while this weapon is active.
@export var turbo_boost: float = 0.0
## Attached particle system that plays while the weapon fires (e.g., flame trail).
@export var attached_particle_system: String = ""
## Uses fire-colored particles for muzzle/trail effects.
@export var use_fire_particles: bool = false
## Uses spark-colored particles for muzzle/trail effects.
@export var use_spark_particles: bool = false
## Whether the projectile renders as a bright/glowing effect.
@export var bright: bool = false


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("WeaponData: id is empty")
    if damage < 0 and ambient_damage <= 0:
        errors.append("%s: damage must be >= 0" % id)
    if attack_range <= 0.0:
        errors.append("%s: range must be > 0" % id)
    return errors
