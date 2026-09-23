# Tasks

## 1. Tooling — bridge tile footprints

- [x] 1.1 Add bridge parsing to `tools/isotem/`: read `ovrps*` (road) / `tovrps*` (rail) via the existing `tem.py`; key tiles by the `temperat.ini` role map (`BridgeTopLeft1/BottomRight/TopRight/BottomLeft/BridgeMiddle1/2`, `TrainBridgeSet` for rail).
- [x] 1.2 Extend the land map with the original ids: `6 → railroad`, `11/12 → road`, `14 → clear` (keep `15 → rock`).
- [x] 1.3 Add a minimal header reader (`0, W, H, frameCount`) that reports the three-lane atlas dimensions/frame counts for `bridge/railbrdg/lobrdg*` (no pixel import).
- [x] 1.4 Add a self-check asserting a known bridge footprint (e.g. `tovrps01` middle lane `railroad`, outer lanes `road`; deck at height 4).

## 2. Generated bridge-end terrain objects

- [x] 2.1 Derive a directional road bridge-end footprint from `ovrps` (three-wide road cut at grade 4, `rock@4` banks, `rock@0` base) and generate `cliff_bridge_end_{n,e,s,w}` into `games/ts/terrain_objects/`.
- [x] 2.2 Derive the rail equivalent from `tovrps` (middle cut cell `railroad`, outer cut cells `road`) and generate `cliff_rail_bridge_end_{n,e,s,w}`.
- [x] 2.3 Art: end caps alias the placeholder GLB `ovrps01` (clear lower) / `ovrps02` (water lower); add the clear/water art ids and the stamp-time pick; rotate per direction.
- [x] 2.4 Data-integrity test: each end object has non-empty cells, 4-element corners, valid crease, registered land ids, resolvable art; the road cut is exactly three cells; the rail middle cut cell is railroad.

## 3. Retire the synthetic bridge land type

- [x] 3.1 Delete `games/ts/land_types/bridge.tres` and its `global_rules.tres` registration.
- [x] 3.2 Remove `TerrainSystem.BRIDGE_LAND_TYPE` and the level>0 `"bridge"` return; the deck surface returns its resolved land.
- [x] 3.3 Remove the `"bridge"` terrain-speed rows from `Foot`, `Track`, `Wheel`, `Amphibious`.

## 4. Per-lane deck land and rail

- [x] 4.1 Add `EntityData.bridge_land` (default `"road"`) and publish it through `BridgeComponent` to the bridge-cell registry.
- [x] 4.2 `TerrainSystem.get_land_type(cell, level>0)` returns the registry's deck land (`road`/`railroad`/`clear`).
- [x] 4.3 `rail_bridge.tres` declares `bridge_land = "railroad"`; road/low/high and rail outer lanes stay `road`.
- [x] 4.4 `Pathfinder`/`MovementController` cost and pass the deck from its resolved land row (Road, or Railroad for a rail middle lane) with the terrain figure skipped.

## 5. Overlay data cleanup

- [x] 5.1 Set explicit `bridge_level`/`bridge_rise` on `bridge_high.tres`/`bridge_high_end.tres` (four-step rise); keep low at half a step.
- [x] 5.2 Confirm the rail piece layout in data: three lanes, middle `railroad`, outer `road`.

## 6. Specs, glossary, tests

- [x] 6.1 Record TS bridge land/lane facts and the three-lane piece in `GLOSSARY.md` (bridge deck lane, rail lane, road cut) if not already covered.
- [x] 6.2 Tests: deck land resolution (road vs railroad), deck cost from the resolved row, end-cap three-wide cut, rail middle lane, no `"bridge"` land type remains.
- [x] 6.3 Full suite green; `gdlint`/`gdformat` clean; `openspec validate bridge-ts-fidelity --strict`.
