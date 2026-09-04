## ADDED Requirements

### Requirement: EditorTool interface
Editor tools SHALL implement a common informal interface: `activate()`, `deactivate()`, `on_input(event) -> bool` (true = consumed), and an active-state query. Tool-specific sub-states (e.g. cliff drawing, flatten reference picking) SHALL live inside the tool, not in the dispatcher.

#### Scenario: Activation lifecycle
- **WHEN** a tool is selected in the top bar
- **THEN** the previously active tool is deactivated first and the new tool's `activate()` runs

#### Scenario: Sub-state stays internal
- **WHEN** the Cliff tool is in its drawing sub-state
- **THEN** the dispatcher holds no cliff-specific state; cancelling or accepting is handled entirely by the tool

### Requirement: Single dispatch loop
`MapEditor._input` SHALL route world input through a single loop over registered tools: the active tool's `on_input` is called and, when it returns true, the event is consumed. Input SHALL NOT reach tools when the cursor hovers a GUI control, and right-click SHALL remain reserved for cancel/deselect behavior.

#### Scenario: Active tool consumes
- **WHEN** the active tool's `on_input` returns true for an event
- **THEN** no other tool or world handler processes that event

#### Scenario: GUI hover guard
- **WHEN** a mouse event arrives while the cursor is over an editor control
- **THEN** the dispatch loop does not run for that event

#### Scenario: No magic tool ids
- **WHEN** a tool checks whether it is active
- **THEN** it queries its own active state rather than comparing the editor's tool field against a numeric literal

### Requirement: Existing tools migrated to the protocol
EntityPlacer, EntitySelector, ResourcePainter, PlayerStartTool, HeightPainter, WaypointTool, and CliffTool SHALL all register with the dispatch loop through the common interface; the per-tool elif chain in `MapEditor._input` SHALL be removed.

#### Scenario: Selection still works with no tool active
- **WHEN** no placement/painting tool is active and the player left-clicks an entity
- **THEN** EntitySelector handles the click and selects it

#### Scenario: Height painting still works
- **WHEN** the Raise tool is active and the player drags on the terrain
- **THEN** HeightPainter (via the protocol) raises cells along the drag
