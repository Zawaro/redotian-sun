## MODIFIED Requirements

### Requirement: Bridge span overlay entity
A bridge SHALL be modeled as one or more non-blocking OVERLAY entities, each covering exactly one grid cell at one deck level, carrying a `BridgeComponent`. A bridge piece SHALL span three lanes (cells) across by one cell along; each covered cell is placed as its own overlay entity one by one. Cells of one piece SHALL share a piece identifier (`piece_id`). Bridge entities SHALL join a `"bridge"` group so the live cell registry can resolve them, and the component SHALL publish the deck level, the bridge kind, the end flag, the deck land of its lane, and the piece identifier. Bridge cells SHALL NOT participate in ground occupancy or block ground movement.

#### Scenario: Placing a piece registers its three lanes
- **WHEN** a multi-cell bridge piece is placed across three lanes
- **THEN** each covered cell resolves as a bridge cell at the piece's level and all share one piece identifier

#### Scenario: Bridge does not block ground occupancy
- **WHEN** a unit is ordered onto the ground under a bridge deck
- **THEN** the ground cell is occupiable (the bridge does not block the ground level)

#### Scenario: Component publishes level, kind, and lane land
- **WHEN** a bridge entity is created
- **THEN** its `BridgeComponent` publishes the deck level, bridge kind, end flag, deck land, and piece identifier

### Requirement: Deck surface resolves without overwriting underlying land
`TerrainSystem.get_land_type(cell, level)` SHALL return the deck's resolved land type for a cell covered by an intact bridge at `level`, resolved as a live overlay in the same manner the existing `"resource"` type is derived. A deck cell SHALL resolve an ordinary land type, not a synthetic `bridge` type: `road` (or `clear`) for a road-bridge lane, and `railroad` for a rail-bridge middle lane. The underlying ground land type of the cell SHALL remain unchanged, and when the covering bridge piece is removed or destroyed the deck surface SHALL be removed and the cell SHALL revert to ground behavior.

#### Scenario: Road bridge cell reports road at its level
- **WHEN** a road bridge covers a water cell at level `L`
- **THEN** `get_land_type(cell, L)` returns `"road"`

#### Scenario: Rail bridge middle lane reports railroad
- **WHEN** a rail bridge covers a water cell at level `L` on its middle lane
- **THEN** `get_land_type(cell, L)` returns `"railroad"`

#### Scenario: Water beneath is preserved
- **WHEN** a bridge covering a water cell is removed
- **THEN** `get_land_type(cell, 0)` returns `"water"`

#### Scenario: Painted overlay untouched
- **WHEN** a bridge covers a cell and the bridge is removed
- **THEN** any painted land-type override on that cell is unchanged

### Requirement: Deck surface passability is road with the terrain figure skipped
A bridge deck surface SHALL be passable and costed from the land row its deck cell resolves, with the destination land type's terrain figure skipped entirely for the deck. A road-bridge lane SHALL use the locomotor's Road row; a rail-bridge middle lane SHALL use its Railroad row. A ground locomotor SHALL cross a road bridge span over water where it cannot cross the uncovered water, including a tracked unit whose underlying water speed is zero. A water-only locomotor SHALL NOT treat a deck as passable.

#### Scenario: Wheeled crosses a bridge over water
- **WHEN** a wheeled unit pathfinds from one shore to the other across a bridge span over water
- **THEN** the path crosses the deck cells and not the uncovered water

#### Scenario: Deck skips the underlying terrain figure
- **WHEN** a tracked unit whose water speed is zero crosses a road deck over water
- **THEN** the deck is passable at the road cost

#### Scenario: Rail lane uses the railroad row
- **WHEN** a unit crosses the middle lane of a rail bridge
- **THEN** the deck is passable and costed from the locomotor's Railroad row

#### Scenario: Removal blocks the crossing
- **WHEN** the deck cells between a wheeled unit and the far shore are removed
- **THEN** the unit no longer paths across the former deck cells over water

#### Scenario: Ship does not use the deck
- **WHEN** a ship pathfinds across a body of water spanned by a bridge
- **THEN** the deck is not treated as passable to the ship

### Requirement: Rail bridges are high bridges only
A rail bridge SHALL exist only as a high bridge variant. A rail bridge SHALL NOT be authored or placed as a low bridge. A rail bridge SHALL be three lanes whose middle lane resolves `railroad` and whose outer lanes resolve `road`; the bridge kind SHALL distinguish road from rail, and rail-specific movement restrictions SHALL be applied by the movement system from that kind.

#### Scenario: Rail kind is high only
- **WHEN** a bridge is authored with the rail kind
- **THEN** it uses the high bridge geometry and four-step deck

#### Scenario: Rail middle lane is railroad, outer lanes are road
- **WHEN** a rail bridge piece is authored
- **THEN** its middle lane resolves `railroad` and its outer lanes resolve `road`

#### Scenario: Low rail bridge refused
- **WHEN** a bridge is authored as low with the rail kind
- **THEN** it is rejected or normalized to the road low bridge

### Requirement: Bridge ends are terrain objects with a road cut
A high bridge's end SHALL be a `TerrainObject` generated from the original engine's bridge tile footprints (`ovrps` / `tovrps`), of `cell_type = "cliff"`, carrying a road cut through its covered cells with per-cell `land` and `corners` data. The cut SHALL span three cells at the deck grade (`road` on a road end; `railroad` on the rail end's middle lane), the banks SHALL be `rock` at the deck grade, and the base cells SHALL be `rock` at ground grade. A low bridge SHALL use slope end pieces instead of a terrain-object end.

#### Scenario: High bridge end is a three-wide road cut
- **WHEN** a high bridge end is authored
- **THEN** its three cut cells carry the road land at the deck grade, flanked by rock banks at the deck grade and rock base cells at ground grade

#### Scenario: Rail end cut is railroad
- **WHEN** a rail bridge end is authored
- **THEN** its middle cut cell carries the railroad land

#### Scenario: Road cut admits traffic
- **WHEN** a ground unit follows the road cut to a high bridge end
- **THEN** it transitions onto the deck at the deck grade

#### Scenario: Low bridge uses slope ends
- **WHEN** a low bridge is authored
- **THEN** its ends are slope pieces, not terrain-object cliff ends
