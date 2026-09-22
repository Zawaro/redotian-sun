## ADDED Requirements

### Requirement: Sidebar tabs are per-game data
The sidebar tab set SHALL be built from per-game configuration declared by the active `GameDefinition` (tab label, accepted entity type groups, and an optional required feature). The sidebar SHALL NOT hardcode the Tiberian Sun four-tab list or its entity-type mapping. Tabs whose required feature is off SHALL be hidden.

#### Scenario: Declared tabs
- **WHEN** the active game declares sidebar tabs (name + entity types)
- **THEN** the sidebar builds exactly those tabs in order

#### Scenario: No declared tabs
- **WHEN** the active game declares no sidebar tabs
- **THEN** the built-in default tab set is used

#### Scenario: Feature-gated tab hidden
- **WHEN** a declared tab requires a feature the game does not enable
- **THEN** that tab is not shown and its hotkey does nothing

#### Scenario: Empty tabs allowed
- **WHEN** a declared tab maps to no entity type groups (e.g. the special/superweapon tab before that mechanic exists)
- **THEN** the tab builds empty without error
