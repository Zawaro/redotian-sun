## ADDED Requirements

### Requirement: Brush size
The top bar SHALL provide a brush size control (1×1 up to at least 5×5) that applies to the height tools and the LAT brush. Brushed regions are square cell areas centered on the hovered cell, clipped to the playable diamond.

#### Scenario: Brush grows
- **WHEN** the player sets brush size to 3×3
- **THEN** height and LAT operations affect a 3×3 cell area around the hovered cell

#### Scenario: Brush clipped at map edge
- **WHEN** a brush region extends past the playable diamond
- **THEN** only in-diamond cells are affected

### Requirement: Combined Raise/Lower tool
The editor SHALL provide a combined Raise/Lower tool: left-drag raises brushed cells (existing `raise_cell` semantics), Ctrl+left-drag lowers them. Right-click stays cancel/deselect.

#### Scenario: Left-drag raises
- **WHEN** the player left-drags with the combined tool
- **THEN** brushed cells rise one height level per threshold step

#### Scenario: Ctrl+left-drag lowers
- **WHEN** the player Ctrl+left-drags with the combined tool
- **THEN** brushed cells lower one height level per threshold step

### Requirement: Separate Raise and Lower tools
The editor SHALL provide separate Raise and Lower tools that pin the direction: Raise only raises, Lower only lowers.

#### Scenario: Lower tool never raises
- **WHEN** the player drags upward with the Lower tool active
- **THEN** cells lower (never raise), down to level 0

### Requirement: Flatten tool
The editor SHALL provide a Flatten tool: the first click records the hovered cell's height as the reference level; dragging then levels every brushed cell to that reference (writing all four corner vertices), while the existing cascade re-slopes surrounding unpinned cells.

#### Scenario: Flatten to clicked level
- **WHEN** the player clicks a cell at height 4 then drags across uneven ground
- **THEN** every brushed cell ends with all corner heights equal to 4

#### Scenario: Flatten stops at pin
- **WHEN** the flatten brush crosses a pinned cliff cell
- **THEN** the pinned cell is skipped unchanged

### Requirement: LAT brush
The editor SHALL provide a LAT brush that paints the selected land type onto brushed cells via `TerrainSystem.set_land_type`. The bottom bar's selected group member SHALL drive which land type the brush paints; the top-bar LAT dropdown and the bottom-bar selection SHALL stay in sync.

#### Scenario: Paint land type
- **WHEN** the player selects "pavement" and paints over clear cells
- **THEN** those cells' land type becomes pavement and the renderer/locomotor see the new type

#### Scenario: Selections stay in sync
- **WHEN** the player picks "sand" in the bottom bar
- **THEN** the top-bar LAT dropdown also shows sand

### Requirement: Only paint on clear
When the "Only paint on clear" checkbox is enabled, the height and LAT brushes SHALL skip cells that host entities, resource crystals, or pins. When disabled, painting applies regardless.

#### Scenario: Skips occupied cells
- **WHEN** "Only paint on clear" is on and the brush crosses a cell holding a tree
- **THEN** that cell is unchanged while its empty neighbors are painted

#### Scenario: Off applies everywhere
- **WHEN** "Only paint on clear" is off and the brush crosses the same tree cell
- **THEN** that cell is painted too

### Requirement: Auto-LAT v1
The top bar SHALL provide an Auto-LAT checkbox. In v1 it SHALL be fully plumbed into the painting path as a session-scoped checkbox (no persistence — no editor-settings store exists), and its only effect SHALL be painting the selected land type; transition-piece selection SHALL be deferred until transition land types exist.

#### Scenario: Checkbox toggles
- **WHEN** the player toggles Auto-LAT
- **THEN** the state is stored and applied to subsequent strokes (v1 behavior identical to manual LAT selection)

### Requirement: Bottom bar LandType groups
The bottom bar SHALL list land types grouped by their `group` field behind a "Search tileset…" filter, with each member rendered as a swatch preview. Selecting a member selects it as the LAT brush's land type. Groups with no members SHALL NOT appear; the search filters both groups and members by name.

#### Scenario: Groups listed
- **WHEN** the editor opens
- **THEN** the bar shows groups (e.g. Sand, Pavement, Green, Crystal, Mold, Clear) each expandable to their member land types with swatch previews

#### Scenario: Search filters
- **WHEN** the player types "pave" into the search field
- **THEN** only the Pavement group/member remains visible

#### Scenario: Member selects LAT
- **WHEN** the player clicks a member swatch
- **THEN** the LAT brush's land type becomes that member
