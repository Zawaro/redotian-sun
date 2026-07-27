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

var _rules: GlobalRules
var _stats: StatsComponent
var _resolved: bool = false


func _resolve_refs() -> void:
    _resolved = true
    if EntityFactory and EntityFactory.has_method("get_global_rules"):
        _rules = EntityFactory.get_global_rules()
    var parent := get_parent()
    if parent:
        _stats = parent.get_node_or_null("StatsComponent") as StatsComponent


func configure(data: EntityData) -> void:
    if data.strength > 0:
        max_health = data.strength
        current_health = data.spawn_health if data.spawn_health > 0 else data.strength


func take_damage(damage: int, damage_type: String = "") -> void:
    if damage <= 0:
        return
    if not _resolved:
        _resolve_refs()
    var final_damage := damage
    if _rules:
        var armor := _stats.armor if _stats else "none"
        var veteran := _stats.veteran_level if _stats else 0
        final_damage = _rules.compute_final_damage(damage, armor, veteran)
    current_health -= final_damage
    damage_taken.emit(final_damage, damage_type)
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


func kill() -> void:
    current_health = 0
    health_zero.emit()
