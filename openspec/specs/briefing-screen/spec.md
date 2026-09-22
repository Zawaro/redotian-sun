# briefing-screen Specification

## Purpose
Defines the mission briefing dialog: displaying the active mission's briefing, the pre-mission pause gate, and re-opening from the pause menu.
## Requirements
### Requirement: Briefing dialog content
The system SHALL provide a `BriefingDialog` that displays the active mission's `display_name` and
`briefing` text. Showing it for a mission SHALL replace any previously displayed briefing content.

#### Scenario: Briefing shows mission text
- **WHEN** the briefing dialog is shown for a mission whose `briefing` is `"Reinforce Phoenix Base."`
- **THEN** the dialog displays the mission's display name and that briefing text

### Requirement: Pre-mission briefing gate
Starting a mission SHALL show the briefing dialog before gameplay begins when the mission's
`show_briefing` is `true`, and SHALL NOT show it when `show_briefing` is `false`.

#### Scenario: Briefing shown when enabled
- **WHEN** a mission with `show_briefing = true` starts
- **THEN** the briefing dialog is visible

#### Scenario: Briefing skipped when disabled
- **WHEN** a mission with `show_briefing = false` starts
- **THEN** the briefing dialog is not shown

### Requirement: Pre-mission briefing holds the game paused
While the pre-mission briefing is visible the game SHALL remain paused. Closing it SHALL unpause
the game and hide the dialog.

#### Scenario: Game paused during pre-mission briefing
- **WHEN** the pre-mission briefing is visible
- **THEN** `get_tree().paused` is `true`

#### Scenario: Closing resumes gameplay
- **WHEN** the player clicks Close on the pre-mission briefing
- **THEN** the dialog hides and `get_tree().paused` is `false`

### Requirement: Briefing from the pause menu
The pause menu SHALL provide a "Briefing" button that opens the briefing dialog for the active
mission. Opening it from the pause menu SHALL leave the game paused, and closing it SHALL return to
the pause menu with the game still paused.

#### Scenario: Pause menu opens the briefing
- **WHEN** a mission is active and the player clicks Briefing in the pause menu
- **THEN** the briefing dialog is visible and `get_tree().paused` remains `true`

#### Scenario: Closing pause-menu briefing stays paused
- **WHEN** the player clicks Close on a briefing opened from the pause menu
- **THEN** the briefing dialog hides, the pause menu is visible, and `get_tree().paused` is `true`

### Requirement: Briefing unavailable without a mission
When no mission is active, the briefing SHALL not be shown; the pause menu's Briefing button SHALL
be disabled.

#### Scenario: No active mission disables Briefing
- **WHEN** the pause menu is open and `GameContext.current_mission` is `null`
- **THEN** the Briefing button is disabled

### Requirement: Escape closes the briefing
While the briefing is visible, pressing the pause action SHALL close it and SHALL NOT toggle the
pause state. Closing a pre-mission briefing SHALL unpause the game; closing a briefing opened from
the pause menu SHALL leave the game paused.

#### Scenario: Escape closes a pre-mission briefing and unpauses
- **WHEN** the pre-mission briefing is visible and the pause action is pressed
- **THEN** the briefing hides, the game is unpaused, and the pause state was not toggled

#### Scenario: Escape closes a pause-menu briefing and stays paused
- **WHEN** a briefing opened from the pause menu is visible and the pause action is pressed
- **THEN** the briefing hides and the game remains paused

