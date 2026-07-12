class_name EntityData extends Resource

## Entity type enum
enum EntityType { INFANTRY, VEHICLE, BUILDING, AIRCRAFT, TERRAIN, OVERLAY }

## Identity
@export var id: String = ""
@export var display_name: String = ""
@export var entity_type: EntityType = EntityType.TERRAIN

## Core stats
@export var strength: int = 0
@export var armor: String = "none"
@export var cost: int = 0
@export var tech_level: int = -1
@export var sight: int = 1
@export var is_drag_selectable: bool = true
@export var owner: PackedStringArray = []
@export var points: int = 0
@export var explosion: PackedStringArray = []

## Combat
@export var weapons: Array[WeaponData] = []
@export var elite_weapons: Array[WeaponData] = []
@export var turret: bool = false
@export var turret_anim: String = ""
@export var threat_posed: int = 0

## Movement
@export var speed: float = 0.0
@export var movement_zone: String = ""
@export var locomotor: String = ""
@export var rotation_speed: float = 180.0
@export var crusher: bool = false
@export var crushable: bool = false
@export var weight: float = 1.0

## Foundation
@export var foundation: Vector2i = Vector2i(1, 1)
@export var height: float = 1.0
@export var bib_cells: Array[Vector2i] = []
@export var hitbox_size: Vector3 = Vector3.ZERO

## Dock
@export var dock_position: Vector3 = Vector3.ZERO
@export var dock_rotation: float = 0.0
@export var dock_unload: bool = false
@export var refinery_storage: int = 0

## Power
@export var power: int = 0
@export var powered: bool = false

## Radar
@export var radar: bool = false

## Factory
@export var factory: String = ""
@export var free_unit: String = ""

## Transport
@export var passengers: int = 0
@export var dock: String = ""
@export var harvester: bool = false
@export var storage: int = 0
@export var pip_scale: String = ""

## Tiberium tree spawner
@export var tiberium_tree: bool = false
@export var spawned_entity_id: String = ""
@export var radius_cells: int = 0
@export var node_count: int = 0
@export var amount_per_node: int = 0
@export var max_amount_per_node: int = 0

## Tiberium crystal resource
@export var tiberium_resource: bool = false
@export var tiberium_amount: int = 0
@export var tiberium_max_amount: int = 0
@export var tiberium_type: int = 0
@export var tiberium_regrowth_rate: float = -1.0

## Special abilities
@export var cloakable: bool = false
@export var self_healing: bool = false
@export var c4: bool = false
@export var engineer: bool = false
@export var disguise: bool = false
@export var agent: bool = false
@export var thief: bool = false
@export var tiberium_proof: bool = false
@export var immune_to_veins: bool = false
@export var capturable: bool = false

## Build menu
@export var buildable: bool = false

## Prerequisites
@export var prerequisite: PackedStringArray = []
@export var prerequisite_necessary: PackedStringArray = []

## Art reference
@export var art_data: ArtData = null


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("EntityData: id is empty")
    if strength <= 0 and entity_type != EntityType.TERRAIN and entity_type != EntityType.OVERLAY:
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
        or tiberium_proof
        or immune_to_veins
        or capturable
    )
