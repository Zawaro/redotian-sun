## ADDED Requirements

### Requirement: File dropdown menu
The map editor toolbar SHALL display a "File" MenuButton at the top-left that opens a PopupMenu with New, Load, and Save items.

#### Scenario: File menu opens
- **WHEN** the player clicks the "File" button
- **THEN** a PopupMenu appears with items: "New", "Load", "Save"

#### Scenario: File menu New item
- **WHEN** the player clicks "New" in the File menu
- **THEN** the New Map dialog opens

#### Scenario: File menu Load item
- **WHEN** the player clicks "Load" in the File menu
- **THEN** the existing load FileDialog opens (from EditorSaveLoad)

#### Scenario: File menu Save item
- **WHEN** the player clicks "Save" in the File menu
- **THEN** the existing save FileDialog opens (from EditorSaveLoad)

### Requirement: Settings dropdown menu
The map editor toolbar SHALL display a "Settings" MenuButton immediately right of File that opens a PopupMenu with Map Settings and Show Grid items.

#### Scenario: Settings menu opens
- **WHEN** the player clicks the "Settings" button
- **THEN** a PopupMenu appears with items: "Map Settings", "Show Grid"

#### Scenario: Settings menu Map Settings item
- **WHEN** the player clicks "Map Settings" in the Settings menu
- **THEN** the Map Settings dialog opens

#### Scenario: Settings menu Show Grid toggle
- **WHEN** the player clicks "Show Grid" in the Settings menu
- **THEN** the grid visibility toggles on/off and the checkmark updates

#### Scenario: Show Grid defaults to off
- **WHEN** the map editor opens
- **THEN** "Show Grid" is unchecked and the grid is not visible

### Requirement: Toolbar layout without standalone Save/Load
The toolbar SHALL NOT display standalone Save, Load, Grid checkbox, X Offset, or Z Offset controls. These are accessible through the File and Settings menus/dialogs.

#### Scenario: Toolbar on open
- **WHEN** the map editor opens
- **THEN** the toolbar shows: `[File] [Settings] | [Paint Height] [Paint Tiberium] [Place Tree] [Erase] | [Strength slider] [Radius spinbox] | [Height label]`
