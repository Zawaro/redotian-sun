# ui-typography — Tiny5 Font for In-Game UI Text

## ADDED Requirements

### Requirement: Tiny5 font asset with pixel-crisp import
The project SHALL provide the Tiny5 Regular font as a FontFile at `assets/fonts/Tiny5/Tiny5-Regular.ttf` with its SIL OFL license file, imported with antialiasing disabled, hinting disabled, and subpixel positioning disabled so the 5x5 pixel grid renders crisp.

#### Scenario: Font asset exists and imports without smoothing
- **WHEN** the project is opened and `assets/fonts/Tiny5/Tiny5-Regular.ttf` is imported
- **THEN** the generated `.import` file has antialiasing off, hinting off, and subpixel positioning disabled
- **AND** the OFL license file sits alongside the TTF

### Requirement: Sidebar cameo labels use Tiny5 style
Sidebar build-cameo text labels (entity name and cost) SHALL render in Tiny5 at 16px, white, with an outline whose size dynamically tracks 75% of the current font size, left-aligned, and rendered uppercase, with word-wrap enabled for long names. The name label SHALL sit at the bottom of the cameo and pack words toward the end (e.g. "NOD" / "POWER PLANT", never "NOD POWER" / "PLANT") so the top cameo art stays visible. The cost label SHALL remain on the cameo (top zone); the tooltip continues to carry name, cost, time, and power.

#### Scenario: Name label styling
- **WHEN** a build cameo is created for an entity whose display name is "Tiberium Silo"
- **THEN** the name label displays "TIBERIUM SILO" in Tiny5, white, with an outline of 75% of the font size, left-aligned at the bottom of the cameo
- **AND** text longer than one line wraps with the fullest words on the last line

#### Scenario: Word packing prefers the last line
- **WHEN** a display name wraps at the cameo width (e.g. "NOD POWER PLANT")
- **THEN** the label breaks as "NOD" / "POWER PLANT" — the last line carries as many words as fit

#### Scenario: Outline scales with font size
- **WHEN** the cameo font size constant changes (e.g. 16 → 20)
- **THEN** the outline size follows at 75% of the new size without further edits

#### Scenario: Cost label styling
- **WHEN** a build cameo is created for an entity with a positive cost
- **THEN** the cost label renders in Tiny5 with the same white color, dynamic outline, left alignment, and uppercase treatment as the name label

#### Scenario: Backward-compatible cameo structure
- **WHEN** the sidebar grid rebuilds
- **THEN** each cameo is still a Button with programmatic child labels (no `.tscn` changes required)

### Requirement: Power readout uses Tiny5 with zoom-following outline
The selected-producer power readout ("POWER = / DRAIN =") SHALL render in Tiny5, keeping its existing green color, at a base size of 16px that scales dynamically with camera zoom (the same 1/camera-size relationship the projected health bar gets), with an outline whose size tracks 75% of the live font size.

#### Scenario: Power label restyle
- **WHEN** a selected producer reports a live power grid
- **THEN** the power label draws in Tiny5, green, with an outline of 75% of its font size, centered in the bracket as before

#### Scenario: Font follows camera zoom
- **WHEN** the camera zooms in or out (orthographic size shrinks or grows from the default 20)
- **THEN** the power label font size scales proportionally (16px at the default size), never below the minimum scale, with the outline tracking at 75%

## REMOVED Requirements

### Requirement: Selection overlay draws entity name labels
**Reason**: Over-reach — name labels were only wanted for the power readout on producer structures. Entity name display already exists behind the debug menu's entity-id toggle (`DebugVisualizer._draw_entity_ids`).
**Migration**: None — remove the overlay name-label draw; debug name display remains available via the debug menu toggle.
