## Context

The dock pipeline has three layers, none of which know about ownership:

1. **Order path**: `HarvestComponent.get_order_for_target()` returns an ENTER order for any entity with a `DockHostComponent` (HarvestComponent.gd:347-363).
2. **Seek path**: `DockClientComponent.find_nearest_host()` scans the `entities` group and ranks candidates by cell distance plus occupancy penalty, filtering only on `can_dock_with` entity ids (DockClientComponent.gd:266-289).
3. **Bind point**: `DockHostComponent.request_dock()` accepts any node — first come, first served (DockHostComponent.gd:122-138).

Additionally, `DockUnloadComponent._process()` credits the *docker's* owner: it reads `StatsComponent.player_id` off the docker's parent entity, falling back to `PlayerManager.get_local_player_id()` (DockUnloadComponent.gd:81-88). So an enemy harvester unloading at your refinery pays the enemy.

Ownership source of truth is `StatsComponent.player_id` on the root entity node; `< 0` means unset (existing convention — see `test_is_enemy_false_for_negative_player_id`).

## Goals / Non-Goals

**Goals:**

- Owner-only docking: a dock host only accepts dockers with the same valid owner.
- Auto-delivery never routes to foreign or ownerless docks.
- Explicit ENTER orders only target same-owner docks.
- Full harvester idles near the field (retry cooldown) when no friendly refinery exists.
- Unload credits go to the refinery's owner.

**Non-Goals:**

- Allied/team dock sharing.
- Building capture or ownership change mid-game.
- Cursor/UI feedback when hovering an enemy refinery with a harvester selected.
- Changes to dock queueing, stale eviction, wait cells, or unload timing.

## Decisions

### D1: Gate at the host (`request_dock`), not just callers
`request_dock()` compares the docker entity's `StatsComponent.player_id` against its own parent building's and returns `false` on mismatch or unset id (`< 0`) on either side. This is the trust boundary: 24 call sites already route through it, so one guard closes every current and future path. Client-side filtering (D2/D3) exists for *behavior quality* (don't walk there in the first place), not correctness — if either is ever bypassed, the host still refuses.

*Alternative considered*: gate only in `find_nearest_host` + order targeter. Rejected — leaves every future dock caller (transports, aircraft pads) responsible for remembering the rule.

### D2: Owner comparison helper, not PlayerManager lookups
Ownership comes exclusively from each entity's own `StatsComponent.player_id`. The comparison is plain equality between two valid ids (`>= 0`). No team/alliance logic — owner-only per project decision. A small shared helper (e.g., static on DockHostComponent or a util function) avoids duplicating the get-node-guard-cast dance in four places across three scripts. Existing component patterns (HealthComponent, SelectComponent) already read sibling components via `get_node_or_null("StatsComponent")`; we follow that instead of inventing a new lookup mechanism.

### D3: `find_nearest_host` skips foreign/ownerless hosts
Added alongside the existing `can_dock_with` filter inside the group scan. If the client entity itself has no valid owner id, no host matches (ownerless clients don't auto-dock). Consequence: with zero friendly refineries in range, `find_nearest_host` returns null → `seek_dock` emits `dock_slot_failed` → `HarvestComponent._on_dock_slot_failed` schedules its existing retry cooldown. That idle-with-retry loop is the desired "strand safely" behavior; it needs a regression test, not new code (verify, don't assume).

### D4: Order targeter falls through by returning null
`get_order_for_target` returns null (instead of ENTER) for foreign-owned dock hosts so downstream order generators can resolve attack/move as usual. If the fall-through proves disruptive to cursor resolution in practice, scope this decision down: returning null is correct; forcing an attack cursor here is out of scope.

### D5: Credits attributed to the host building
In `DockUnloadComponent._process`, take the owner from the unload component's parent (the refinery) `StatsComponent.player_id`. Remove the local-player fallback: an ownerless building grants nothing rather than crediting the local player. The docker's stats stop being consulted entirely.

### D6: Test fixtures gain explicit owners
Bare fixture hosts/clients in `test_dock_client_component`, `test_dock_host_component`, `test_harvest_dock`, `test_dock_queue_step` currently carry no `StatsComponent`. Under D1 they would all fail. Fixtures get a minimal helper that attaches a `StatsComponent` with a chosen player id; default fixtures use matching owners so existing scenarios keep their meaning, and new tests exercise mismatched owners explicitly.

## Risks / Trade-offs

- [Fixture churn across 4 test files] → One shared helper pattern, applied mechanically; default-to-matching-owner keeps diffs small.
- [Ownerless map props with docks become unusable] → Intentional: neutral docks shouldn't pay anyone. If a future mission needs a neutral refuel point, that's a new requirement (allied/neutral docking policy).
- [Retry loop could spin hot if `_on_dock_slot_failed` retries every frame] → Verify cooldown behavior in tests; the existing retry-cooldown mechanism was built for occupied docks and should apply unchanged.
- [`request_dock` returning false mid-sequence changes client state expectations] → `seek_dock` already handles bind failure by queuing; queued clients whose bind later fails need the rejection surfaced through the same failure paths tested today.

## Migration Plan

Single PR on `fix/309-harvester-docks-at-enemy-dock-host`. No data, scene, or save migration. Rollback = revert commit; behavior returns to pre-fix state harmlessly.

## Open Questions

- None blocking. Allied sharing revisited if alliance mechanics land.
