class_name EntityData extends Resource

## Entity type enum
enum EntityType { INFANTRY, VEHICLE, BUILDING, AIRCRAFT, TERRAIN, OVERLAY, SMUDGE }

## Identity
@export var id: String = ""
## Display name shown in UI (e.g., "Minigunner", "Harvester").
@export var display_name: String = ""
## Category of this entity — determines sidebar tab, production queue, and valid behaviors.
@export var entity_type: EntityType = EntityType.TERRAIN
## Original rules.ini section ID for cross-referencing (e.g., "GACNST", "GAPOWR").
@export var legacy_id: String = ""

## Core stats
## Maximum hit points. Entity is destroyed when health reaches 0.
@export var strength: int = 0
## Health percentage (0–100) at which this entity spawns. -1 = use full strength.
@export var spawn_health: int = 0
## Armor type string (e.g., "none", "wood", "light", "heavy", "concrete").
@export var armor: String = "none"
## Cost in credits to produce this entity.
@export var cost: int = 0
## Tech level required to build. -1 = always available, 0 = needs prerequisite, etc.
@export var tech_level: int = -1
## Sight range in cells — how far this entity can see on the map.
@export var sight: int = 1
## Whether this entity can be selected by dragging a box over it.
@export var is_drag_selectable: bool = true
## Player IDs that can own this entity (e.g., ["GDI", "Nod"]).
@export var owner: PackedStringArray = []
## Score points awarded for killing this entity.
@export var points: int = 0
## Entity IDs to spawn on death (e.g., ["GDI_BUILDING_RUBBLE"] for debris).
@export var death_explosion_ids: PackedStringArray = []

## Combat
## Weapons this entity uses when attacking.
@export var weapons: Array[WeaponData] = []
## Weapons used when this unit is elite (promoted). Empty = use normal weapons.
@export var elite_weapons: Array[WeaponData] = []
## Whether this entity has a rotating turret.
@export var turret: bool = false
## Animation name for the turret rotation (e.g., "TURRET").
@export var turret_anim: String = ""
## Threat level for AI targeting (higher = prioritized). 0 = no threat.
@export var threat_posed: int = 0

## Movement
## Movement speed in cells per tick. 0 = immobile.
@export var speed: float = 0.0
## Movement zone — which terrain types this entity can traverse (e.g., "foot", "track", "float").
@export var movement_zone: String = ""
## Locomotor type — determines movement behavior and animation (e.g., "Walk", "Drive", "Fly").
@export var locomotor: String = ""
## Rotation speed in degrees per second when turning.
@export var rotation_speed: float = 180.0
## Whether this entity can crush infantry underfoot.
@export var crusher: bool = false
## Whether this entity can be crushed by larger units.
@export var crushable: bool = false
## Weight class — affects crushing interactions (heavier units crush lighter ones).
@export var weight: float = 1.0

## Vehicle behavior
## Unit cannot fire while moving.
# ponytail: schema-first, no consumer yet
@export var no_moving_fire: bool = false
## Unit must deploy before firing (e.g., artillery, tick tank).
# ponytail: schema-first, no consumer yet
@export var deploy_to_fire: bool = false
## Speed factor for cloaking transition (0 = instant, higher = slower).
# ponytail: schema-first, no consumer yet
@export var cloaking_speed: float = 0.0
## Whether this unit can be promoted to elite status.
# ponytail: schema-first, no consumer yet
@export var trainable: bool = false
## Whether this unit can pick up crate power-ups.
# ponytail: schema-first, no consumer yet
@export var crate_goodie: bool = false
## Whether this unit tilts visually on sloped terrain.
# ponytail: schema-first, no consumer yet
@export var is_tilter: bool = false
## Turret spins continuously when unit is idle.
# ponytail: schema-first, no consumer yet
@export var turret_spins: bool = false
## Unit has a visible targeting laser beam.
# ponytail: schema-first, no consumer yet
@export var target_laser: bool = false

## Foundation
## Footprint in cells (width × depth) — determines placement grid and collision.
@export var foundation: Vector2i = Vector2i(1, 1)
## Visual height in world units — affects bounding box and selection overlay.
@export var height: float = 1.0
## Cells that form the building's bib (the raised foundation edge).
@export var bib_cells: Array[Vector2i] = []
## 3D hitbox size in world units for projectile collision.
@export var hitbox_size: Vector3 = Vector3.ZERO

