## ADDED Requirements

### Requirement: Per-player per-category resource storage
The system SHALL track each player's **stored** resource value per resource category (e.g. `"tiberium"`, `"weed"`) on their `PlayerData` as the single source of truth for storage. Harvest dumps and production-cancel refunds SHALL increase the category's stored value; spending SHALL decrease it (stored first). Free credits (starting credits, crate bonuses, debug money, sell refunds) SHALL be tracked separately and never count toward storage.

#### Scenario: Harvest dump stores into the tiberium category
- **WHEN** a harvester unloads at a refinery and `EconomyManager.add(player_id, 500, "harvest")` is called
- **THEN** the player's stored value for the `"tiberium"` category increases by 500

#### Scenario: Free credits do not store
- **WHEN** `EconomyManager.add(player_id, 1000, "crate", "tiberium", true)` is called
- **THEN** the player's stored tiberium value is unchanged and `get_balance(player_id, "tiberium")` returns 0

#### Scenario: Deduct draws from a specific category
- **WHEN** `EconomyManager.deduct(player_id, 300, "build", "tiberium")` is called with sufficient balance
- **THEN** the player's stored value for the `"tiberium"` category decreases by 300 (stored drained before free)

### Requirement: Displayable balance excludes hidden groups
The system SHALL expose a displayable balance — free credits plus the sum of stored values across categories flagged `display_in_hud = true` — as the value used for the HUD credit counter and build affordability. Categories flagged `display_in_hud = false` (e.g. the `"weed"` vein category) SHALL never appear in the HUD credits or build-menu prices.

#### Scenario: Hidden vein group excluded from balance
- **WHEN** a player has 500 stored in `"tiberium"` (displayable) and 100 stored in `"weed"` (not displayable) and no free credits
- **THEN** `EconomyManager.get_balance(player_id)` returns 500 and the build menu treats the player as having 500 credits

#### Scenario: Category balance still reachable directly
- **WHEN** a caller queries `EconomyManager.get_balance(player_id, "weed")`
- **THEN** it returns the hidden category's stored value (100) even though it is excluded from the displayable total

### Requirement: Per-category storage capacity
The system SHALL provide a storage capacity per resource category via `EconomyManager.get_storage_capacity(player_id, category)`. The `"tiberium"` category SHALL have capacity 2000 for now; unknown categories SHALL return 0. Capacity constrains stored value, not free credits.

#### Scenario: Tiberium capacity default
- **WHEN** `EconomyManager.get_storage_capacity(player_id, "tiberium")` is called
- **THEN** it returns 2000

#### Scenario: Unknown category capacity
- **WHEN** `EconomyManager.get_storage_capacity(player_id, "weed")` is called
- **THEN** it returns 0

### Requirement: Refinery storage pips visualization
The system SHALL draw a storage bar on selected or hovered refinery buildings. The bar SHALL be a full-width segmented bar running along the building's bottom/south edge (max Z), spanning its x-width, one cube tall with a segmented grid like the building health bar, filled in the tiberium resource color to the ratio of the building owner's **stored** tiberium value over the tiberium capacity. Free credits (starting credits, crates, sell refunds) SHALL NOT count toward the bar. The bar SHALL update as the stored balance changes.

#### Scenario: Refinery shows storage bar on selection
- **WHEN** a building with `EntityData.refinery = true` is selected and its owner has 500 of 2000 tiberium stored
- **THEN** a full-width bar appears along the building's bottom/south edge, drawn to 25% fill in the tiberium color

#### Scenario: Storage bar reflects stored balance change
- **WHEN** the same selected refinery's owner harvests 500 more tiberium (stored now 1000)
- **THEN** the bar fill increases to 50%

#### Scenario: Free credits do not fill the storage bar
- **WHEN** the selected refinery's owner has 1000 free credits and 0 stored tiberium
- **THEN** the bar fill is 0% (free credits do not count toward storage)

#### Scenario: Non-refinery buildings show no storage bar
- **WHEN** a selected building does not have `EntityData.refinery = true`
- **THEN** no storage bar is drawn for it

#### Scenario: No bar when capacity is unavailable
- **WHEN** a selected refinery has an owner with `player_id < 0` (map editor) or the tiberium capacity is 0
- **THEN** no storage bar is drawn and no division-by-zero occurs

### Requirement: Refinery data declares storage capability
The GDI and Nod refinery `EntityData` resources SHALL set `refinery = true` and declare `storage_capacity` for the tiberium category (2000).

#### Scenario: GDI refinery declares capability
- **WHEN** the `gdi_refinery.tres` entity data is loaded
- **THEN** `refinery` is `true` and `storage_capacity["tiberium"]` is 2000

#### Scenario: Nod refinery declares capability
- **WHEN** the `nod_refinery.tres` entity data is loaded
- **THEN** `refinery` is `true` and `storage_capacity["tiberium"]` is 2000
