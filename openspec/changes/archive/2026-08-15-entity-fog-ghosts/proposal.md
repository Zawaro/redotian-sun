## Why

Entities in explored-but-not-visible (fog) cells must show a frozen "last-known" visual so the player sees where things were last, and keep that visual even after the entity is destroyed in fog. Today only MultiMesh units freeze (`_FOG_GHOST`); buildings and killable overlays leak live state (harvest shrink, doors, damage, live fallback-unit positions) or vanish, and a building/tiberium destroyed in fog disappears with no ghost.

## What Changes

- Generalize fog "freeze" to every rendered entity type: buildings, node-tree fallback units, and killable overlays (Tiberium harvest-stage visuals, trees, rubble), not just MultiMesh units.
- Introduce post-destruction fog ghosts: an entity destroyed while its cell is in fog keeps a static last-known visual at its last spot until the cell is revealed or reverts to shroud.
- Add a `GhostDepot` scene node that owns ghost visuals (reparented model subtrees and tombstone MultiMesh slots), with a single release contract: reveal, shroud-revert (growth/cover), fog toggle-off, grid reinit, and map teardown.
- Derive ghost truth from the ShroudSystem grid (cell state + entity alive + enemy gate) via a reconciling sweep, making ghost leaks structurally impossible and keeping freeze visual-only (simulation and combat keep running).
- Fix the node-tree fallback leak: a unit rendered through its GLB tree when a region bucket is full now freezes/hides per fog state instead of showing live through fog.

Out of scope: the opaque-shroud x-ray/shader workaround (lifted sheet offset + material config) is the true fix for shroud edge artifacts and is tracked separately (#276). This change touches only fog (explored-but-hidden) behavior.

## Capabilities

### New Capabilities

_None — this extends existing fog capabilities rather than introducing a new spec surface._

### Modified Capabilities

- `fog-rendering`: replace the OPEN GAP note on "Fog-driven culling for all entity types" with concrete requirements — freeze all entity types (including killable overlays and fallback-rendered units) in fog, post-destruction ghosts released on reveal/shroud-revert/toggle-off, per-player enemy gating, and the release contract.
- `unit-multimesh-rendering`: add a requirement for post-destruction tombstone slots — a frozen ghost instance may outlive its entity's registration (released on reveal), extending the existing per-instance fog freeze.

## Impact

- `scripts/core/FogRenderer.gd` — building culling moves onto the shared reconcile/ghost path; keeps only shader plane management.
- `scripts/core/UnitMeshRenderer.gd` — hosts the reconciling sweep and GhostDepot wiring; tombstone slots for multimesh units; fallback path fog-corrected.
- `scripts/core/ShroudSystem.gd` — no functional change (query-only consumers); reconcile reads `get_cell_effective_state`/`is_entity_revealed_to_local`.
- `scripts/components/ArtComponent.gd` — async-loaded models parent into the depot when the entity is already fogged.
- Death paths (`EntityFactory._on_entity_death`, `BuildingManager._on_building_destroyed`) — capture ghost visuals pre-free.
- Overlay visuals (`scripts/components/ResourceComponent.gd` tiberium stages; `scripts/core/TerrainRenderer.gd` trees) — freeze and tombstone wiring.
- No scene/.tscn breaks: GhostDepot is added at runtime by UnitMeshRenderer (no packed-scene changes).
