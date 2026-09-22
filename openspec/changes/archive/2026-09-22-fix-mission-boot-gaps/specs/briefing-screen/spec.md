## ADDED Requirements

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
