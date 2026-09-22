## ADDED Requirements

### Requirement: Active mission tracking
GameContext SHALL expose `current_mission: Mission` and `start_mission(id: String)`. Starting a
mission SHALL resolve the mission through `CampaignCatalog`, store it as `current_mission`, and
emit a `mission_started` signal. An unknown mission id SHALL log a `push_error` and leave the
current mission unchanged. Selecting or unloading a game SHALL clear `current_mission`.

#### Scenario: Start a known mission
- **WHEN** `start_mission("gdi01")` is called and that mission is registered
- **THEN** `current_mission.id` is `"gdi01"` and exactly one `mission_started` is emitted

#### Scenario: Unknown mission refused
- **WHEN** `start_mission("nope")` is called
- **THEN** an error names `"nope"`, no `mission_started` is emitted, and `current_mission` is
  unchanged

#### Scenario: Game switch clears the mission
- **WHEN** a different game is selected while a mission is active
- **THEN** `current_mission` becomes `null`
