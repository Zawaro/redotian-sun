## Why

Refinery buildings give players no visual feedback for resource storage: you cannot tell how full your tiberium storage is, and harvest dumps feel silent. The economy model is also a single scalar `credits` per player plus a hardcoded capacity of 2000, which cannot represent multiple resource groups (e.g. hidden vein storage consumed only by the Tiberium Waste Facility / Chemical Missile) or future multi-resource build costs without a rewrite.

## What Changes

- Introduce a per-player, per-category storage wallet (`stored_by_category`) on `PlayerData`; `credits` becomes a computed accessor over displayable categories so all existing readers keep working (backward compatible).
- Make `EconomyManager` category-aware: `add`, `deduct`, `can_afford`, `get_balance`, and `get_storage_capacity` accept a resource category, defaulting to `"tiberium"`. `get_balance` defaults to the sum of *displayable* categories so the HUD counter is unchanged.
- Add group metadata to `ResourceType` (`display_in_hud`) so hidden groups (vein) can never surface in HUD credits or build prices.
- Add per-category `storage_capacity` to `EntityData` (capacity a storage building grants) and set `EntityData.refinery = true` on the GDI and Nod refinery data.
- Render refinery storage pips: a full-width bar along the bottom/south of the refinery, styled like the building health bar (segmented, alternating shading), showing tiberium storage fill (stored / capacity) for the building's owner.

## Capabilities

### New Capabilities

- `resource-storage`: per-player per-category resource storage, per-category capacity, group visibility rules, and the refinery storage pips visualization.

### Modified Capabilities

- `economy-core`: the ledger API becomes category-aware (balance, add/deduct, capacity) and `get_balance` sums displayable categories only.
- `player-data`: `PlayerData` carries a category-keyed storage wallet; `credits` is a computed accessor over displayable categories.

## Impact

- `scripts/data/PlayerData.gd` — category wallet + `credits` accessor.
- `scripts/data/ResourceType.gd` — `display_in_hud` group flag.
- `scripts/data/EntityData.gd` — `storage_capacity` per-category map; `refinery` flag gains a consumer.
- `scripts/economy/EconomyManager.gd` — category-aware API + storage capacity query.
- `scripts/core/PlayerManager.gd` — player init writes starting credits into the wallet.
- `scripts/components/SelectComponent.gd` — shared segmented-bar helper (health bar refactored through it) + refinery storage bar meshes.
- `resources/entities/structures/gdi/gdi_refinery.tres`, `resources/entities/structures/nod/nod_refinery.tres` — set `refinery = true`, `storage_capacity`.
- `resources/resource_types/vein.tres` — `display_in_hud = false`.
- Tests: `test/unit/test_economy_manager.gd`, `test/unit/test_selection_overlay.gd`.
- **Deferred (design seam only, not implemented here):** multi-resource installment build costs, silo buildings / live capacity summation, harvester wait-at-full-storage behavior, vein storage consumers (Tiberium Waste Facility, Chemical Missile).
