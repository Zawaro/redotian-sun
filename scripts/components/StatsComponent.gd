# ponytail: thin data wrapper, grows when entity inspection UI or stat modifiers are needed
class_name StatsComponent extends Node

@export var id: String = ""
@export var display_name: String = ""
@export var entity_type: int = 0
@export var armor: String = "none"
@export var cost: int = 0
@export var tech_level: int = -1
@export var sight: int = 1
@export var owner_faction: PackedStringArray = []
@export var points: int = 0
## Player who owns this entity instance (-1 = unset).
@export var player_id: int = -1


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


func validate(data: EntityData) -> PackedStringArray:
    var errors: PackedStringArray = []
    if data.id.is_empty():
        errors.append("StatsComponent: id is empty")
    return errors
