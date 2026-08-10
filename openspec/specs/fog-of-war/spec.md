# fog-of-war Specification

## Purpose

Authoritative per-player fog-of-war grid providing shroud / fog / visible cell states, height-aware shadowcasting, allied vision sharing, blue-bounds reveal limits, circular trigger reveals, optional shroud growth, and incremental dirty-cell updates.

## Requirements

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

### Requirement: Change notification
The system SHALL emit a `state_changed` signal each resolve tick when any cells were processed by `resolve_dirty`. The signal SHALL NOT be emitted when nothing changed.

#### Scenario: Signal emitted on resolution
- **WHEN** `resolve_dirty` processes one or more dirty cells
- **THEN** the `state_changed` signal is emitted

#### Scenario: No signal when nothing changed
- **WHEN** `resolve_dirty` processes zero cells
- **THEN** the `state_changed` signal is not emitted

### Requirement: Ref-counted revealer registration
The system SHALL expose `register_revealer(player_id, center_cell, radius, viewer_height, blocks_terrain) -> key`, `unregister_revealer(player_id, key)`, and `move_revealer(player_id, key, new_cell)`. Registration SHALL mark the revealed cells explored and increment their `visible_count`; unregistration SHALL decrement it. Overlapping revealers SHALL stack via reference counts, so a cell stays visible while at least one revealer covers it. A revealer that moves SHALL call `move_revealer` with its new cell; the move SHALL transfer the revealer's visibility contribution from the old disc to the new disc without leaking counts. A `move_revealer` SHALL re-stamp only the entering/exiting crescent between the old and new discs; cells covered by both discs SHALL keep their existing `visible_count` contribution and SHALL NOT be re-stamped.

#### Scenario: Single revealer reveals radius
- **WHEN** a revealer with radius R registers at cell C
- **THEN** all in-bounds cells within R of C resolve to visible, and cells beyond R are unaffected

#### Scenario: Overlapping revealers stack
- **WHEN** two revealers both cover a cell
- **THEN** the cell resolves to visible, and remains visible while either revealer is active

#### Scenario: Last revealer leaves
- **WHEN** the last revealer covering a cell unregisters
- **THEN** the cell reverts to fog (it was explored), never to shroud

#### Scenario: Unregister with no revealer
- **WHEN** `unregister_revealer` is called with a key that is not registered
- **THEN** the call is a no-op and does not corrupt counts

#### Scenario: Revealer moves between cells
- **WHEN** a revealer moves from cell A to cell B via `move_revealer`
- **THEN** cell A loses its visibility contribution and cell B gains it, with no leftover counts

#### Scenario: Move re-stamps only the crescent
- **WHEN** a revealer moves one cell from A to B
- **THEN** only the cells that entered or left the union of the two discs are re-stamped; cells covered by both discs keep their contribution and are not re-stamped

#### Scenario: Shadow-edge flip self-corrects
- **WHEN** a move leaves an overlap cell's line-of-sight reachability changed at a terrain shadow edge (its segment passes within one cell of a blocker)
- **THEN** the cell keeps its previously stamped state and no count leaks; the discrepancy self-corrects on a subsequent crossing that re-stamps the cell

### Requirement: Height-aware shadowcasting
Revealed cells SHALL be computed by per-cell Bresenham line-of-sight from the revealer center to each candidate cell within radius. A candidate cell is revealed only if no intermediate cell blocks it. A cell blocks vision when its terrain height (`TerrainSystem.get_cell_max_height`) exceeds the viewer height by more than `max_height_delta`. Buildings do not block line of sight. The revealer's own cell and the candidate cell itself are not blockers. Viewer height SHALL be supplied at registration. Air revealers (`blocks_terrain = false`) SHALL ignore all blockers and reveal a full circle within radius.

#### Scenario: Hill blocks vision
- **WHEN** a low revealer is below a hill whose height exceeds the viewer height plus delta
- **THEN** cells on the far side of the hill are not revealed, and the hill's own cells are revealed

#### Scenario: High ground sees over
- **WHEN** a revealer sits atop a ridge with viewer height above the valley floor
- **THEN** cells in the valley below within radius are revealed

#### Scenario: Building does not block vision
- **WHEN** a building cell lies on the line between a revealer and a candidate cell
- **THEN** the candidate cell is still revealed by that revealer, and the building's own cells are revealed

#### Scenario: Air revealer ignores blockers
- **WHEN** an air revealer (`blocks_terrain = false`) registers over a hill
- **THEN** all cells within radius are revealed regardless of intervening terrain

