## ADDED Requirements

### Requirement: Credit display resyncs when the player roster is rebuilt
`PlayerManager` SHALL emit `players_changed` after it (re)builds its player roster. The credit counter SHALL resync — via the forced, non-animated display path — to the local player's balance whenever `players_changed` fires, so a mission's starting credits replace any pre-mission balance shown while the map was loading.

#### Scenario: Roster rebuild resyncs the HUD
- **WHEN** `PlayerManager.begin_mission` rebuilds the roster with a new local-player balance
- **THEN** `players_changed` emits and the credit label immediately shows the new balance, with no animation

#### Scenario: Mission credits replace the stale default
- **WHEN** the map enters the tree showing the autoload default balance and the mission then sets the local player's credits
- **THEN** the label ends at the mission's balance, not the pre-mission default

#### Scenario: Resync is silent
- **WHEN** the counter resyncs from `players_changed`
- **THEN** no tick sound plays
