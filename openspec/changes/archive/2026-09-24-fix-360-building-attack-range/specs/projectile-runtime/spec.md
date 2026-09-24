## MODIFIED Requirements

### Requirement: Detonation triggers
A visible, armed projectile SHALL detonate when any of the following occurs first: contact with a valid hitbox along its motion; close proximity to its target while armed; overshoot, meaning the distance to the target stops decreasing between frames; or exhaustion of its maximum range. Max range SHALL be derived from the firing weapon's `attack_range`. When the target is a structure (has a `FoundationComponent` and its `StatsComponent.is_structure()` is true), max range SHALL additionally include the target foundation's half-diagonal in world units, because the projectile flies to the footprint centre while the attacker stops at weapon range from the nearest footprint edge; without this the shot fizzles before reaching the wall. Non-structure targets SHALL keep max range equal to the weapon range. When the projectile exhausts range or flies past the map's playable bounds without hitting, it SHALL free itself without dealing damage.

#### Scenario: Contact detonation
- **WHEN** an armed projectile's motion segment intersects an enemy hitbox
- **THEN** it detonates at the intersection

#### Scenario: Overshoot detonation
- **WHEN** a guided projectile's target dodges and the projectile's distance to the target stops decreasing
- **THEN** the projectile detonates instead of circling or flying forever

#### Scenario: Max range fizzle
- **WHEN** a projectile has flown farther than its weapon's attack range without contact
- **THEN** it frees itself without dealing damage and without emitting `impacted`

#### Scenario: Physical shot reaches a large structure fired from nearest-edge range
- **WHEN** a visible non-invisible projectile is fired at a 4x4 structure whose centre is `range + half_extent` away (the attacker stopped at weapon range from the nearest edge)
- **THEN** the projectile's max range covers the footprint centre and it detonates through the hitbox pipeline, dealing damage

#### Scenario: Non-structure max range unchanged
- **WHEN** a projectile is fired at a non-structure target beyond weapon range
- **THEN** max range remains the weapon range and the projectile fizzles without damage
