## ADDED Requirements

### Requirement: Ground locomotors declare a bridge terrain speed
Every ground locomotor (Foot, Track, Wheel, Amphibious) SHALL declare a `"bridge"` entry in `terrain_speeds` at least equal to its Road multiplier, so it crosses a bridge deck over water at road-like speed. Hover and Fly SHALL pass decks via their existing pass-all behavior. Ship SHALL declare no `"bridge"` entry (impassable), so it does not traverse deck surfaces. The deck surface SHALL be consumed through the same `terrain_speeds` path used by other land types.

#### Scenario: Wheeled crosses at road speed
- **WHEN** a wheeled unit enters a bridge deck cell
- **THEN** its terrain speed multiplier for `bridge` equals its road multiplier

#### Scenario: Amphibious crosses the deck
- **WHEN** an amphibious unit pathfinds across a bridge span
- **THEN** the deck cells are passable and it crosses them as a ground surface

#### Scenario: Ship cannot use deck cells
- **WHEN** `is_passable("bridge")` is called on the Ship locomotor
- **THEN** it returns `false`

#### Scenario: Validation clean with bridge keys
- **WHEN** `validate_locomotor_keys()` runs after ground locomotors declare `bridge`
- **THEN** it returns no errors

### Requirement: Large height steps cost from the road row
A locomotor SHALL cost a transition of two or more height levels (including a four-level bridge step) from its Road row rather than the destination land type, so a unit keeps road-like speed climbing onto a deck over water. On a deck the terrain figure SHALL be skipped entirely. Rail bridges SHALL be treated as high decks, and any rail-specific movement restriction SHALL be applied by the movement system from the rail bridge kind.

#### Scenario: Large step uses road multiplier
- **WHEN** a unit transitions a step of two or more levels onto a deck
- **THEN** the cost uses the unit locomotor's road multiplier

#### Scenario: Deck skips the terrain figure
- **WHEN** a unit whose destination ground land type has zero speed crosses onto a deck
- **THEN** the deck transition is allowed at road cost

#### Scenario: Rail high deck
- **WHEN** a rail bridge is crossed
- **THEN** it is treated as a high deck for cost and passability
