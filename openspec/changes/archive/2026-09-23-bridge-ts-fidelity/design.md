# Bridge TS data fidelity — design

## Context

The walkable-bridge change modeled a per-cell surface stack and level-aware
occupancy, using a synthetic `bridge` land type for a deck surface. Review
against the original engine (`ovrps*`/`tovrps*` theater TMP footprints, the
placeholder GLB, and `temperat.ini`) showed the data layer diverged.

## Findings (source of truth)

- `ovrps*` (`BridgeSet = 19`) and `tovrps*` (`TrainBridgeSet = 37`) are theater
  TMP files with per-cell height + land. A road deck lane is land `11` (road)
  (`14` clear on transition pieces); a rail deck is `11 6 11` — middle lane `6`
  (railroad), outer lanes `11` (road); banks and base are `15` (rock), at height
  `4` and `0` respectively. Bridge deck height is `4` lattice steps.
- `bridge.tem` / `railbrdg.tem` / `lobrdg*.tem` are overlay **art** (a
  whole-piece atlas: `0, W, H, frameCount`; three lanes wide), not terrain
  footprint. No `.tem` art is imported.
- The placeholder GLB exposes `ovrps01` and `ovrps02` (clear-lower and
  water-lower bridge art) plus `Bridge_1m_x_1m`.
- Low-bridge pieces are per-cell three-lane sections placed one by one, plus
  four end pieces; no curves or junctions.

## Decisions

**D1 — No synthetic land type.** TS has no `bridge` land type. A deck cell
resolves its real land via `TerrainSystem.get_land_type(cell, level)`: `road`
(sometimes `clear`), or `railroad` on a rail bridge's middle lane. The `bridge`
land type, its `global_rules` entry, `TerrainSystem.BRIDGE_LAND_TYPE`, and the
`"bridge"` rows on the four ground locomotors are removed. Deck terrain figures
are still skipped; the deck is costed from the land row it resolves
(`road`/`railroad`), and gravel/banks stay `rock`.

**D2 — Three lanes, per cell.** A bridge piece is three cells (lanes) wide by
one long; each covered cell is its own overlay entity. A rail bridge is
`road / railroad / road`; a road bridge is `road / road / road`. The per-cell
deck land is carried on the overlay's data and published to the registry, so a
single `get_land_type(cell, level)` answers correctly per lane.

**D3 — End caps generated from TS footprints.** `cliff_bridge_end_{n,e,s,w}` and
`cliff_rail_bridge_end_{n,e,s,w}` are generated from the `ovrps`/`tovrps` cells
(three-wide cut, `rock@4` banks, `rock@0` base; rail middle `railroad`), through
the existing isotem → TerrainObject pipeline. The hand-authored uniform plateau
is replaced. Art aliases `ovrps01` (clear lower) or `ovrps02` (water lower),
chosen when the end is stamped, rotated per direction.

**D4 — Explicit overlay data.** High and rail overlay resources declare
`bridge_level` and `bridge_rise` explicitly rather than relying on defaults
(high = 4 steps; low = 0.5 step).

**D5 — Tooling.** `tools/isotem/` gains bridge-set parsing keyed by the
`temperat.ini` role map (TopLeft/BottomRight/TopRight/BottomLeft/Middle;
TrainBridgeSet for rail) and the land ids `6`/`11`/`12`/`14`, with a
known-footprint self-check. A minimal header reader records the three-lane art
atlas dimensions; pixels are never imported.

## Supersedes

Supersedes the walkable-bridge change's synthetic `bridge` land type and the
uniform hand-authored end tiles. The surface stack, level-aware occupancy,
pathfinding, and stamping model are retained unchanged.

## Open Questions

None. Road-cut width is settled at three cells; rail lane split is settled at
`road / railroad / road`.
