## Context

The dock-host-client refactor (PR #52) landed a working but over-engineered dock system. Two issues remain:

1. **RefineryComponent** was planned in the refactor tasks but never created as a file. `EntityData.accepted_resource_categories` exists but nothing reads it at runtime. `DockUnloadComponent` has its own `unload_rate` and doesn't validate cargo categories.

2. **DockClientComponent** (349 lines) has timing/retry logic that duplicates what DockHostComponent already handles. The timeout management, queue recheck timer, and retry cooldown on the client side create fragility and code smell. OpenRA's proven architecture shows the host should own queue timing while the client stays thin.

The branch `refactor/53-55-dock-cleanup` targets issues #53 (closed — already resolved), #54 (simplify DockClientComponent), and #55 (decide fate of RefineryComponent).

## Goals / Non-Goals

**Goals:**
- Remove dead code (RefineryComponent concept, unused `accepted_resource_categories` field)
- Add `refinery: bool` classification flag to EntityData for AI targeting
- Simplify DockClientComponent to ~120 lines by moving timing logic to DockHostComponent
- Add cargo validation in DockUnloadComponent (what the refinery accepts)
- Comprehensive unit tests for dock host-client interaction

**Non-Goals:**
- Redesigning the dock system architecture (signal-driven, not activity-based)
- Adding new dock types beyond harvest/repair
- Optimizing dock cell computation or SpatialHash integration
- Refactoring HarvestComponent state machine (already clean)

## Decisions

### 1. `refinery: bool` flag replaces RefineryComponent

**Decision**: Add `refinery: bool = false` to EntityData. Wire existing `accepted_resource_categories` from EntityData through EntityFactory to DockUnloadComponent.

**Rationale**: Tiberian Sun's `Refinery=yes` is a classification flag, not a component. OpenRA uses `AcceptsDeliveredCash` tag trait — trivial, no logic. Our current composition approach (DockHostComponent + DockUnloadComponent) already handles dock behavior. The only missing piece is a classification flag for AI targeting. The `accepted_resource_categories` field already exists on EntityData — EntityFactory passes it to DockUnloadComponent at creation time. Empty array = accept all, non-empty = exclusive whitelist.

**Alternative considered**: Keep RefineryComponent as data declaration. Rejected — YAGNI, adds a component with zero runtime readers.

### 2. DockHostComponent owns stale client cleanup

**Decision**: Add `stale_timeout: float = 5.0` to DockHostComponent. If a client doesn't complete dock sequence (emit `docker_docked` callback) within N seconds, host evicts it and emits `dock_timeout`.

**Rationale**: Currently DockClientComponent has 3 separate timeout countdowns (`_refinery_timeout`, `_docking_timeout`, `_queued_timeout`) that all do the same thing: give up after 5 seconds. Moving this to the host centralizes the logic. If host evicts a stale client, client receives `dock_timeout` signal and can retry. Host is the authority on dock state.

**Alternative considered**: Keep timeouts on client only. Rejected — duplicated across 3 states, fragile when client is freed mid-queue.

### 3. Remove queue recheck logic from DockClientComponent

**Decision**: Delete `_find_shorter_queue()`, `_recheck_timer`, and the periodic recheck in `_process`. Client waits at the host it chose. Host promotes from queue on `leave_dock()`.

**Rationale**: The recheck logic adds complexity for marginal benefit. In practice, harvesters don't switch queues mid-wait — they wait or timeout. If a shorter queue exists, the client will find it on the next `seek_dock()` call after timeout. OpenRA doesn't have queue rechecking on the client side.

**Alternative considered**: Move recheck to DockHostComponent. Rejected — adds complexity to host for minimal benefit. If needed later, can add `notify_better_host` signal.

### 4. DockUnloadComponent reads accepted categories from EntityData

**Decision**: DockUnloadComponent's `configure(data: EntityData)` copies `data.accepted_resource_categories` to its own export. During `_process`, before unloading cargo, check if each cargo type's category matches accepted categories. Empty array = accept all (no validation).

**Rationale**: Two-way validation matches OpenRA's pattern: harvester declares what it collects, refinery declares what it accepts. This prevents a tiberium harvester from unloading at a service depot (which might accept vehicle repairs but not tiberium). Empty array as "accept all" preserves backward compatibility with existing buildings that don't set categories.

**Alternative considered**: Skip validation entirely. Rejected — violates the original design intent and allows incorrect gameplay.

### 5. Keep DockClientComponent's `seek_dock()` API stable

**Decision**: Public API (`seek_dock`, `release_reservation`, `find_nearest_host`) stays the same. Only internal timing logic changes. HarvestComponent calls unchanged.

**Rationale**: HarvestComponent is clean and well-tested. Changing its dock interface would cascade test changes unnecessarily. The simplification is purely internal to DockClientComponent.

## Risks / Trade-offs

- **[Risk] Stale client eviction races** → Host emits `dock_timeout`, client receives signal and retries. If client is already freed, `is_instance_valid()` guard prevents crash. Host checks validity before emitting.

- **[Risk] Removing queue recheck may cause longer wait times** → Mitigated by timeout + retry. Client finds next available host on retry. In practice, refineries process dockers fast enough that queue position rarely matters.

- **[Risk] Breaking existing tests** → Existing tests for DockHostComponent and DockClientComponent cover basic queue behavior. New tests cover the simplified flow. Old tests that relied on removed methods (like `_find_shorter_queue`) will be rewritten.

- **[Trade-off] Host complexity increases** → DockHostComponent grows from 160 to ~200 lines. Acceptable — host is the natural owner of dock state.

- **[Trade-off] `dock_unload` field stays on EntityData** → Kept for backward compatibility with existing .tres resources. Remove in a future cleanup.

## Post-Review Revisions

A review after the initial implementation reversed two decisions and refined the HarvestComponent state machine (previously a Non-Goal):

- **Decision 1 reversed — `refinery: bool` removed.** The flag had zero runtime readers (no AI system yet). Deleted from `EntityData`, `EntityFactory`, and `gdi_refinery.tres` as YAGNI. Re-add when the GameAI build-ratio system actually queries it (see plan `1-3_economy_resources.md`). `accepted_resource_categories` stays on EntityData and is applied via `DockUnloadComponent.configure(data)`.
- **Decision 2 refined — client `on_dock_timeout()` removed.** The host still emits `dock_timeout` on eviction (real, tested event), but the client handler and the `dock_slot_reserved` signal were redundant: stale eviction already drives client cleanup through `leave_dock() → docker_undocked → on_dock_undocked()`.
- **Cancellation unified.** `DockClientComponent.cancel()` aborts docking from any sub-state (leave slot/queue, then `_reset()`), mirroring OpenRA's `MoveToDock.Cancel → UnreserveHost`. `HarvestComponent.cancel_harvest` calls it so a player move order mid-dock cannot leave dangling state.
- **HarvestComponent state machine extended.** Added `DELIVERING` (replacing the old FULL/DOCKING/QUEUED trio) and `HIBERNATE`. `IDLE` now means only "waiting for player orders"; an exhausted, empty harvester enters `HIBERNATE` and auto-resumes, matching OpenRA's `FindAndDeliverResources` search-with-backoff (with dock-unblock, echoing OpenRA's `UnblockCell`).
- **Stale timeout scoped to phases.** The client resets the host stale timer on arrival and at unload start, so a long approach across the map isn't mistaken for a stuck docker.
- **`max_queue_length` removed.** The queue is unbounded; the client-side occupancy penalty provides soft load-balancing. A hard cap would require restoring the "rejected → try next-nearest host" fallback that was deleted.
