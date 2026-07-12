## Why

The economy loop (refinery → harvester → tiberium → credits) was scaffolded in #45 but lacks: map editor tools to paint Tiberium for testing, FreeUnitComponent for refinery free harvester spawn, placeholder art for Tiberium pods and Tiberium trees, and Tiberium self-destruct on depletion. Without these, the economy loop can't be interactively tested or validated.

## What Changes

- Restructure MapEditor UI from vertical list to top toolbar row with toggleable tools
- Add Paint Tiberium, Place Tiberium Tree, Erase tools with strength slider and radius spinbox
- Place Tree tool replaces existing entity on occupied cell
- All entities placed at center of 2×2 cells
- Add editor entity tracking (`_painted_entities` dict) and JSON v3 persistence (`"entities"` array)
- Create `MapLoader.gd` to restore entities from saved JSON
- Create `FreeUnitComponent`: reusable one-shot component that spawns a free unit (e.g., harvester) when parent is placed, then self-destructs
- Add `placeholder_size` field to ArtData for non-foundation-shaped placeholders (Tiberium Tree thin pole)
- Rewrite `TiberiumComponent` visuals: cell-seeded 3-stage cube clusters; self-destruct on depletion via `queue_free()`
- No HarvestComponent changes needed (standard MovementController pathfinding)
- Add `_preview` meta guard to BuildingManager ghost entities to prevent FreeUnitComponent firing on previews
- Configure gdi_refinery.tres with `factory` and `free_unit` fields
- Create `TiberiumGrowthSystem` autoload: two independent timers (tree + crystal), batched entity processing, distance/spread limits to prevent cascading
- MapEditor guarded to never trigger growth (`Engine.is_editor_hint()` early return)
- TiberiumTreeComponent: add `configure()` method, remove `_spawn_crystals` (map editor pre-populates)
- TiberiumComponent: add `spread_count` tracking field
- GlobalRules: add 7 new growth-related fields (tree_growth_rate, growth_batch_trees, growth_batch_crystals, spread_amount, spread_distance_buffer, spread_max, full_growth_speed_bonus)

## Capabilities

### New Capabilities
- `map-editor-tiberium`: Map editor toolbar, paint tiberium, erase, place tree, entity tracking
- `map-loader`: JSON v3 persistence with entities array, load/save flow
- `free-unit`: FreeUnitComponent — self-spawning, self-destructing free unit on building placement
- `tiberium-art-placeholder`: Cell-seeded 3-stage cube cluster visuals, Tiberium pod self-destruct on depletion
- `tiberium-growth-system`: TiberiumGrowthSystem autoload — tree timer, crystal timer, batched processing, spread limits

### Modified Capabilities
<!-- None — no existing spec requirements are changing -->

## Impact

- `scripts/editor/MapEditor.gd` — major UI restructure + new tools + entity tracking
- `scripts/maps/MapLoader.gd` — new file
- `scripts/components/FreeUnitComponent.gd` — new file
- `scripts/components/TiberiumComponent.gd` — visual rewrite + self-destruct + spread_count field
- `scripts/components/TiberiumTreeComponent.gd` — add configure(), remove _spawn_crystals
- `scripts/components/ArtComponent.gd` — placeholder_size support
- `scripts/data/ArtData.gd` — placeholder_size field
- `scripts/data/GlobalRules.gd` — 7 new growth-related fields
- `scripts/buildings/BuildingManager.gd` — ghost preview meta flag
- `scripts/entities/EntityFactory.gd` — FreeUnitComponent wiring
- `scripts/core/TerrainSystem.gd` — JSON version bump
- `scripts/core/TiberiumGrowthSystem.gd` — new file (autoload)
- `project.godot` — register TiberiumGrowthSystem autoload
- `resources/global_rules.tres` — new growth field values
- `resources/entities/structures/gdi/gdi_refinery.tres` — factory/free_unit fields
- `resources/entities/terrain/tiberium_tree.tres` — verify spawned_entity_id, radius_cells, node_count
