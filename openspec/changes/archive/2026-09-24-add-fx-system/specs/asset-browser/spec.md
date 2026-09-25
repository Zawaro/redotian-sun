## ADDED Requirements

### Requirement: FX effect preview
The browser SHALL include an `FxData` category. Selecting an effect asset SHALL preview it in the 3D view by playing it once at a fixed point on the preview stage through `FxSystem`, and the browser SHALL provide a replay action that plays the effect again. A SPRITE effect SHALL preview its animated billboard; a PARTICLES effect SHALL preview its emitter. An effect that fails to resolve or validate SHALL show the explicit empty state rather than silently rendering nothing.

#### Scenario: FX category lists effects
- **WHEN** the browser loads and an `FxData` effect exists in the active game content
- **THEN** the effect is listed under the `FxData` category

#### Scenario: Selecting an effect plays it once
- **WHEN** an `FxData` asset is selected
- **THEN** the effect plays once on the preview stage

#### Scenario: Replay action
- **WHEN** the replay action is triggered for the selected effect
- **THEN** the effect plays again from the start

#### Scenario: Empty or invalid effect shows empty state
- **WHEN** the selected `FxData` fails to resolve or fails `validate()`
- **THEN** the browser shows the explicit empty state and logs a warning
