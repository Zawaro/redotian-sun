## ADDED Requirements

### Requirement: Runtime error handling uses push_error not assert
All runtime precondition checks SHALL use `push_error()` + `return` instead of `assert()`. Assert statements are stripped in release builds, leaving no guard at all.

#### Scenario: Null selection_manager in release build
- **WHEN** `MouseHandler._handle_single_click()` is called with `selection_manager == null` in a release export build
- **THEN** the function logs an error via `push_error()` and returns early without crashing

#### Scenario: Null selection_manager in debug build
- **WHEN** `MouseHandler._handle_single_click()` is called with `selection_manager == null` in a debug build
- **THEN** the function logs an error via `push_error()` and returns early (same behavior as release)

### Requirement: Typed signal emit syntax
All signal emissions SHALL use the typed `signal_name.emit(args)` syntax instead of `emit_signal("name", args)`.

#### Scenario: HealthComponent emits health_changed
- **WHEN** `HealthComponent.take_damage()` reduces health
- **THEN** `health_changed.emit(new_health, old_health)` is called (not `emit_signal("health_changed", ...)`)

#### Scenario: HealthComponent emits damage_taken
- **WHEN** `HealthComponent.take_damage()` is called with valid damage
- **THEN** `damage_taken.emit(damage)` is called

#### Scenario: HealthComponent emits health_zero
- **WHEN** `HealthComponent.take_damage()` reduces health to 0
- **THEN** `health_zero.emit()` is called

#### Scenario: HealthComponent emits healed
- **WHEN** `HealthComponent.heal()` increases health
- **THEN** `healed.emit(amount)` is called

### Requirement: Variables use snake_case naming
All variable names SHALL use snake_case convention per Redot style guide. PascalCase is reserved for classes and node types.

#### Scenario: MainMenuItem01 text label reference
- **WHEN** `MainMenuItem01.gd` references its text label node
- **THEN** the variable is named `text_label` (not `Text`)
