# bridges Specification

## Purpose

A bridge is a set of non-blocking per-cell overlay entities carrying a `BridgeComponent`, each covering exactly one grid cell at one deck level, that resolve a walkable deck surface without overwriting the underlying ground land and that persist through the map `entities` array. The capability defines low, high, and rail bridge geometry, extra-high stacked decks, the bridge-end `TerrainObject` road cut and its stamp-to-grid and `cell_pins` persistence, and the bridge piece destructibility split.

## Requirements

### Requirement: Bridge span overlay entity
A bridge SHALL be modeled as one or more non-blocking OVERLAY entities, each covering exactly one grid cell at one deck level, carrying a `BridgeComponent`. A bridge piece SHALL span a row of cells; cells of one piece SHALL share a piece identifier (`piece_id`). Bridge entities SHALL join a `"bridge"` group so the live cell registry can resolve them, and the component SHALL publish the deck level, the bridge kind, the end flag, and the piece identifier. Bridge cells SHALL NOT participate in ground occupancy or block ground movement.

#### Scenario: Placing a piece registers its cells
- **WHEN** a multi-cell bridge piece is placed over a row of cells
- **THEN** each covered cell resolves as a bridge cell at the piece's level and all share one piece identifier

#### Scenario: Bridge does not block ground occupancy
- **WHEN** a unit is ordered onto the ground under a bridge deck
- **THEN** the ground cell is occupiable (the bridge does not block the ground level)

#### Scenario: Component publishes level and kind
- **WHEN** a bridge entity is created
- **THEN** its `BridgeComponent` publishes the deck level, bridge kind, end flag, and piece identifier

### Requirement: Deck surface resolves without overwriting underlying land
`TerrainSystem.get_land_type(cell, level)` SHALL return the deck land type for a cell covered by an intact bridge at `level`, resolved as a live overlay in the same manner the existing `"resource"` type is derived. The underlying ground land type of the cell SHALL remain unchanged, and when the covering bridge piece is removed or destroyed the deck surface SHALL be removed and the cell SHALL revert to ground behavior.

#### Scenario: Bridge cell reports bridge at its level
- **WHEN** a bridge covers a water cell at level `L`
- **THEN** `get_land_type(cell, L)` returns the deck land type

#### Scenario: Water beneath is preserved
- **WHEN** a bridge covering a water cell is removed
- **THEN** `get_land_type(cell, 0)` returns `"water"`

#### Scenario: Painted overlay untouched
- **WHEN** a bridge covers a cell and the bridge is removed
- **THEN** any painted land-type override on that cell is unchanged

### Requirement: Deck surface passability is road with the terrain figure skipped
A bridge deck surface SHALL be passable and costed as the locomotor's Road row, with the destination land type's terrain figure skipped entirely for the deck. A ground locomotor SHALL cross a bridge span over water where it cannot cross the uncovered water, including a tracked unit whose underlying water speed is zero. A water-only locomotor SHALL NOT treat a deck as passable.

#### Scenario: Wheeled crosses a bridge over water
- **WHEN** a wheeled unit pathfinds from one shore to the other across a bridge span over water
- **THEN** the path crosses the deck cells and not the uncovered water

#### Scenario: Deck skips the underlying terrain figure
- **WHEN** a tracked unit whose water speed is zero crosses a deck over water
- **THEN** the deck is passable at the road cost

#### Scenario: Removal blocks the crossing
- **WHEN** the deck cells between a wheeled unit and the far shore are removed
- **THEN** the unit no longer paths across the former deck cells over water

#### Scenario: Ship does not use the deck
- **WHEN** a ship pathfinds across a body of water spanned by a bridge
- **THEN** the deck is not treated as passable to the ship

### Requirement: Walkable deck surface height
The system SHALL expose the per-level walkable surface height. `TerrainSystem.get_cell_surface_height(cell, level)` SHALL return the deck surface height when a deck covers the cell at `level`, otherwise the ground surface height at level 0. A low bridge deck SHALL sit approximately half a height step above its cell's ground; a high bridge deck SHALL sit approximately four height steps above its cell's ground, authored as the bridge's deck grade/rise. Movement SHALL position entities at the walkable surface height of their level, and pathing SHALL evaluate climb tolerance and height cost against it.