## Aircraft behavior
## Altitude at which this aircraft flies (in world units).
# ponytail: schema-first, no consumer yet
@export var flight_level: float = 0.0
## Whether this aircraft can land on helipads or ground.
# ponytail: schema-first, no consumer yet
@export var landable: bool = false
## Whether this aircraft can carry other units (e.g., carryall).
# ponytail: schema-first, no consumer yet
@export var carryall: bool = false

## Dock — building-side configuration for the dock system.
## Local offset from the building's top-left cell to the dock cell.
@export var dock_position: Vector3 = Vector3.ZERO
## Rotation in degrees the docker entity snaps to when docking (e.g. -90 for west-facing).
@export var dock_rotation: float = 0.0
## Whether this building has a dock for unloading cargo.
@export var dock_unload: bool = false
## Resource categories this dock accepts (e.g. ["tiberium"]). Empty = accepts all.
@export var accepted_resource_categories: PackedStringArray = []

## Power
## Power output in watts (positive = generating, negative = consuming).
@export var power: int = 0
## Whether this building requires power to function (shutdown when low power).
@export var powered: bool = false

## Radar
## Whether this building provides radar/minimap functionality.
@export var radar: bool = false
## Whether this building has a sensor array (detects cloaked units).
# ponytail: schema-first, no consumer yet
@export var sensors: bool = false
## Whether this building generates a cloak field for nearby friendly units.
# ponytail: schema-first, no consumer yet
@export var cloak_generator: bool = false
## Radius in cells of the cloak generator field.
# ponytail: schema-first, no consumer yet
@export var cloak_radius_cells: int = 0
## Whether units can reload ammunition at this building.
# ponytail: schema-first, no consumer yet
@export var unit_reload: bool = false
## Upgrade IDs available at this building (e.g., ["WEAP_UPGRADE"]).
# ponytail: schema-first, no consumer yet
@export var upgrades: PackedStringArray = []
## Whether this building is a construction yard (can deploy from MCV).
# ponytail: schema-first, no consumer yet
@export var construction_yard: bool = false
## Whether this building is a weapons factory (produces vehicles).
# ponytail: schema-first, no consumer yet
@export var weapons_factory: bool = false
## Whether this building is a refinery (processes harvested resources).
# ponytail: schema-first, no consumer yet
@export var refinery: bool = false
## Whether this building is a helipad (lands and reloads aircraft).
# ponytail: schema-first, no consumer yet
@export var helipad: bool = false

## Factory — which production queue this entity belongs to (used for queue routing).
## Set on entities that ARE produced (e.g. buildings → "BuildingType").
@export var buildable_queue: String = ""
## Production type — what this building produces (used to find the producing building).
## Set on production buildings only (e.g. Construction Yard → "BuildingType").
@export var factory: String = ""
## Entity ID of the free unit spawned when this building is placed (e.g., "GDI_HARVESTER").
@export var free_unit: String = ""

## Transport — unit-side cargo and docking configuration.
## Number of infantry passengers this unit can carry.
@export var passengers: int = 0
## Dock type ID this unit docks with (e.g. "GDI_REFINERY").
@export var dock: String = ""
## Whether this unit is a harvester (auto-seeks resources and docks when full).
@export var harvester: bool = false
## Maximum resource bales this unit can carry (raw units, not credit value).
@export var storage: int = 0
## Animation scale key for pip overlays on the sidebar.
@export var pip_scale: String = ""

## Resource entity — configuration for harvestable resource entities.
## Category string (e.g. "tiberium", "spice"). Empty = not a resource entity.
@export var resource_category: String = ""
## ResourceType ID for this crystal (e.g. "tiberium_green", "tiberium_blue").
@export var resource_type_id: String = ""
## Regrowth rate override — negative means use the ResourceType's grow_rate.
@export var resource_regrowth_rate: float = -1.0

