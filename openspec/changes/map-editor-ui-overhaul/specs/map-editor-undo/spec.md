## ADDED Requirements

### Requirement: Undo/redo command stack
The editor SHALL maintain an undo stack. Ctrl+Z SHALL undo the most recent command and Ctrl+Y (and Edit ▸ Redo) SHALL redo the most recently undone command. New edits after an undo SHALL truncate the redo branch. Undo/redo entries SHALL also be available in the Edit menu.

#### Scenario: Undo restores prior state
- **WHEN** the player paints several height changes and presses Ctrl+Z
- **THEN** the terrain state (vertices, land types, pins) reverts to what it was before the last command

#### Scenario: Redo re-applies
- **WHEN** the player presses Ctrl+Y after an undo
- **THEN** the undone edit is re-applied exactly

#### Scenario: New edit truncates redo
- **WHEN** the player undoes, then makes a new edit
- **THEN** redo is unavailable until another command is pushed

### Requirement: Region-snapshot terrain commands
All cell-space mutations (height painting, LAT painting, flatten, cliff stamping/unpinning) SHALL be captured as one region-snapshot command containing before/after values for exactly the affected vertices, land types, and cell pins. Restoring SHALL write the "before" values back, invalidate height snapshots, and emit `cell_changed` for affected cells.

#### Scenario: Only the touched region is captured
- **WHEN** a brush stroke changes 6 cells
- **THEN** the pushed command records before/after only for vertices and cells those edits touched (including cascade side effects)

#### Scenario: Restore emits updates
- **WHEN** a terrain command is undone
- **THEN** affected cells emit `cell_changed` and the renderer updates them

### Requirement: Brush strokes coalesce
A drag-driven tool (raise/lower/combined, flatten, LAT brush) SHALL accumulate its per-frame diffs and push exactly one command when the stroke ends (mouse release). No intermediate command SHALL be pushed per cell or per height step.

#### Scenario: One command per stroke
- **WHEN** the player drags the Raise tool across 30 cells and releases
- **THEN** the undo stack contains exactly one new command, and undoing reverts the whole stroke

### Requirement: Entity and waypoint commands
Entity placement, entity deletion, waypoint placement, and waypoint deletion SHALL each push a command that restores or removes the affected entity/waypoint on undo/redo.

#### Scenario: Undo entity placement
- **WHEN** the player places an entity and presses Ctrl+Z
- **THEN** the entity is removed from the scene and the tracked data

#### Scenario: Undo waypoint placement
- **WHEN** the player places a waypoint and presses Ctrl+Z
- **THEN** the waypoint is removed

### Requirement: Cliff Accept is atomic
A cliff tool Accept SHALL push exactly one command covering all stamped cells (vertices, land types, pins) regardless of path length; Cancel SHALL push nothing.

#### Scenario: Undo a cliff stamp
- **WHEN** the player accepts a 9-cell cliff path and presses Ctrl+Z
- **THEN** the entire path reverts: heights, land types, and pins

#### Scenario: Cancel leaves no command
- **WHEN** the player draws a cliff path and clicks Cancel
- **THEN** no command is pushed and the map is unchanged
