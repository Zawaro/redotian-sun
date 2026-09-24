## MODIFIED Requirements

### Requirement: CombatComponent tracks attack target
CombatComponent SHALL maintain a `_target: Node3D` reference set via `set_target(entity, hold_ground := false)`. The optional `hold_ground` flag SHALL default to `false` so existing player-order and test call sites are unchanged. When `hold_ground` is true, CombatComponent SHALL treat the engagement as stand-and-shoot: it SHALL NOT issue chase/approach moves, and when the target's horizontal distance exceeds the longest weapon range on a `_physics_process` tick it SHALL clear the target and stop attacking. The target SHALL persist across `_physics_process` ticks until explicitly cleared via `clear_target()`, the target becomes invalid, or (hold-ground only) the target leaves weapon range.

#### Scenario: Set target
- **WHEN** `set_target(entity)` is called with a valid enemy entity
- **THEN** `_target` SHALL reference that entity

#### Scenario: Target becomes invalid
- **WHEN** `_target` is no longer a valid instance (freed node)
- **THEN** CombatComponent SHALL clear `_target` and stop attacking

#### Scenario: Target dies (health reaches zero)
- **WHEN** the target's HealthComponent emits `health_zero`
- **THEN** CombatComponent SHALL clear `_target` and stop attacking

#### Scenario: Hold-ground target leaves range
- **WHEN** the active target was set with `hold_ground = true` and its horizontal distance exceeds `max(weapon.attack_range) * CellUtil.CELL_SIZE`
- **THEN** CombatComponent SHALL clear `_target` and SHALL NOT call `_move_toward_target`

#### Scenario: Default hold_ground preserves chase
- **WHEN** `set_target(entity)` is called without the second argument (or with `false`) and the target is out of range
- **THEN** CombatComponent SHALL behave exactly as before this change (stop current move, approach toward the target)
