## ADDED Requirements

### Requirement: New Map dialog
The editor SHALL display a New Map dialog when "New" is selected from the File menu. The dialog SHALL contain fields for map name, width, height, starting height, player count, and a read-only visible bounds display.

#### Scenario: Dialog fields and defaults
- **WHEN** the New Map dialog opens
- **THEN** it shows: Map Name (LineEdit, "Untitled"), Width (SpinBox, 64, min 50, max 512, step 2), Height (SpinBox, 64, min 50, max 512, step 2), Starting Height (SpinBox, 0, min 0, max 15, step 4), Player Count (SpinBox, 2, min 2, max 8), Visible Bounds (read-only Label, "53 × 55"), Confirm button, Cancel button

#### Scenario: Visible bounds auto-update on size change
- **WHEN** the user changes Width to 100
- **THEN** the Visible Bounds label updates to "89 × 55" (100-1-10=89, 64-1-8=55)

#### Scenario: Visible bounds auto-update on height change
- **WHEN** the user changes Height to 100
- **THEN** the Visible Bounds label updates to "53 × 91" (64-1-10=53, 100-1-8=91)

#### Scenario: Confirm creates new map
- **WHEN** the user clicks Confirm with Width=80, Height=60
- **THEN** the dialog closes, `TerrainSystem.init_grid(80, 60)` is called, terrain is cleared and rebuilt, grid is redrawn, and BoundsSystem offsets are set to (10, 8)

#### Scenario: Cancel closes without changes
- **WHEN** the user clicks Cancel
- **THEN** the dialog closes and no map changes occur

### Requirement: Map Settings dialog
The editor SHALL display a Map Settings dialog when "Map Settings" is selected from the Settings menu. The dialog SHALL be pre-populated with current values and allow modifying map parameters.

#### Scenario: Dialog pre-populated with current values
- **WHEN** the Map Settings dialog opens on a 80×60 map
- **THEN** Width shows 80, Height shows 60, Starting Height shows current value, Player Count shows current value, Visible Bounds shows "69 × 51"

#### Scenario: Visible bounds auto-update on size change
- **WHEN** the user changes Width to 100 in the Map Settings dialog
- **THEN** the Visible Bounds label updates to "89 × 51" (100-1-10=89, 60-1-8=51)

#### Scenario: Confirm applies changes
- **WHEN** the user changes Width to 100 and clicks Confirm
- **THEN** the dialog closes, `TerrainSystem.init_grid(100, 60)` is called, terrain is rebuilt, grid is redrawn, and BoundsSystem offsets are updated

#### Scenario: Cancel closes without changes
- **WHEN** the user clicks Cancel
- **THEN** the dialog closes and the map retains its original parameters

### Requirement: Dialogs use confirm/cancel pattern
Both New Map and Map Settings dialogs SHALL use a Confirm/Cancel button pair at the bottom. Confirm applies changes; Cancel discards and closes.

#### Scenario: Confirm button labeled appropriately
- **WHEN** the New Map dialog opens
- **THEN** the confirm button is labeled "Create"

#### Scenario: Confirm button labeled for settings
- **WHEN** the Map Settings dialog opens
- **THEN** the confirm button is labeled "Apply"
