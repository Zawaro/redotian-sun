## ADDED Requirements

### Requirement: Edit menu with undo/redo
The menu bar SHALL display an "Edit" menu with Undo and Redo items bound to the editor undo stack (Ctrl+Z / Ctrl+Y), disabled when the corresponding stack side is empty.

#### Scenario: Undo menu item
- **WHEN** the player clicks Edit ▸ Undo after an edit
- **THEN** the most recent command reverts, identical to Ctrl+Z

#### Scenario: Disabled when empty
- **WHEN** no commands have been pushed
- **THEN** Undo and Redo are disabled

### Requirement: View menu
The menu bar SHALL display a "View" menu with checkable items: Show Grid, Framework, Preview Pane. Show Grid keeps its current behavior; Framework toggles framework render mode; Preview Pane toggles the sidebar preview pane.

#### Scenario: View menu toggles
- **WHEN** the player toggles any View menu item
- **THEN** the corresponding view state (grid visibility, framework mode, preview pane) flips and the checkmark updates

### Requirement: Tools menu
The menu bar SHALL display a "Tools" menu listing the editor tools (height raise/lower variants, flatten, LAT paint, waypoint, delete, cliff, resource paint, tree placement, player start). Selecting a tool activates it exactly like its top-bar toggle.

#### Scenario: Tools menu selects a tool
- **WHEN** the player clicks "Flatten" in the Tools menu
- **THEN** the Flatten tool activates and any previously active tool deactivates

### Requirement: Scripting menu stub
The menu bar SHALL display a "Scripting" menu containing a disabled "Script Console" item as a placeholder for a future scripting system.

#### Scenario: Scripting stub
- **WHEN** the player opens the Scripting menu
- **THEN** "Script Console" is visible but disabled

## MODIFIED Requirements

### Requirement: File dropdown menu
The editor menu bar SHALL display a "File" menu (top of the left sidebar) that opens a PopupMenu with New, Load, Save, and Map Settings items.

#### Scenario: File menu opens
- **WHEN** the player clicks the "File" menu
- **THEN** a PopupMenu appears with items: "New", "Load", "Save", "Map Settings"

#### Scenario: File menu New item
- **WHEN** the player clicks "New" in the File menu
- **THEN** the New Map dialog opens

#### Scenario: File menu Load item
- **WHEN** the player clicks "Load" in the File menu
- **THEN** the existing load FileDialog opens (from EditorSaveLoad)

#### Scenario: File menu Save item
- **WHEN** the player clicks "Save" in the File menu
- **THEN** the existing save FileDialog opens (from EditorSaveLoad)

#### Scenario: File menu Map Settings item
- **WHEN** the player clicks "Map Settings" in the File menu
- **THEN** the Map Settings dialog opens

## REMOVED Requirements

### Requirement: Settings dropdown menu
**Reason**: The Settings menu is dissolved into the new menu bar — Show Grid moves under View, Map Settings moves under File.
**Migration**: Use View ▸ Show Grid for grid visibility and File ▸ Map Settings for the Map Settings dialog.

### Requirement: Toolbar layout without standalone Save/Load
**Reason**: The floating toolbar is replaced wholesale by the four-region layout: the menu bar lives in the sidebar and the tool buttons live in the top tool bar.
**Migration**: Tools are reachable from the top bar's tool toggles and the Tools menu; save/load from File; grid from View.
