class_name HitboxComponent extends Area3D

## Emitted when a damaging entity enters the hitbox.
## Args: damage amount, damage type string, the node that dealt the damage.
signal received_damage(damage: int, damage_type: String, source: Node3D)

## Collision layers — assign via EntityFactory based on entity type.
const LAYER_HITBOX_GROUND: int = 1 << 1
const LAYER_HITBOX_AIR: int = 1 << 2
const LAYER_HITBOX_BUILDING: int = 1 << 3
const LAYER_PROJECTILE: int = 1 << 4

@export var health_component: HealthComponent
@export var size: Vector3 = Vector3(2.0, 2.0, 2.0):
    set(value):
        size = value
        _update_collision_shape()


func _ready() -> void:
    area_entered.connect(_on_area_entered)
    body_entered.connect(_on_body_entered)


func _on_area_entered(area: Area3D) -> void:
    _try_deal_damage(area)


func _on_body_entered(body: Node3D) -> void:
    _try_deal_damage(body)


## Checks if the entering node deals damage and forwards to HealthComponent.
## Projectiles should implement get_damage_info() -> { "amount": int, "type": String }.
func _try_deal_damage(node: Node3D) -> void:
    if not health_component:
        return
    if not node.has_method("get_damage_info"):
        return
    var info: Dictionary = node.get_damage_info()
    var damage: int = info.get("amount", 0)
    var damage_type: String = info.get("type", "")
    if damage > 0:
        health_component.take_damage(damage, damage_type)
        received_damage.emit(damage, damage_type, node)


func _update_collision_shape() -> void:
    $CollisionObject3D.shape.size = size
    $CollisionObject3D.position = Vector3(0, size.y / 2.0, 0)
