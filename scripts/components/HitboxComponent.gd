class_name HitboxComponent extends Area3D

@export var health_component: HealthComponent
@export var size: Vector3 = Vector3(2.0, 2.0, 2.0):
    set(value):
        size = value
        _update_collision_shape()


func _update_collision_shape():
    $CollisionObject3D.shape.size = size
    $CollisionObject3D.position = Vector3(0, size.y / 2.0, 0)
