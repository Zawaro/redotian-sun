## MODIFIED Requirements

### Requirement: Hitscan damage application
When firing, CombatComponent SHALL compute the damage dealt to the target as the weapon's base damage multiplied by the weapon's warhead armor multiplier for the target's armor type, clamped to GlobalRules `[min_damage, max_damage]`, then call `target.get_node("HealthComponent").take_damage(final_damage, weapon.warhead)` directly (hitscan). No projectile node is spawned.

#### Scenario: Damage applied with armor
- **WHEN** a weapon with `damage = 100` and warhead "SA" fires at a target with `armor = "heavy"` (SA multiplier 0.25)
- **THEN** the target's HealthComponent SHALL receive `take_damage(25, "SA")`

#### Scenario: Armor-piercing vs heavy
- **WHEN** a weapon with `damage = 100` and warhead "AP" fires at a target with `armor = "heavy"` (AP multiplier 1.00)
- **THEN** the target's HealthComponent SHALL receive `take_damage(100, "AP")`

#### Scenario: Minimum damage floor
- **WHEN** the computed damage would be below `min_damage` (1)
- **THEN** the applied damage SHALL be clamped to 1

#### Scenario: Maximum damage cap
- **WHEN** the computed damage would exceed `max_damage` (1000)
- **THEN** the applied damage SHALL be clamped to 1000

#### Scenario: Zero-damage armor pairing
- **WHEN** a warhead's multiplier for the target's armor is 0.0
- **THEN** the target's HealthComponent SHALL receive `take_damage(0, warhead)` and take no damage

#### Scenario: Unknown warhead
- **WHEN** the weapon's warhead id is not in the GlobalRules warhead registry
- **THEN** damage SHALL be applied unmodified (full multiplier 1.0)

#### Scenario: Unknown target armor
- **WHEN** the target's armor id is not in the GlobalRules armor type registry
- **THEN** damage SHALL be applied with full multiplier 1.0

#### Scenario: Target has no HealthComponent
- **WHEN** the target entity has no HealthComponent child
- **THEN** CombatComponent SHALL skip the damage call without error