#### Scenario: Low bridge deck is a half step up
- **WHEN** a low bridge covers a flat water cell
- **THEN** its surface height is approximately half a height step above the ground surface

#### Scenario: High bridge deck is four steps up
- **WHEN** a high bridge with the default rise covers a flat cell
- **THEN** its surface height is approximately four height steps above the ground surface

#### Scenario: Unit Y follows the deck
- **WHEN** a unit moves onto a high bridge deck cell
- **THEN** its Y position is set to the deck surface height, not the ground height beneath

#### Scenario: Ground unit Y beneath the deck
- **WHEN** a unit moves under a high deck on the ground level
- **THEN** its Y position is set to the ground surface height

### Requirement: Low bridge
A low bridge SHALL be an overlay placed at a small height step above the ground (approximately half a height step), with thickness rendered upward. A low bridge SHALL include slope end pieces that ramp ground traffic on and off the deck, and normal span pieces. Normal span pieces SHALL be destructible and end pieces SHALL be indestructible. A low bridge SHALL NOT require a spanned four-level step; ground traffic transitions on and off via the slope ends.

#### Scenario: Low bridge deck is a small step
- **WHEN** a low bridge is placed over flat ground
- **THEN** its deck sits approximately half a height step above the ground

#### Scenario: Slope ends admit ground traffic
- **WHEN** a ground unit reaches a low bridge at a slope end piece
- **THEN** it transitions onto the deck and crosses the span

#### Scenario: Normal piece destructible, end indestructible
- **WHEN** a low bridge piece is authored
- **THEN** a normal span piece is a destruction target and an end piece is excluded from destruction

### Requirement: High bridge
A high bridge SHALL be a deck approximately four height steps above the ground, with thickness rendered downward, built on one authored flat span grade. The deck SHALL be reached and left only across a spanned transition (a cliff or road-cut end at the matching grade). All cells of a high bridge SHALL be indestructible. A high bridge SHALL own cliff / road-cut terrain ends (see the bridge-end requirement) rather than slope pieces.

#### Scenario: High bridge deck is four steps up
- **WHEN** a high bridge is placed over flat ground
- **THEN** its deck sits approximately four height steps above the ground

#### Scenario: All high bridge cells indestructible
- **WHEN** a high bridge span is authored
- **THEN** no cell of it is a destruction target

#### Scenario: Entry only at a matching-grade end
- **WHEN** a ground unit at the deck grade reaches a high bridge end
- **THEN** it can enter the deck, and it cannot climb onto the deck from the surrounding ground grade

#### Scenario: Flat authored span grade
- **WHEN** a high bridge span is authored
- **THEN** the deck uses one flat authored grade for the whole span

### Requirement: Rail bridges are high bridges only
A rail bridge SHALL exist only as a high bridge variant. A rail bridge SHALL NOT be authored or placed as a low bridge. The bridge kind SHALL distinguish road from rail, and rail-specific movement restrictions SHALL be applied by the movement system.

#### Scenario: Rail kind is high only
- **WHEN** a bridge is authored with the rail kind
- **THEN** it uses the high bridge geometry and four-step deck

#### Scenario: Low rail bridge refused
- **WHEN** a bridge is authored as low with the rail kind
- **THEN** it is rejected or normalized to the road low bridge

### Requirement: Extra-high stacked decks
A bridge SHALL support more than one deck level stacked over the same XZ at different world heights, bounded by `TerrainSystem.MAX_HEIGHT`. Each deck level SHALL form an independent surface and place-set, and each SHALL participate in the height transition rules. A deck SHALL NOT be stacked at a level equal to or above `MAX_HEIGHT`.

#### Scenario: Two stacked decks over one span
- **WHEN** two bridge decks are authored over the same cells at different levels
- **THEN** the cells expose both deck surfaces at their own world Y

