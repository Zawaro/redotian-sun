## MODIFIED Requirements

### Requirement: Warhead impact FX

On each damaging hit, `EntityFactory` SHALL resolve the hit's warhead from the `HealthComponent.damage_taken` `damage_type` through `GlobalRules` and play `warhead.impact_fx` through `FxSystem.play` at the victim's `global_position`. A `null` `impact_fx`, an empty `damage_type`, or an unresolvable warhead SHALL play nothing. Because the trigger is the shared damage signal, this SHALL cover both the projectile and the fallback hitscan damage paths without a separate projectile hook. The per-victim report SHALL apply only to combat entities; cell overlays (bridge span, ice, tiberium) SHALL be excluded from this trigger, because their damage is applied by the warhead-gated cell pass, which plays the shot's single report once at the impact point. One resolved shot SHALL therefore play the impact effect at most once, never once per damaged cell victim. Fog gating is delegated to `FxSystem` (see the `fx-system` capability).

#### Scenario: Damaging hit plays impact FX

- **WHEN** an entity takes damage whose warhead has a non-null `impact_fx`
- **THEN** the effect is played at the victim's position

#### Scenario: Projectile hit path

- **WHEN** a projectile detonates on a victim through the hitbox pipeline and the warhead has an `impact_fx`
- **THEN** the impact effect is played at the victim

#### Scenario: Hitscan hit path

- **WHEN** a weapon applies fallback hitscan damage and the warhead has an `impact_fx`
- **THEN** the impact effect is played at the victim

#### Scenario: Mixed entity and overlay hit plays one impact effect

- **WHEN** a shot damages both a combat entity and a cell overlay at the same impact point and the warhead has an `impact_fx`
- **THEN** exactly one impact effect plays at that point, not one per victim

#### Scenario: No impact FX is silent

- **WHEN** the resolved warhead's `impact_fx` is `null`
- **THEN** no effect node is spawned

#### Scenario: Non-warhead damage is silent

- **WHEN** an entity takes damage with an empty `damage_type` (crush, drowning)
- **THEN** no impact effect is played

#### Scenario: Unknown warhead is silent

- **WHEN** `damage_type` does not resolve to a warhead in the GlobalRules registry
- **THEN** no impact effect is played and no error is raised
