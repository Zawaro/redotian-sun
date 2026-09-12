## Why

Turreted units in Tiberian Sun keep their turret pointed at the current order target at all times: the enemy while attacking (even while closing the distance), and the destination while moving. The turret system shipped in #358 only slews toward a target **once it is already inside weapon range**, and a plain move order never touches the turret at all. The result is a turret that freezes mid-chase and ignores movement entirely.

## What Changes

- `TurretComponent` aims on its own physics tick for **every** entity, not just the node-tree (building) path. Each yaw-free socket not aimed by combat this tick faces the movement destination while the `MovementController` is moving, and realigns to its rest orientation (`yaw = 0`, chassis forward) when idle.
- `CombatComponent` slews yaw-free mounts toward the target **before** the range gate, so the turret tracks during the chase leg instead of freezing until the target re-enters range.
- Combat aim wins over movement aim within a tick; the two drivers do not step the same socket twice.
- Fixed sockets (`yaw_free = false`) and entities without a `MovementController` (buildings) are unchanged.

## Impact

- Modified: `scripts/components/TurretComponent.gd`, `scripts/components/CombatComponent.gd`.
- Tests: `test/unit/test_turret_system.gd`.
- Specs: `turrets` (continuous aim requirement), `combat-facing` (chase tracking scenario).
