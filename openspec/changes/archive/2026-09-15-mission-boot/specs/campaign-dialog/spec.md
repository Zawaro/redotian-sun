## ADDED Requirements

### Requirement: Campaign dialog lists campaigns
The main menu's campaign entry SHALL open a `CampaignDialog` listing one row per campaign returned
by `CampaignCatalog.list_campaigns()`, labeled with the campaign's `display_name` (falling back to
`id` when empty). The dialog SHALL provide a Start action and SHALL expose which campaign is
selected. While the dialog is visible it SHALL occlude the main menu so main-menu input cannot
react to clicks aimed at the dialog.

#### Scenario: Campaigns rendered as rows
- **WHEN** the catalog returns campaigns with ids `gdi` and `nod`
- **THEN** the dialog contains a row per campaign labeled with its `display_name`

#### Scenario: Display name fallback
- **WHEN** a campaign has an empty `display_name`
- **THEN** its row is labeled with the campaign's `id`

#### Scenario: Main menu occluded
- **WHEN** the campaign dialog is visible
- **THEN** the main menu node is not visible

### Requirement: Starting a campaign's first mission
Activating Start with a campaign selected SHALL start that campaign's first mission through the
mission boot flow, using the campaign's `missions` order. Start SHALL be refused (with no mission
started) when no campaign is selected or the selected campaign has no missions.

#### Scenario: Start selects the first mission
- **WHEN** the dialog has the `gdi` campaign selected and Start is activated
- **THEN** `GameContext.current_mission.id` is that campaign's first mission id

#### Scenario: Empty campaign refused
- **WHEN** Start is activated for a campaign whose `missions` array is empty
- **THEN** no mission starts and the dialog stays open

#### Scenario: No selection refused
- **WHEN** Start is activated with no campaign selected
- **THEN** no mission starts and the dialog stays open

### Requirement: Dialog handles an empty catalog
The campaign dialog SHALL open even when no campaigns are discovered, showing an empty state and a
disabled Start action, so the player is never left without a way to back out.

#### Scenario: No campaigns discovered
- **WHEN** `list_campaigns()` returns an empty array
- **THEN** the dialog shows no campaign rows and Start is disabled
