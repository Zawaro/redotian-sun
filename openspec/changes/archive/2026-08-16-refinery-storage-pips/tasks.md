## 1. Storage wallet data model

- [x] 1.1 `PlayerData.gd`: replace the `credits` field with `stored_by_category: Dictionary[String, int]` (single source of truth) plus a `credits` get/set property that reads/writes the `"tiberium"` category; keep `credits` readable/writable so existing call sites compile unchanged
- [x] 1.2 `ResourceType.gd`: add `display_in_hud: bool = true` export to the Resource Type group
- [x] 1.3 `EntityData.gd`: add `storage_capacity: Dictionary[String, int]` export to the Building Capabilities group
- [x] 1.4 `EconomyManager.gd`: make `add`/`deduct` category-aware with a `"tiberium"` default (signature `add(player_id, amount, reason, category := "tiberium")`, same for `deduct`), mutating `stored_by_category` and carrying the category on `credits_changed`
- [x] 1.5 `EconomyManager.gd`: make `can_afford`/`get_balance` read the displayable sum (categories whose resource type has `display_in_hud = true`), resolved via `EntityFactory.get_global_rules().get_resource_type(category)`; unknown categories default to displayable
- [x] 1.6 `EconomyManager.gd`: make `get_storage_capacity(player_id, category)` category-aware — returns 2000 for `"tiberium"`, 0 otherwise
- [x] 1.7 `PlayerManager.gd`: confirm player init writes starting credits through the `credits` accessor (tiberium category) with no behavior change

## 2. Refinery and resource data

- [x] 2.1 `gdi_refinery.tres`: set `refinery = true` and `storage_capacity = {"tiberium": 2000}`
- [x] 2.2 `nod_refinery.tres`: set `refinery = true` and `storage_capacity = {"tiberium": 2000}`
- [x] 2.3 `resources/resource_types/vein.tres`: set `display_in_hud = false`

## 3. Refinery storage pips rendering

- [x] 3.1 `SelectComponent.gd`: extract the structure health-bar build (BoxMesh fill + ImmediateMesh grid) into a shared `_build_segmented_bar(...)` helper (parameterized by span axis X/Z, span/cross/y bounds, ratio, color); rebuild the health bar through it with identical geometry
- [x] 3.2 `SelectComponent.gd`: build the refinery storage bar via the shared helper — full-width bar along the x-axis at the building's base (`min_y` edge), centered in z, tiberium green, fill = `EconomyManager.get_balance(owner) / get_storage_capacity(owner)`; built at `_ready` only when `EntityFactory.get_entity_data(stats.id).refinery` and owner `player_id >= 0`, guarded by `not Engine.is_editor_hint()`; `update_storage_bar()` rescales the fill and `credits_changed` (tiberium, own player) refreshes it; hidden/shown via the generic visibility loop (select or hover)
- [x] 3.3 Verify the bar draws only on selected/hovered refineries, updates on balance change, and never appears on non-refinery structures

## 4. Tests

- [x] 4.1 `test/unit/test_economy_manager.gd`: add coverage for category-aware `add`/`deduct` (tiberium default, hidden `"weed"` category), `get_balance` excluding hidden groups, `get_balance(player_id, category)` direct read, and `get_storage_capacity` (2000 tiberium / 0 unknown)
- [x] 4.2 `test/unit/test_select_component.gd`: a structure refinery builds a `StorageBar` whose `scale.x` = full width × (balance/capacity), updates after `EconomyManager.add(..., "harvest")` via `credits_changed`, shows on select or hover, and a non-refinery structure builds none; reverted the wrong-path `test_selection_overlay.gd` storage tests and `SelectionOverlay` storage drawing
- [x] 4.3 `test/unit/test_player_data.gd` (or existing player-data coverage): assert `stored_by_category` holds the tiberium amount set via `credits = 1000`, and that a weed balance coexists without changing the `credits` read

## 5. Verification

- [x] 5.1 Run the full suite: `redot --headless -s test/run_tests.gd` — all green
- [x] 5.2 Run lint + format: `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`, then grep for tab introduction

## 6. Stored vs free credits

- [x] 6.1 `PlayerData.gd`: add `free_credits: int = 0`; remove the legacy `credits` accessor; `stored_by_category` stays the storage (bar numerator)
- [x] 6.2 `PlayerManager.gd`: starting credits write into `free_credits`, not storage
- [x] 6.3 `EconomyManager.gd`: `add(..., is_free := false)` — default routes to stored (harvest + production-cancel refunds), `is_free := true` routes to free credits; `deduct` spends stored first then free; `get_balance(player_id)` = free + displayable stored, `get_balance(player_id, category)` = stored only
- [x] 6.4 Call sites: `DebugMenu` add-credits and `BuildingManager.sell_building` refund pass `is_free = true`; harvest deposit and production-cancel refunds stay stored (default)
- [x] 6.5 `SelectComponent.update_storage_bar`: read `get_balance(owner_id, "tiberium")` (stored only) so free credits never fill the bar
- [x] 6.6 Tests: economy free/stored routing + stored-first deduct; `test_select_component` free-credits-don't-fill-bar; `test_player_data` free_credits field
