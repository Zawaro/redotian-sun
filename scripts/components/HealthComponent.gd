class_name HealthComponent extends Node3D

signal health_changed(new_health: int, old_health: int)
signal damage_taken(damage_amount: int, damage_type: String)
signal healed(heal_amount: int)
signal health_zero

@export_range(0, 65535) var max_health: int = 100
@export_range(0, 65535) var current_health: int = 100:
    set(value):
        var old_health = current_health
        current_health = clampi(value, 0, max_health)
        if old_health != current_health:
            health_changed.emit(current_health, old_health)


func configure(data: EntityData) -> void:
    if data.strength > 0:
        max_health = data.strength
        current_health = data.spawn_health if data.spawn_health > 0 else data.strength


func take_damage(damage: int, damage_type: String = "") -> void:
    if damage <= 0:
        return
    current_health -= damage
    damage_taken.emit(damage, damage_type)
    if current_health <= 0:
        health_zero.emit()


func heal(amount: int) -> void:
    if amount <= 0:
        return
    var old_value = current_health
    current_health = clampi(current_health + amount, 0, max_health)
    if current_health > old_value:
        healed.emit(current_health - old_value)


func is_full_health() -> bool:
    return current_health >= max_health


func get_health_ratio() -> float:
    return float(current_health) / float(max_health) if max_health > 0 else 0.0


func reset_health() -> void:
    var old_value = current_health
    current_health = max_health
    if old_value != current_health:
        healed.emit(current_health - old_value)
