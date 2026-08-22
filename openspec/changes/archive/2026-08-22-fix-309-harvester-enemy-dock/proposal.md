## Why

A player's harvester can dock into and unload at an **enemy** refinery (GH #309). No layer in the dock pipeline checks ownership: the order targeter returns ENTER for any dock host, `find_nearest_host()` ranks hosts by distance/queue only, and `request_dock()` accepts any node. Worse, unload credits are attributed to the *docker's* owner, so an enemy harvester using your refinery pays its own side. Docking is a trust boundary that currently has no gate.

## What Changes

- `DockHostComponent.request_dock()` SHALL reject dockers whose entity owner (`StatsComponent.player_id`) does not match the host building's owner; unset ids (`< 0`) on either side are also rejected.
- `DockClientComponent.find_nearest_host()` SHALL skip foreign-owned and ownerless host candidates, so auto-delivery never targets an enemy refinery.
- `HarvestComponent.get_order_for_target()` SHALL only return an ENTER order when the target dock host is owned by the harvester's owner; foreign-owned docks fall through (no ENTER order).
- A full harvester with no friendly refinery in range SHALL idle near the field on the existing retry-cooldown loop instead of docking anywhere else; cargo is retained.
- Unload credits SHALL be attributed to the **refinery's** owner (the `DockUnloadComponent`'s parent building), not the docker's owner, and no credits are granted when the building has no valid owner.
- Test fixtures across the dock test files gain minimal owner setup so existing suites stay green under the new ownership rule.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `dock-host-client`: request_dock becomes owner-gated (trust boundary); find_nearest_host filters candidates by owner in addition to type compatibility.
- `resource-harvesting`: order targeter only issues ENTER on same-owner docks; full harvester idles with retry when no friendly refinery exists; unload credit attribution moves from docker to host building owner.

## Impact

- Scripts: `scripts/components/DockHostComponent.gd`, `scripts/components/DockClientComponent.gd`, `scripts/components/HarvestComponent.gd`, `scripts/components/DockUnloadComponent.gd`.
- Tests: `test/unit/test_dock_client_component.gd`, `test/unit/test_dock_host_component.gd`, `test/unit/test_harvest_dock.gd`, `test/unit/test_dock_queue_step.gd` — fixtures must assign owners; new ownership scenarios added.
- No scene changes, no data resource changes, no autoload changes.
- Backward compatible with existing `.tscn` files: components read ownership from the entity's existing `StatsComponent` at runtime; buildings without `StatsComponent` are treated as ownerless and refuse/are skipped rather than crashing.

Out of scope: allied/team dock sharing, capture mechanics, cursor feedback when clicking an enemy refinery.
