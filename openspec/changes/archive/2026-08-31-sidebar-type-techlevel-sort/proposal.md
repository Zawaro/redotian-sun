## Why

Sidebar build menu order is driven by `EntityData.sidebar_priority` — a hand-maintained per-entity list position. Adding a new buildable entity means manually renumbering siblings to slot it in, and the field carries no meaning beyond "where someone put it". Order should derive from data entities already carry (type, tech level) so new entities slot in automatically.

## What Changes

- **Sidebar sort keys become entity type group → tech level → display name → id** in `Sidebar._compare_build_items`. The type-group rank (`Sidebar.TYPE_RANK`) mirrors `TAB_ENTITY_TYPES`, so tabs with mixed types (Vehicles = ground vehicles + aircraft) always list ground vehicles before aircraft.
- **tech_level (-1 = always available) sorts ascending** within a type group, so early-tech items appear first.
- **Remove `sidebar_priority`** from `EntityData` and all entity `.tres` resources — the sidebar was its only consumer.
- Deterministic name/id tie-breaking is unchanged (anti-flicker regression preserved).

## Capabilities

### New Capabilities
- `sidebar-build-order`: defines the canonical sort of sidebar build menu items.

### Modified Capabilities
<!-- none -->

## Impact

- `scripts/ui/Sidebar.gd` — add `TYPE_RANK`/`UNKNOWN_TYPE_RANK` consts, rewrite `_compare_build_items`.
- `scripts/data/EntityData.gd` — drop the `sidebar_priority` export.
- 73 entity `.tres` files — drop the `sidebar_priority` line (mechanical).
- `test/unit/test_sidebar_build_order.gd` — rewritten for the new key order: pure sort properties plus data-coverage checks over `resources/entities/`.
