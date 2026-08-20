## Why

A full harvester given a harvest order can strand idle at the tiberium field. The TS-authentic flow — walk to the field, then head to the refinery — is intended, but `_deliver_cargo()` calls `DockClientComponent.seek_dock()`, which silently returns without engaging when the dock client is busy or on its retry cooldown. Since `_deliver_retry` is left at 0, the DELIVERING state never re-seeks; the only recovery is the interrupted dock completing on its own, which may never happen (e.g. permanently blocked dock path). The `resource-harvesting` spec also wrongly requires an ENTER cursor (direct-to-refinery) for a full harvester — that contradicts both the code and authentic Tiberian Sun behavior.

## What Changes

- `DockClientComponent.seek_dock()` returns a `bool`: true when it engaged (entered MOVING or QUEUED), false when it no-ops (client busy, retry cooldown, or no compatible host found).
- `HarvestComponent._deliver_cargo()` schedules the DELIVERING retry (`_deliver_retry = DELIVER_RETRY`) when `seek_dock()` reports it could not engage, so the harvester re-seeks the dock and self-heals instead of stranding.
- `HarvestComponent.set_target_refinery()` gets the same retry safety net for player-ordered docks.
- TS-authentic behavior is preserved and locked by test: a full harvester ordered to harvest still walks to the tiberium cell (SEEK_NODE), then routes to the refinery (DELIVERING) on arrival.
- Spec correction: the "Full cargo" scenario in `resource-harvesting` is rewritten — full cargo keeps the HARVEST cursor and the walk-to-field behavior; the direct-to-refinery ENTER-cursor requirement is removed.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `resource-harvesting`: full-cargo harvest order behavior — cursor stays HARVEST, the harvester walks to the tiberium cell then routes to the refinery; the direct-to-refinery ENTER-cursor requirement is removed.

## Impact

- `scripts/components/DockClientComponent.gd` — `seek_dock()` return type `void` → `bool`.
- `scripts/components/HarvestComponent.gd` — retry safety net in `_deliver_cargo()` and `set_target_refinery()`.
- `test/unit/test_harvest_dock.gd` — TS-lock test (full harvester walks to field then delivers) + strand regression test (non-engaging `seek_dock` still recovers).
- `test/unit/test_dock_client_component.gd`, `test/unit/test_dock_queue_step.gd` — unchanged behavior; existing assertions remain valid.
- `openspec/specs/resource-harvesting/spec.md` — corrected "Full cargo" scenario.
