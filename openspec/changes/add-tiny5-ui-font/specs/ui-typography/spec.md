# ui-typography — Tiny5 Font for In-Game UI Text

## ADDED Requirements

### Requirement: Tiny5 font asset with pixel-crisp import
The project SHALL provide the Tiny5 Regular font as a FontFile at `assets/fonts/Tiny5/Tiny5-Regular.ttf` with its SIL OFL license file, imported with antialiasing disabled, hinting disabled, and subpixel positioning disabled so the 5x5 pixel grid renders crisp.

#### Scenario: Font asset exists and imports without smoothing
- **WHEN** the project is opened and `assets/fonts/Tiny5/Tiny5-Regular.ttf` is imported
- **THEN** the generated `.import` file has antialiasing off, hinting off, and subpixel positioning disabled
- **AND** the OFL license file sits alongside the TTF

### Requirement: Sidebar cameo labels use Tiny5 style
Sidebar build-cameo text labels (entity name and cost) SHALL render in Tiny5 at 10px, white, with a 1px black outline, left-aligned, and rendered uppercase, with word-wrap enabled for long names. The cost label SHALL remain on the cameo (top zone); the tooltip continues to carry name, cost, time, and power.

#### Scenario: Name label styling
- **WHEN** a build cameo is created for an entity whose display name is "Tiberium Silo"
- **THEN** the name label displays "TIBERIUM SILO" in Tiny5, white, with a 1px black outline, left-aligned
- **AND** text longer than one line wraps within the cameo width

#### Scenario: Cost label styling
- **WHEN** a build cameo is created for an entity with a positive cost
- **THEN** the cost label renders in Tiny5 with the same white color, 1px black outline, left alignment, and uppercase treatment as the name label

#### Scenario: Backward-compatible cameo structure
- **WHEN** the sidebar grid rebuilds
- **THEN** each cameo is still a Button with programmatic child labels (no `.tscn` changes required)

### Requirement: Selection overlay draws entity name labels
The selection overlay SHALL draw the display name of every tracked entity that is selected or hovered, centered below its bracket rectangle, in Tiny5, white, with a 1px black outline, uppercase. The name SHALL be sourced from the entity's `StatsComponent` display_name at collect time.

#### Scenario: Selected unit shows name label
- **WHEN** a unit with `StatsComponent.display_name` = "Light Infantry" is selected
- **THEN** the overlay draws "LIGHT INFANTRY" centered below the unit's bracket rect

#### Scenario: Hovered entity shows name label
- **WHEN** the pointer hovers a selectable entity without an active selection
- **THEN** the overlay draws the entity's uppercase name below its bracket

#### Scenario: Entity without StatsComponent
- **WHEN** a tracked entity has no `StatsComponent` or an empty display_name
- **THEN** no name label is drawn for that entity and no error is raised

### Requirement: Power readout uses Tiny5 with outline
The selected-producer power readout ("POWER = / DRAIN =") SHALL render in Tiny5 with a 1px black outline, keeping its existing green color and 14px size.

#### Scenario: Power label restyle
- **WHEN** a selected producer reports a live power grid
- **THEN** the power label draws in Tiny5, green, with a 1px black outline, centered in the bracket as before
