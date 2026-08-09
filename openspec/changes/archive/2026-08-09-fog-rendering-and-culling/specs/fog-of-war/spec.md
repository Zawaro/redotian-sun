## ADDED Requirements

### Requirement: Change notification
The system SHALL emit a `state_changed` signal each resolve tick when any cells were processed by `resolve_dirty`. The signal SHALL NOT be emitted when nothing changed.

#### Scenario: Signal emitted on resolution
- **WHEN** `resolve_dirty` processes one or more dirty cells
- **THEN** the `state_changed` signal is emitted

#### Scenario: No signal when nothing changed
- **WHEN** `resolve_dirty` processes zero cells
- **THEN** the `state_changed` signal is not emitted

## MODIFIED Requirements

### Requirement: ShroudSystem autoload and per-player grid
The system SHALL provide a `ShroudSystem` autoload that maintains an authoritative per-player fog-of-war grid. The grid SHALL be sized to the terrain cell index space (`CellUtil.get_diamond_extent(TerrainSystem.grid_cells)` — W+H cells per axis for a grid_cells of W×H) and re-initialized when the terrain grid changes. Per player, the system SHALL track: an `explored` boolean per cell (latch, never un-set by vision), a `visible_count` per cell (reference count of active revealers), and dirty flags per cell for incremental updates. Cell state SHALL resolve to shroud (0), fog (1), or visible (2): unexplored is shroud; explored with no active visibility is fog; explored with one or more active visibility sources is visible. Visible and fog states are not mutually supersets — a cell SHALL be fog only when explored and not currently visible.

#### Scenario: Grid initialized from terrain
- **WHEN** ShroudSystem initializes with a terrain grid whose diamond extent is N×M
- **THEN** every cell resolves to shroud and `explored` is false for all cells

#### Scenario: Grid re-initialized on terrain change
- **WHEN** the terrain grid is re-initialized (new map)
- **THEN** ShroudSystem clears all per-player state and re-sizes to the new diamond extent

#### Scenario: Fog not a superset of visible
- **WHEN** a cell is explored but no revealer currently covers it
- **THEN** the cell resolves to fog (not visible)

#### Scenario: Visible not a superset of explored
- **WHEN** a revealer covers a cell that was never marked explored
- **THEN** the cell resolves to visible and SHALL also become explored
