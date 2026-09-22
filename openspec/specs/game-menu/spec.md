# game-menu Specification

## Purpose
TBD - created by archiving change audit-core-ts-hardcodes. Update Purpose after archive.
## Requirements
### Requirement: Per-game UI theming from data
Shared UI scenes SHALL NOT hardcode a Tiberian Sun asset path or palette. The main menu background and item accent colour SHALL be sourced from the active `GameDefinition` (`menu_background`, `menu_accent_color`), with the scene default left in place when the game declares none.

#### Scenario: Declared theme
- **WHEN** the active game declares `menu_background` and `menu_accent_color`
- **THEN** the main menu uses that background and menu items render in that accent colour

#### Scenario: Missing theme
- **WHEN** the active game declares no menu background or accent
- **THEN** the menu keeps its scene default and no error is raised

#### Scenario: No TS asset in shared scenes
- **WHEN** `scenes/ui/MainMenu01.tscn` is inspected
- **THEN** it does not reference a `res://games/ts/...` asset

### Requirement: Dead menu scene removed
The unused `scenes/ui/MainMenu01_old.tscn` SHALL be deleted; it is superseded by `MainMenu01.tscn` and referenced nowhere.

#### Scenario: No stale scene
- **WHEN** the UI scenes are listed
- **THEN** `MainMenu01_old.tscn` does not exist