## Resource tree spawner — configuration for entities that spawn resource crystals.
## Entity ID of the crystal to spawn (e.g. "TIBERIUM_RIPARIUS").
@export var spawned_entity_id: String = ""
## Spawn radius in cells around this entity.
@export var radius_cells: int = 0
## Maximum number of crystal nodes to spawn within the radius.
@export var node_count: int = 0
## Initial spawn density (0.0–1.0) — fraction of max nodes placed on spawn.
@export var spawn_strength: float = 0.5
## Maximum spawn density (0.0–1.0) — cap for regrowth.
@export var max_spawn_strength: float = 1.0

## Special abilities
## Can cloak (become invisible until attacking).
@export var cloakable: bool = false
## Regenerates health slowly over time.
@export var self_healing: bool = false
## Can destroy buildings with C4 charges.
@export var c4: bool = false
## Can capture enemy buildings (engineer class).
@export var engineer: bool = false
## Can disguise as enemy units.
@export var disguise: bool = false
## Can infiltrate enemy buildings for intel.
@export var agent: bool = false
## Can steal credits from enemy buildings.
@export var thief: bool = false
## Immune to resource entity damage (tiberium, veins).
@export var immune_to_resource_damage: bool = false
## Immune to tiberium vein damage.
@export var immune_to_veins: bool = false
## Can be captured by engineers (neutral buildings).
@export var capturable: bool = false

## Building adjacent cell requirement (number of cells the building must be placed next to).
@export var adjacent: int = 0
## Whether the building is crewed (affects survival on destruction).
@export var crewed: bool = false
## Whether the building explodes on death (affects debris and damage).
@export var explodes: bool = false
## Whether this building can be toggled on/off to save power.
# ponytail: schema-first, no consumer yet
@export var toggle_power: bool = false

## Build menu
## Whether this entity appears in the build sidebar.
@export var buildable: bool = false
## Production time in game seconds (scales with Engine.time_scale).
## If 0, calculated from cost: cost * 0.048 (TS BuildSpeed=0.8 formula).
@export var build_time: float = 0.0
## Max count per player (0 = unlimited).
@export var build_limit: int = 0

## Prerequisites
## Entity IDs that must exist before this entity can be built (any-of).
@export var prerequisite: PackedStringArray = []
## Entity IDs that must ALL exist before this entity can be built (all-of).
@export var prerequisite_necessary: PackedStringArray = []

## Deploy — vehicle↔building transformation configuration.
## Entity id to create when this entity deploys (e.g., "GDI_CONSTRUCTION_YARD" for MCV).
@export var deploys_into: String = ""
## Entity id to create when this entity undeploys (e.g., "GDI_MCV" for ConYard).
@export var undeploys_into: String = ""
## Rotation in degrees the source entity rotates to before deploying (0 = default/north).
@export var deploy_rotation: float = 0.0
## Rotation in degrees the source entity rotates to before undeploying (0 = default/north).
@export var undeploy_rotation: float = 0.0

## Art reference
@export var art_data: ArtData = null

## TS BuildSpeed factor — must match GlobalRules.build_speed.
const BUILD_SPEED: float = 0.8


## Returns effective build time in seconds. Uses explicit build_time if set,
## otherwise calculates from cost using TS formula.
func get_build_time() -> float:
    if build_time > 0.0:
        return build_time
    # TS formula: (cost / 1000) * BuildSpeed * 60
    return cost * BUILD_SPEED * 60.0 / 1000.0


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("EntityData: id is empty")
    if (
        strength <= 0
        and entity_type != EntityType.TERRAIN
        and entity_type != EntityType.OVERLAY
        and entity_type != EntityType.SMUDGE
    ):
        errors.append("%s: strength must be > 0" % id)
    if cost < 0:
        errors.append("%s: cost must be >= 0" % id)
    if owner.is_empty():
        errors.append("%s: owner is empty" % id)
    for weapon in weapons:
        if weapon and weapon.id.is_empty():
            errors.append("%s: weapon has empty id" % id)
    if buildable and strength <= 0:
        errors.append("%s: buildable building must have strength > 0" % id)
    return errors


func has_special_abilities() -> bool:
    return (
        cloakable
        or self_healing
        or c4
        or engineer
        or disguise
        or agent
        or thief
        or immune_to_resource_damage
        or immune_to_veins
        or capturable
    )
