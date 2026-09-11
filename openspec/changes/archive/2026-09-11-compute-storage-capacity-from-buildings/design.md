## Context

`EconomyManager.get_storage_capacity(player_id, category)` currently ignores `player_id` and returns a flat `TIBERIUM_CAPACITY = 2000` for the `"tiberium"` category (`scripts/economy/EconomyManager.gd:60-62`). `EntityData.storage_capacity: Dictionary` (`scripts/data/EntityData.gd:167`) is authored on both TS refineries (`{"tiberium": 2000}`) and read by nothing. The only live consumer of `get_storage_capacity` is the refinery storage bar (`SelectComponent.gd:379`), which calls it with the default category and derives a fill ratio from stored tiberium.

The stated goal is silo summation: a player's cap should be the sum of what their owned storage buildings declare. A per-player owned-building registry already exists in `PrerequisiteSystem` (`_player_buildings: {player_id: {entity_id: count}}`), maintained on place/sell/destroy/deploy/undeploy via `register_building` / `unregister_building`, with a read accessor `get_player_buildings(player_id)`. The archived `refinery-storage-pips` design explicitly deferred "live summation and place/sell/death invalidation" until a storage building existed; the registry's invalidation is now already implemented.

The issue also asks to consume `GlobalRules.currency_category` instead of the `"tiberium"` literal, but that field does not exist yet and its introduction is the subject of #395 (a broad content-sniffing refactor). That half is blocked.

## Goals / Non-Goals

**Goals:**
- `get_storage_capacity(player_id, category)` returns the per-player sum of `EntityData.storage_capacity[category]` over owned buildings.
- Keep the existing signature and the single `SelectComponent` call site unchanged.
- Reuse existing registries; add no new persistent state and no new signals.
- Cover summation, per-category, empty-base, and building-loss behavior with core tests on synthetic building data.

**Non-Goals:**
- Reading `GlobalRules.currency_category` / removing the `"tiberium"` literal (blocked on #395).
- Enforcing capacity on the stored value (harvester wait-at-full, deposit clamping) — still deferred.
- Fixing owner attribution for AI/non-local buildings or registering map-preloaded buildings.
- Introducing a dedicated economy-side building registry.

## Decisions

### D1: Sum from `PrerequisiteSystem.get_player_buildings` (reuse the existing registry)

`get_storage_capacity` iterates `PrerequisiteSystem.get_player_buildings(player_id)`, and for each `entity_id → count` reads `EntityFactory.get_entity_data(entity_id).storage_capacity.get(category, 0) * count`, summing the result. Registration and invalidation already ride the place/sell/destroy/deploy/undeploy lifecycle, so the returned capacity falls automatically when a storage building is lost. The visible storage bar re-scales through a `PrerequisiteSystem.prerequisites_changed` connection made in `SelectComponent._build_storage_bar` (registration fires after `add_child`, so this also catches the refinery's own first registration).

Alternatives rejected:
- **Scan `BuildingManager._buildings` filtering `StatsComponent.player_id`** — would give true owner attribution, but `_buildings` entries store `node`/`type`/`origin`/`cells`; scanning and reading `StatsComponent` is more code for no requirement gain, and it still misses deployed MCVs that register via `DeployComponent`.
- **New EconomyManager registry wired to `building_placed`/`building_sold`/`building_destroyed`** — duplicates the exact invalidation logic that `PrerequisiteSystem` already performs, the most state and most surface for drift.

Coupling EconomyManager → PrerequisiteSystem is a read-only accessor call; both are autoloads and `get_storage_capacity` is called at runtime (storage-bar refresh), not during `_ready()`, so autoload ordering is irrelevant.

### D2: Keep `DEFAULT_CATEGORY = "tiberium"`; defer `currency_category` to #395

The signature default and the internal literal remain until #395 introduces `GlobalRules.currency_category` and migrates all `"tiberium"` literals (`EconomyManager`, `SelectComponent:345/383/396`, `BuildingManager:513`, `DebugMenu:225`). This change only makes the returned value sum-based, so #395's literal swap composes cleanly afterward.

### D3: Compute on demand, no cache

`PrerequisiteSystem._player_buildings[player_id]` is a small dictionary keyed by distinct building ids, and the only caller runs on a `credits_changed` event, not per frame. An O(distinct building ids) sum per call is cheap; a cache would add invalidation state and a staleness window for no measured benefit. `ponytail:` note the shortcut if profiling ever disagrees.

### D4: No owned buildings → 0 capacity

The old flat 2000 existed only because summation was deferred. With capacity sourced from buildings, an empty base genuinely has no storage. This is a behavioral change acknowledged in the spec (`resource-storage` "No owned buildings means no capacity") and hidden by the storage bar's existing `capacity <= 0` guard, which already draws nothing.

### D5: PrerequisiteSystem clears its registry on a runtime game switch

`_player_buildings` holds entity ids that only resolve against the active game's content. `EntityFactory.reset_content()` clears its cache on `game_changed`, so stale ids would silently resolve to null and drop capacity to 0. `PrerequisiteSystem` therefore connects `GameContext.game_changed` and clears the registry (emitting `prerequisites_changed` for affected players so the Sidebar cameo list refreshes).

## Risks / Trade-offs

- **Owner attribution is local-player-biased** → `BuildingManager._on_building_placed` registers with `PlayerManager.get_local_player_id()`, not the placed building's owner, so `get_storage_capacity(ai_player, …)` reads 0 for AI-placed buildings. Mitigation: document the ceiling in the implementation; owner-accurate registration is a separate fix (the deploy path already uses the snapshot owner).
- **Map-preloaded buildings are not registered** → `MapLoader` creates entities directly via `EntityFactory.create_entity` and never calls `register_building`, so a preplaced refinery contributes 0. Mitigation: out of scope; note it, and registering on load is a candidate follow-up.
- **Tests must not depend on TS refinery ids** → register synthetic `EntityData` via `PrerequisiteSystem.register_building`, matching the issue's "core tests only, no TS-specific ids" constraint and the existing pattern in `test_economy_audio.gd:315-333`.

## Migration Plan

No persisted state changes; nothing to migrate. Reverting is restoring the two-line constant body of `get_storage_capacity`.

## Open Questions

- Should the AI/owner-attribution and map-preload gaps be tracked as their own issues now, or left as documented ceilings until a multiplayer/AI economy pass? (Default: document now, file follow-ups if the gaps matter for an active gameplay path.)
