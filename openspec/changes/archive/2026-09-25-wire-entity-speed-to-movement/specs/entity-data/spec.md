## ADDED Requirements

### Requirement: EntityData speed is TS leptons per frame and drives movement

`EntityData.speed: float` SHALL be interpreted as the original Tiberian Sun `Speed` value in leptons per game frame (`0.0` = immobile). `MovementController` SHALL set its base `move_speed` from this value through the `GlobalRules` lepton-to-world-units conversion, so two units with different `speed` traverse the same path at different real rates. The field SHALL NOT be documented as "cells per tick".

#### Scenario: Different speeds move at different rates

- **WHEN** two units with `speed = 6.0` and `speed = 10.0` move over flat clear terrain with a non-ramping locomotor on the unit's default cell land type
- **THEN** their world units per second are in the ratio 6:10 and each equals `GlobalRules.speed_to_units_per_second(speed)`

#### Scenario: Immobile entity has no controller

- **WHEN** an EntityData has `speed = 0.0`
- **THEN** no MovementController is attached and the entity never moves

#### Scenario: Speed documentation

- **WHEN** a developer reads the `EntityData.speed` declaration
- **THEN** the comment describes it as leptons per frame (TS `Speed`), not cells per tick

## MODIFIED Requirements

### Requirement: EntityData weight drives ice damage, not speed

`EntityData.weight: float` SHALL represent mass used to damage ice entities when a unit enters their cell. Weight SHALL NOT scale movement speed — speed is set by `EntityData.speed` and terrain/locomotor factors.

#### Scenario: Heavy unit damages ice

- **WHEN** a unit with `weight = 3.0` enters a cell occupied by an ice entity
- **THEN** the ice entity receives weight-proportional damage

#### Scenario: Weight does not affect speed

- **WHEN** two units with the same `speed = 6.0` but different `weight` move over flat clear terrain
- **THEN** both move at the same rate, `GlobalRules.speed_to_units_per_second(6.0)`, independent of weight
