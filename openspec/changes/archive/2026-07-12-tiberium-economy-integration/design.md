## Context

The economy system has TiberiumTreeComponent, TiberiumComponent, HarvestComponent, DockComponent, and EconomyManager implemented but untestable interactively — no map editor tools to paint Tiberium, no free harvester spawn on refinery placement, no placeholder art for Tiberium pods, and no Tiberium self-destruct on depletion. Map persistence only covers terrain (height), not placed entities.

## Goals / Non-Goals

**Goals:**
- Map editor toolbar with paint/erase Tiberium and place Tiberium Tree tools
- Entity persistence in JSON v3 (`"entities"` array) through MapLoader
- FreeUnitComponent for refinery auto-spawning harvester on placement
- Cell-seeded 3-stage placeholder cubes for Tiberium pods
- Thin pole placeholder for Tiberium Trees via ArtData.placeholder_size
- Tiberium pod self-destructs on depletion

**Non-Goals:**
- No real 3D model art for Tiberium (placeholder cubes only)
- No blue Tiberium (type 1) tooling in editor
- No multi-player economy
- No production queue deduction (still uses stub in BuildingManager)

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Harvester positioning | Standard MovementController pathfinding | Pod's TiberiumComponent blocks building while alive; no special snap needed |
| Pod depletion | Self-destruct in collect() | Deferred queue_free is same-frame-safe; harvest loop releases pod ref immediately |
| Editor entity tracking | Editor-local `_painted_entities` dict | O(1), no coupling to SpatialHash, directly maps to save/load |
| Free unit spawn | Reusable self-destructing component | Decoupled from BuildingManager; works for any future building with free_unit |
| Pod art | In TiberiumComponent, not ArtComponent | ArtComponent lacks multi-stage support; defer until real .glb models |
| Tiberium Tree art | placeholder_size field on ArtData | Single field, no asset pipeline, no custom scene needed |
| Editor tree placement | Replaces existing entity on occupied cell | Clean UX — no manual pre-erase step needed |
| Overlay concept | TERRAIN entity with pseudo-foundation | Reuses EntityFactory + FoundationComponent patterns |

## Risks / Trade-offs

- [Editor ghost entity overhead] → Ghost preview created via EntityFactory once per build-mode entry. `_preview` meta flag prevents FreeUnitComponent firing.
- [JSON v3 backward compat] → Old v2 maps without "entities" key load fine (empty array). No migration needed.
