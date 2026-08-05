# selection-manager Specification

## MODIFIED Requirements

### Requirement: Visual selection synchronization
SelectionManager SHALL synchronize its internal selection list with the visual `is_selected` state on SelectComponents. The primary path SHALL be event-driven: `SelectComponent.set_is_selected()` emits a selection-state signal and SelectionManager reconciles that entity immediately. A low-frequency reconcile (at most 10 Hz) SHALL remain as a safety net for external direct writes to `is_selected`. The list SHALL NOT be rescanning the "selectable" group every frame.

#### Scenario: Visual selection out of sync (event-driven)
- **WHEN** a SelectComponent sets `is_selected = true` via `set_is_selected()` and is not in `selected_entities`
- **THEN** it is added to `selected_entities` on the same frame

#### Scenario: List contains visually unselected (event-driven)
- **WHEN** a SelectComponent sets `is_selected = false` via `set_is_selected()` while in `selected_entities`
- **THEN** it is removed from `selected_entities` on the same frame

#### Scenario: External mutation reconciled at low frequency
- **WHEN** a SelectComponent's `is_selected` is written directly (not via `set_is_selected()`)
- **THEN** `selected_entities` is reconciled within 100 ms
