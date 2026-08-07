## ADDED Requirements

### Requirement: New Map dialog
The editor SHALL display a New Map dialog when "New" is selected from the File menu. The dialog SHALL contain fields for map name, width, height, starting height, player count, four visible-bounds insets, and a read-only visible bounds display.

#### Scenario: Dialog fields and defaults
- **WHEN** the New Map dialog opens
- **THEN** it shows: Map Name (LineEdit, "Untitled"), Width (SpinBox, 50, min 20, max 512, step 1), Height (SpinBox, 50, min 20, max 512, step 1), Starting Height (SpinBox, 0, min 0, max 12, step 4), Player Count (SpinBox, 2, min 2, max 8), Left Inset (SpinBox, 5), Right Inset (SpinBox, 5), Top Inset (SpinBox, 4), Bottom Inset (SpinBox, 4), Visible Bounds (read-only Label), Create button, Cancel button

#### Scenario: Visible bounds label reflects insets
- **WHEN** the New Map dialog opens with defaults Width=50, Height=50, insets 5/5/4/4
- **THEN** the Visible Bounds label shows "40 × 42" (50−5−5=40, 50−4−4=42)

#### Scenario: Inset max is capped by map size and opposite inset
- **WHEN** the user sets Left Inset to 8 on a 50-wide map (Right Inset 5)
- **THEN** the Right Inset max becomes `2*50 − 8 − 1 = 91`, and the Visible Bounds label updates
- **AND** when an opposite inset is raised so `left + right >= 2*width`, the offending inset is clamped so the visible bounds never becomes empty

#### Scenario: Confirm creates new map
- **WHEN** the user clicks Create with Width=80, Height=60, insets 5/5/4/4
- **THEN** the dialog closes, `TerrainSystem.init_grid(80, 60)` is called, terrain is cleared and rebuilt, grid is redrawn, and `BoundsSystem.left/right_inset == 5`, `top/bottom_inset == 4`

#### Scenario: Cancel closes without changes
- **WHEN** the user clicks Cancel
- **THEN** the dialog closes and no map changes occur

### Requirement: Map Settings dialog
The editor SHALL display a Map Settings dialog when "Map Settings" is selected from the Settings menu. The dialog SHALL be pre-populated with current values and allow modifying map parameters.

#### Scenario: Dialog pre-populated with current values
- **WHEN** the Map Settings dialog opens on a 80×60 map with insets 5/5/4/4
- **THEN** Width shows 80, Height shows 60, Left/Right Inset show 5, Top/Bottom Inset show 4, and Visible Bounds shows "70 × 52"

#### Scenario: Confirm applies changes
- **WHEN** the user changes Width to 100 and clicks Apply
- **THEN** the dialog closes, `TerrainSystem.init_grid(100, 60)` is called, terrain is rebuilt, grid is redrawn, and `BoundsSystem.grid_cells` is updated

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
