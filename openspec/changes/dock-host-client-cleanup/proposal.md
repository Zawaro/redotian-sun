## Why

The dock-host-client refactor (PR #52) introduced `RefineryComponent` that was never created as a file, and `DockClientComponent` at 349 lines has timing/retry logic that belongs on `DockHostComponent`. OpenRA's proven architecture shows the host should own queue timing while the client stays thin and reactive. Additionally, no unit tests cover the dock host-client interaction pattern (reservation, queue promotion, timeout handling).

## What Changes

- **Add** `refinery: bool` flag to `EntityData.gd` — classification tag for AI targeting (equivalent to Tiberian Sun's `Refinery=yes`)
- **Wire** `accepted_resource_categories` from EntityData through `EntityFactory._add_components()` to DockUnloadComponent — empty = accept all, non-empty = exclusive whitelist
- **Wire** `refinery` flag through `EntityFactory._add_components()` for AI targeting
- **Simplify** `DockClientComponent` from ~349 lines to ~120 lines by removing:
  - `_refinery_timeout` / `_docking_timeout` / `_queued_timeout` — host manages stale client cleanup
  - `_retry_cooldown` — host signals failure, client retries on next command
  - `_recheck_timer` / `_find_shorter_queue()` — host promotes from queue, client waits
- **Extend** `DockHostComponent` with:
  - `stale_timeout: float` — auto-evict clients that don't complete dock sequence within N seconds
  - Emit `dock_timeout` signal when client is evicted
- **Add** cargo validation in `DockUnloadComponent` using `EntityData.accepted_resource_categories` from the building's entity data (read at configure time)
- **Add** comprehensive unit tests for dock host-client relationship:
  - Request dock when empty → immediate dock
  - Request dock when occupied → queue
  - Queue full → reject
  - Leave dock → promote next in queue
  - Stale client timeout → evict and promote
  - Slot available signal → queued client transitions to docked
  - Dock type filtering (harvest vs repair vs other)
  - Cell reservation/release in SpatialHash

## Capabilities

### New Capabilities
- `dock-host-client`: Complete dock system — DockHostComponent queue management, DockClientComponent reservation flow, DockUnloadComponent cargo handling, cargo validation via accepted_resource_categories

### Modified Capabilities
- `entity-data`: Add `refinery: bool` field, remove `accepted_resource_categories` (replaced by per-building config on DockUnloadComponent), keep `dock_unload: bool` for backward compat
- `resource-harvesting`: Update DockHostComponent and DockClientComponent requirements to reflect simplified timing model; add cargo validation requirement

## Impact

- **Scripts**: `EntityData.gd`, `DockClientComponent.gd`, `DockHostComponent.gd`, `DockUnloadComponent.gd`, `EntityFactory.gd`, `HarvestComponent.gd`
- **Resources**: `resources/entities/structures/gdi/gdi_refinery.tres` (add `refinery = true`)
- **Tests**: `test/unit/test_dock_host_component.gd`, `test/unit/test_dock_client_component.gd`, `test/unit/test_harvest_dock.gd` — expand with comprehensive interaction tests
- **Scenes**: None — component-based architecture, no scene changes needed
