## ADDED Requirements

### Requirement: Action-mode state API
`OrderSystem` SHALL expose action-mode state derived from the active generator's type: `is_sell_mode()` returns true iff `active_generator` is a `SellOrderGenerator`, `is_repair_mode()` returns true iff it is a `RepairOrderGenerator`, and `is_action_mode()` returns true iff `active_generator` is neither the `UnitOrderGenerator` singleton nor a unit-order generator. No parallel mode booleans SHALL be kept in UI scripts; gameplay guards (MouseHandler order routing, PauseMenu ESC handling) SHALL query OrderSystem, not the Sidebar.

#### Scenario: Sell mode armed
- **WHEN** the sell button arms `SellOrderGenerator` via `set_generator()`
- **THEN** `is_sell_mode()` and `is_action_mode()` return true and `is_repair_mode()` returns false

#### Scenario: Repair mode armed
- **WHEN** the repair button arms `RepairOrderGenerator` via `set_generator()`
- **THEN** `is_repair_mode()` and `is_action_mode()` return true and `is_sell_mode()` returns false

#### Scenario: Cancel resets to unit orders
- **WHEN** `cancel()` is called while an action mode is active
- **THEN** the active generator cancels, `active_generator` resets to the `UnitOrderGenerator` singleton, and all three queries return false

#### Scenario: Guards do not read the Sidebar
- **WHEN** MouseHandler or the PauseMenu ESC guard need sell/repair mode state
- **THEN** they call `OrderSystem.is_sell_mode()`/`is_repair_mode()`/`is_action_mode()`; no gameplay script calls `Sidebar.is_sell_mode()`, `Sidebar.is_repair_mode()`, or `Sidebar.exit_action_mode()`

### Requirement: Generator change notification
`OrderSystem` SHALL emit a `generator_changed` signal after `set_generator()` installs a generator and after `cancel()` resets to the `UnitOrderGenerator` singleton, so UI (e.g. the Sidebar sell/repair buttons) can sync its visual state from the signal instead of being told imperatively.

#### Scenario: Set generator notifies
- **WHEN** `set_generator(SellOrderGenerator.new())` is called
- **THEN** `generator_changed` emits after the generator is installed

#### Scenario: Cancel notifies
- **WHEN** `cancel()` is called while a sell order mode is active
- **THEN** `generator_changed` emits after the reset, and the sell button unpresses itself from the signal — no imperative un-press call from gameplay code is required