#### Scenario: Traffic on each level
- **WHEN** one unit is on the upper deck and another on the lower deck of the same XZ
- **THEN** both move on their own level's surface and places

#### Scenario: Stack bounded
- **WHEN** a deck is requested at or above `MAX_HEIGHT`
- **THEN** it is not created

### Requirement: Bridge ends are terrain objects with a road cut
A high bridge's end SHALL be a `TerrainObject` of `cell_type = "cliff"` carrying a road cut through its covered cells, with per-cell `land` and `corners` data. The road cut SHALL span three cells, giving ground traffic a road-grade path onto the deck, and the cliff cells SHALL lock the end geometry. A rail bridge's end SHALL carry a rail road cut equivalently. A low bridge SHALL use slope end pieces instead of a terrain-object end.

#### Scenario: High bridge end is a cliff road cut
- **WHEN** a high bridge end is authored
- **THEN** its `TerrainObject` is a cliff whose cut spans three road cells

#### Scenario: Road cut admits traffic
- **WHEN** a ground unit follows the road cut to a high bridge end
- **THEN** it transitions onto the deck at the deck grade

#### Scenario: Low bridge uses slope ends
- **WHEN** a low bridge is authored
- **THEN** its ends are slope pieces, not terrain-object cliff ends

### Requirement: Bridge-end stamping and cell-pin persistence
A runtime stamp-to-grid consumer SHALL apply a bridge-end `TerrainObject`'s per-cell `land` and `corners` to the terrain grid at its placement and pin the affected cells using the existing `cell_pins` overlay. The pinned cells SHALL reject later height edits, and the road-cut geometry SHALL remain fixed. Persistence SHALL use the existing `cell_pins` map JSON and SHALL NOT introduce a new JSON section. A map without the `cell_pins` key SHALL load with no stamped ends.

#### Scenario: Stamping applies land and corners
- **WHEN** a bridge-end `TerrainObject` is stamped at a placement
- **THEN** each of its cells receives the object's `land` and `corners` on the grid

#### Scenario: Stamped cells are pinned
- **WHEN** a bridge-end object is stamped
- **THEN** its cells are pinned so later height edits do not deform the cut

#### Scenario: Ends round-trip through cell_pins
- **WHEN** a map with a stamped bridge end is exported and re-imported
- **THEN** the pin entries restore the end cells and their geometry

#### Scenario: Absent key loads clean
- **WHEN** a map with no `cell_pins` key is imported
- **THEN** no cells are pinned or stamped

### Requirement: Bridge entity persistence via the entities array
Bridge entities SHALL persist through the map `entities` array with one entry per covered cell, carrying each cell's bridge kind, level, end flag, and shared piece identifier, and SHALL round-trip on load such that deck surfaces resolve again. A map without bridge entities SHALL load with no deck surfaces.

#### Scenario: Span round-trips
- **WHEN** a map containing a bridge span is exported and re-imported
- **THEN** each covered cell resolves as a deck at its level again

#### Scenario: Stacked decks round-trip
- **WHEN** a map containing stacked decks is exported and re-imported
- **THEN** each deck level resolves at its own height again

#### Scenario: Absent bridges load clean
- **WHEN** a map with no bridge entities is imported
- **THEN** no cell exposes a deck surface

### Requirement: Bridge piece destructibility split
A bridge piece SHALL expose whether it is an end or a normal span cell. End pieces SHALL be indestructible. Normal pieces of a low bridge SHALL be destructible; all cells of a high bridge SHALL be indestructible. Destroying a normal piece SHALL revert the deck surface it contributed and remove it from the bridge registry. Actual destruction gameplay, bridge strength, and the repair hut are out of scope for this change (#250).

#### Scenario: End piece flagged indestructible
- **WHEN** a bridge piece is authored as an end
- **THEN** it is excluded from destruction

#### Scenario: High bridge cell indestructible
- **WHEN** any cell of a high bridge is authored
- **THEN** it is not a destruction target

#### Scenario: Destroyed low piece reverts its deck
- **WHEN** a normal low bridge piece is destroyed
- **THEN** its deck surface is removed and the cell returns to ground behavior
