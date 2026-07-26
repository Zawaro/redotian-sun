## MODIFIED Requirements

### Requirement: Toolbar with toggleable tools
The map editor SHALL display a toolbar row at the top with a File MenuButton, Settings MenuButton, horizontally arranged tool buttons (Paint Height, Paint Tiberium, Place Tree, Erase), a Strength HSlider, a Radius SpinBox, and a Height label. Save, Load, Grid, and offset controls are NOT displayed as standalone toolbar items.

#### Scenario: Tool layout
- **WHEN** the map editor opens
- **THEN** the toolbar shows `[File] [Settings] | [Paint Height] [Paint Tiberium] [Place Tree] [Erase] | [Strength slider] [Radius spinbox] | [Height label]`

#### Scenario: Radio-button tool selection
- **WHEN** the player clicks a toggleable tool (Paint Height, Paint Tiberium, Place Tree, Erase)
- **THEN** the previously active tool is deactivated, and the clicked tool is activated
