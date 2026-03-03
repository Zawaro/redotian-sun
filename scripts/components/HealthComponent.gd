extends Node3D
class_name HealthComponent

@export_range(0, 65535) var max_health: int = 100
@export_range(0, 65535) var current_health: int = 100:
    set(value):
        current_health = min(value, max_health)

func _take_damage(damage: int) -> void:
    current_health -= damage
    if current_health <= 0:
        _on_health_zero()

func _heal(amount: int) -> void:
    current_health = min(current_health + amount, max_health)

func _on_health_zero():
    # Handle health reaching zero
    print("Health is zero!")
    # You can add logic here to handle the game state when health reaches zero
    
func is_full_health() -> bool:
    return current_health >= max_health
