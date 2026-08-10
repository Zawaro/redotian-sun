## MODIFIED Requirements

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
