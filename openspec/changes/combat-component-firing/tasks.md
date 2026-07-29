## 1. Data — Wire weapons to entities

- [x] 1.1 Add `weapons` array reference to `gdi_light_infantry.tres` pointing to `m1carbine.tres`
- [x] 1.2 Add `weapons` array reference to `nod_light_infantry.tres` pointing to `m1carbine.tres`
- [x] 1.3 Verify EntityFactory creates CombatComponent for infantry (unit test or manual check)

## 2. MovementController — expose is_moving()

- [x] 2.1 Add `func is_moving() -> bool` getter returning `_state != State.IDLE`
- [x] 2.2 Add unit test for `is_moving()` across IDLE, ROTATING, MOVING, WAIT states

## 3. CombatComponent — firing logic

- [x] 3.1 Add `weapon_fired` signal declaration
- [x] 3.2 Add `_target: Node3D` var and `set_target()` / `clear_target()` methods
- [x] 3.3 Add `_cooldowns: Array[float]` and `_attack_active: bool` state vars
- [x] 3.4 Implement `_physics_process(delta)` — tick cooldowns, validate target, check range, fire or move
- [x] 3.5 Implement `_fire_weapon(weapon, target)` — hitscan `target.HealthComponent.take_damage(damage, warhead)`, emit `weapon_fired`
- [x] 3.6 Implement `_move_toward_target()` — check `is_moving()`, call `mc.set_target_position()` if idle and out of range
- [x] 3.7 Connect to `MovementController.arrived` signal on first attack engagement
- [x] 3.8 Rewrite `_attack(target)` to call `set_target(target)` instead of empty stub

## 4. Tests — firing logic

- [x] 4.1 Test `set_target()` stores reference, `clear_target()` clears it
- [x] 4.2 Test cooldown timer counts down and blocks fire while positive
- [x] 4.3 Test range check: out of range → issues move command
- [x] 4.4 Test range check: in range + cooldown ready → deals damage to target
- [x] 4.5 Test target invalidation: freed node → clears target, no errors
- [x] 4.6 Test target death: health_zero → clears target
- [x] 4.7 Test `weapon_fired` signal emits on successful fire
