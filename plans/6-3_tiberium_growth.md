# Tiberium Growth & Spawning System

## Summary

New `TiberiumGrowthSystem` autoload with two independent timers (tree + crystal), batched entity processing, and distance/spread limits to prevent cascading. MapEditor is guarded to never trigger growth.

## Design Decisions (from grill-me session)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Timer architecture | Global autoload, not per-entity | Matches original TS (`GrowthRate=5`); one place to tune rates |
| Two timers | Separate tree + crystal timers | Trees and crystals have fundamentally different spawn behaviors |
| Batching | Process N entities per frame | Prevents frame spikes with thousands of tiberium entities |
| MapEditor guard | `Engine.is_editor_hint()` early return | Editor must be completely static — no growth while painting |
| Tree upfront spawn | None — map editor pre-populates | User places initial tiberium in editor; timer handles replenishment |
| Spread distance limit | `radius_cells + buffer` from nearest tree | Natural field boundary; prevents unbounded growth |
| Spread count limit | Max 3 per crystal | Prevents exponential cascading |
| Full-growth bonus | Timer interval * 0.5 when at max amount | Tiberium grows faster when field is mature |
| All values in GlobalRules | No hardcoded magic numbers | Tunable from `global_rules.tres` |

## Timer 1: Tree Timer

| Property | GlobalRules field | Default |
|----------|-------------------|---------|
| Base interval | `tree_growth_rate` | 3.0 minutes |
| Random jitter | hardcoded | ±60 seconds |
| Full-growth bonus | `full_growth_speed_bonus` | 0.5 (50% faster) |
| Batch size | `growth_batch_trees` | 10 trees per tick |

**Behavior per tick:**
1. Iterate all entities in "entities" group that have `TiberiumTreeComponent`
2. For each tree in current batch:
   - Pick random cell within `radius_cells`
   - Query `SpatialHash.get_entries(cell)` — if cell has tiberium → grow it (increase amount toward max)
   - If cell is empty → spawn new crystal via `EntityFactory.create_entity("TIB", {overrides})`
   - Track spawned count per tree (max = `node_count`)
3. Advance batch offset

## Timer 2: Crystal Timer

| Property | GlobalRules field | Default |
|----------|-------------------|---------|
| Base interval | `growth_rate` (existing) | 5.0 minutes |
| Random jitter | hardcoded | ±60 seconds |
| Full-growth bonus | `full_growth_speed_bonus` | 0.5 (50% faster) |
| Batch size | `growth_batch_crystals` | 50 crystals per tick |
| Spread amount | `spread_amount` | 50 tiberium |
| Spread distance buffer | `spread_distance_buffer` | 4 cells beyond tree radius |
| Max spread count | `spread_max` | 3 per crystal |

**Behavior per tick:**
1. Iterate all entities with `TiberiumComponent` (excluding tree-owned ones)
2. For each crystal in current batch:
   - **Self-growth**: `amount = mini(amount + grow_amount, max_amount)`
   - **Spread attempt** (only if `spread_count < global_rules.spread_max`):
     - Pick random neighbor cell (8 directions)
     - Check distance to nearest tree: if > `tree.radius_cells + global_rules.spread_distance_buffer` → skip spread
     - Query `SpatialHash.get_entries(cell)` — if cell has tiberium → grow it
     - If cell is empty → spawn new crystal with `global_rules.spread_amount`, increment `spread_count`
3. Advance batch offset

## Cascade Prevention (3 layers)

1. **Distance limit**: Crystal only spreads if within `radius_cells + spread_distance_buffer` of a tree
2. **Spread count**: Each crystal can spread max `spread_max` times, then only self-grows
3. **Batched processing**: 50 crystals/tick prevents frame spikes; trees get 10/tick

## New GlobalRules fields

```gdscript
## Tiberium growth
@export var tree_growth_rate: float = 3.0        # minutes between tree ticks
@export var growth_batch_trees: int = 10         # trees processed per tick
@export var growth_batch_crystals: int = 50      # crystals processed per tick
@export var spread_amount: int = 50              # tiberium amount for new spread crystal
@export var spread_distance_buffer: int = 4      # extra cells beyond tree radius for spread limit
@export var spread_max: int = 3                  # max spread count per crystal
@export var full_growth_speed_bonus: float = 0.5 # timer multiplier when at max (0.5 = -50%)
```

Note: `growth_rate = 5.0` already exists and is reused for crystal timer interval.

## Files to create/modify

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `scripts/core/TiberiumGrowthSystem.gd` | **CREATE** | New autoload — two timers, batched processing |
| 2 | `project.godot` | MODIFY | Register `TiberiumGrowthSystem` autoload |
| 3 | `scripts/components/TiberiumTreeComponent.gd` | MODIFY | Add `configure()`, remove `_spawn_crystals`/`_spawn_crystal_at` |
| 4 | `scripts/components/TiberiumComponent.gd` | MODIFY | Add `spread_count: int = 0` tracking field |
| 5 | `scripts/data/GlobalRules.gd` | MODIFY | Add 7 new growth-related fields |
| 6 | `resources/global_rules.tres` | MODIFY | Set values for new fields |
| 7 | `resources/entities/terrain/tiberium_tree.tres` | MODIFY | Verify `spawned_entity_id`, `radius_cells`, `node_count` |

## MapEditor guard

In `TiberiumGrowthSystem._physics_process()`:
```gdscript
func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    # ... timer logic
```

## Testing

- Place tiberium tree + crystals in editor → save → load → start game → crystals grow over time
- Crystal at max amount → tree timer ticks faster (full-growth bonus)
- Crystal spreads to adjacent cell → new crystal has `spread_count = 1`
- Crystal spreads 3 times → stops spreading, only self-grows
- Crystal beyond `radius_cells + 4` from any tree → does not spread
- MapEditor: paint tiberium → no growth ticks while editing
- Multiple trees: each manages its own field independently
