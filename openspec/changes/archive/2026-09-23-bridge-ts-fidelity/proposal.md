# Bridge TS data fidelity

## Why

The walkable-bridge model landed, but its data layer diverges from Tiberian Sun
and carries placeholder/hallucinated pieces: a synthetic `bridge` land type,
flat end tiles with a one-wide cut, no rail lane, and art aliases that do not
match the available placeholder meshes.

Tiberian Sun bridge cells use ordinary land types. A deck lane is `road`; a rail
bridge's middle lane is `railroad` and its outer lanes are `road`; banks and base
are `rock`. A bridge piece is three lanes wide by one long, placed per cell. High
bridge end caps are composites with a three-wide road cut through rock banks, and
the rail end carries a railroad middle lane. (Sources: `ovrps*` / `tovrps*`
theater TMP footprints; `temperat.ini` `BridgeSet`/`TrainBridgeSet`; the
placeholder GLB `ovrps01` = clear-lower, `ovrps02` = water-lower.)

## What Changes

- **Land types**: retire the synthetic `bridge` land type — its
  `games/ts/land_types/bridge.tres`, its `global_rules` registration, the
  `TerrainSystem.BRIDGE_LAND_TYPE` constant and level>0 return, and the `"bridge"`
  rows on the four ground locomotors. A deck cell resolves its real land: `road`,
  or `railroad` on a rail bridge's middle lane.
- **Rail lanes**: a rail bridge is three lanes — middle `railroad`, outer `road`.
  A road bridge is three `road` lanes.
- **End caps**: regenerate `cliff_bridge_end_{n,e,s,w}` and
  `cliff_rail_bridge_end_{n,e,s,w}` from the TS `ovrps`/`tovrps` footprints —
  three-wide cut, `rock@4` banks, `rock@0` base, rail middle lane `railroad`.
- **Pieces**: bridge pieces are three cells wide (lanes) by one long, one overlay
  entity per covered cell.
- **Art placeholders**: end caps alias the placeholder GLB's `ovrps01` (clear
  lower cell) or `ovrps02` (water lower cell), rotated per direction. No `.tem`
  art is imported.
- **Overlay data**: high/rail overlay resources declare explicit
  `bridge_level`/`bridge_rise`.
- **Tooling**: `tools/isotem/` parses `ovrps*`/`tovrps*` with the
  `temperat.ini` role map and road/railroad/clear land ids, and reports the
  three-lane atlas dimensions for the low/high/rail piece art.

## Impact

- Specs: `bridges`, `cell-surfaces`, `land-types`, `locomotor`,
  `terrain-object-catalog`, `entity-data`.
- Code/data: `TerrainSystem`, `Pathfinder`, `MovementController`,
  `BridgeComponent`/`EntityData`, `games/ts/land_types/`, `games/ts/locomotors/`,
  `games/ts/global_rules.tres`, `games/ts/terrain_objects/cliff*_bridge_end_*.tres`,
  `games/ts/art/terrain/*bridge*`, `tools/isotem/`.
