## ADDED Requirements

### Requirement: Briefing button in the pause menu
The pause menu SHALL provide a "Briefing" button that opens the mission briefing dialog for the
active mission. Activating it SHALL NOT resume the game — the game SHALL stay paused while the
briefing is shown. When no mission is active the button SHALL be disabled.

#### Scenario: Briefing opens without resuming
- **WHEN** the player clicks Briefing while the game is paused during a mission
- **THEN** the briefing dialog is shown and `get_tree().paused` remains `true`

#### Scenario: Briefing disabled without a mission
- **WHEN** the pause menu is open and no mission is active
- **THEN** the Briefing button is disabled
