## 1. TurretComponent

- [x] 1.1 Enable `_physics_process` for all entities (not just the node-tree path); keep the node-mesh transform block guarded by `_node_turrets`
- [x] 1.2 Cache the sibling `MovementController` lazily
- [x] 1.3 Factor the per-socket step into a shared helper; add `realign(socket_id, delta)` targeting `yaw = 0`
- [x] 1.4 Default aim pass: skip sockets aimed by combat this tick; moving → `get_target_position()`, idle → realign
- [x] 1.5 Set `process_physics_priority` so combat (0) aims before turret (50) before renderer (100)

## 2. CombatComponent

- [x] 2.1 Add `_aim_turrets(delta)` slewing every `yaw_free` channel socket at the target
- [x] 2.2 Call it in the out-of-range branch before `_move_toward_target()` so the turret tracks during the chase
- [x] 2.3 Record the physics frame in `TurretComponent.slew` so the movement/idle pass does not double-step an aimed socket

## 3. Tests

- [x] 3.1 Chase: out-of-range target + moving MC → yaw moves toward target
- [x] 3.2 Move: no target + moving MC, off-heading destination → yaw moves toward destination
- [x] 3.3 Attack target overrides movement destination
- [x] 3.4 Idle → yaw returns to `0`
- [x] 3.5 Fixed socket and building node-tree still unaffected

## 4. Verify & Archive

- [x] 4.1 `redot --headless -s test/run_tests.gd`
- [x] 4.2 `gdlint` + `gdformat --check` on touched scripts and tests
- [x] 4.3 `openspec validate turret-continuous-aim` and archive the change