### Requirement: Reveal limiter to visible bounds
No cell SHALL ever be explored or made visible outside the blue visible-bounds play area. All reveal operations (shadowcasting, `explore_area`, `reveal_area`, `explore_all`) SHALL clamp to `BoundsSystem.is_in_play_area(cell)`. Cells outside the play area SHALL remain permanently shrouded. `get_explored_percentage` SHALL compute against the play-area cell count.

#### Scenario: Reveal clamped at play edge
- **WHEN** a revealer or explore_area is centered near the blue bounds edge
- **THEN** cells outside `BoundsSystem.is_in_play_area` are not explored or visible

#### Scenario: Explore all respects bounds
- **WHEN** `explore_all(player_id)` is called
- **THEN** exactly the play-area cells are marked explored and no cell outside the play area is touched

### Requirement: Allied sharing
Visibility and exploration queries SHALL fold in same-team players. `is_visible(query_player, cell)` SHALL return true if the cell is visible to the querying player or any player on the same team (`PlayerManager.get_players_by_team`). `is_explored` SHALL behave likewise. Revealers remain registered against their own player's grid; sharing is a query-time union and SHALL NOT mutate allied grids.

#### Scenario: Same-team player shares vision
- **WHEN** player A and player B are on the same team and A reveals a cell
- **THEN** `is_visible(B, cell)` returns true

#### Scenario: Enemy vision not shared
- **WHEN** player A and player B are on different teams and A reveals a cell
- **THEN** `is_visible(B, cell)` returns false unless B also sees it

#### Scenario: Sharing does not mutate allied grid
- **WHEN** player A reveals a cell visible to ally B
- **THEN** player B's own per-player grid state is unchanged (sharing is read-time only)

### Requirement: Circular trigger reveals
The system SHALL expose `explore_area(player_id, center_cell, radius)` that permanently marks all in-bounds, in-play-area cells within radius as explored (they resolve to fog when no revealer is present). It SHALL also expose `reveal_area(player_id, center_cell, radius, duration)` that reveals the circle as visible for the duration (air-style, no blockers), then reverts to explored; reverted cells SHALL resolve to fog, never shroud.

#### Scenario: Explore area permanent
- **WHEN** `explore_area` is called for a circle
- **THEN** cells inside the circle remain explored (fog) even after the call returns and no revealer is present

#### Scenario: Reveal area reverts to fog
- **WHEN** `reveal_area` with duration D is called and D elapses
- **THEN** cells inside the circle revert from visible to fog (explored, not visible)

#### Scenario: Reveal area clamps to play area
- **WHEN** `reveal_area` is centered near the play-area edge
- **THEN** cells outside the play area are never revealed

### Requirement: Shroud growth
When enabled, the shroud SHALL grow one cell step per interval. The system SHALL expose the growth interval via `GlobalRules.shroud_growth_interval` and gate growth on `GlobalRules.shroud_grows`. On each interval tick, for each player, any cell that is explored, not currently visible, and adjacent to a shrouded cell SHALL revert to shroud (its `explored` flag is cleared). Cells under active vision SHALL be protected from reverting. Cells outside the play area are unaffected (already shroud).

#### Scenario: Frontier reverts one step per interval
- **WHEN** `shroud_grows` is true and the interval elapses
- **THEN** the explored/shroud frontier recedes by exactly one cell ring per tick

#### Scenario: Visible cells protected
- **WHEN** a cell is under active vision when the growth interval elapses
- **THEN** it does not revert to shroud

#### Scenario: Growth disabled is inert
- **WHEN** `shroud_grows` is false
- **THEN** no cells ever revert to shroud from growth

### Requirement: Incremental updates
The system SHALL resolve cell state only for dirty cells and SHALL short-circuit when nothing changed. A fixed resolve tick SHALL process only cells whose dirty flags were set since the previous tick. Shadowcasting SHALL only be recomputed when a revealer registers, unregisters, or moves to a new cell; a move SHALL re-stamp only the entering/exiting crescent between the old and new discs, leaving overlap cells' `visible_count` untouched.

#### Scenario: No work when nothing changed
- **WHEN** no revealer registers, unregisters, or crosses a cell between ticks
- **THEN** the resolve pass performs no per-cell recomputation

#### Scenario: Only changed cells resolved
- **WHEN** a single revealer moves one cell
- **THEN** only cells affected by that movement are re-resolved

#### Scenario: Move re-stamps crescent not full disc
- **WHEN** a revealer moves one cell
- **THEN** the re-stamp covers only the crescent cells that entered or left the disc, not the full disc
