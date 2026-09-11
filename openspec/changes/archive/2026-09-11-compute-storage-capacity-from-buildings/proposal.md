## Why

`EntityData.storage_capacity` is authored in refinery data but read by nothing; `EconomyManager.get_storage_capacity` returns a flat hardcoded `2000` with a `ponytail:` comment admitting the shortcut. Storage capacity should be a property of what the player has built, not a constant — so adding or losing a storage building changes the cap, which is the whole point of silo summation.

## What Changes

- `EconomyManager.get_storage_capacity(player_id, category)` SHALL compute capacity as the sum of `EntityData.storage_capacity[category]` across the player's owned buildings (count × per-building share), instead of returning a flat constant.
- Capacity source is the existing `PrerequisiteSystem` owned-building registry (`get_player_buildings(player_id)`), which already tracks place/sell/destroy/deploy/undeploy registration. No new registry or signal wiring.
- No owned buildings → capacity 0 for every category. Unknown category → 0. A refinery still contributes its declared `2000` for `"tiberium"`.
- `get_storage_capacity(player_id, category)` signature is unchanged. `SelectComponent` and its storage bar need no call-site change.
- **Out of scope (blocked on #395):** reading `GlobalRules.currency_category` instead of the `"tiberium"` literal. The `DEFAULT_CATEGORY` default stays for now; the literal migration across `EconomyManager`, `SelectComponent`, `BuildingManager`, and `DebugMenu` belongs to #395.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `resource-storage`: the "Per-category storage capacity" requirement changes from a flat `2000` for `"tiberium"` to a per-player summation over owned buildings' declared `storage_capacity`; empty base → 0.
- `economy-core`: the "Storage capacity query" scenario changes from "returns 2000" to "returns the sum declared by the player's owned buildings".

## Impact

- `scripts/economy/EconomyManager.gd` — `get_storage_capacity` implementation; remove `TIBERIUM_CAPACITY`.
- `scripts/production/PrerequisiteSystem.gd` — existing `get_player_buildings(player_id)` consumed read-only.
- `scripts/entities/EntityFactory.gd` — existing `get_entity_data(entity_id)` consumed to read `storage_capacity`.
- `test/unit/test_economy_manager.gd` — `test_storage_capacity_category` rewritten to register synthetic buildings and assert summation/per-category.
- `openspec/specs/resource-storage/spec.md`, `openspec/specs/economy-core/spec.md` — delta updates.
- Edge cases surfaced, not fixed here: `BuildingManager._on_building_placed` registers under `PlayerManager.get_local_player_id()` (not the actual owner), and map-preloaded buildings created directly via `EntityFactory.create_entity` never register with `PrerequisiteSystem`. Both mean non-local/preplaced buildings read 0 capacity; documented as known ceilings.
