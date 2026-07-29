## Context

CombatComponent is a data container. It stores weapons from EntityData, resolves cursors and orders, but `_attack()` is an empty stub. The order flow works end-to-end: left-click enemy → OrderResolver → CombatComponent.get_order_for_target() → OrderResult with `_attack()` callable. The missing piece is the actual firing logic inside `_attack()`.

Additionally, no entity .tres file references weapons. EntityFactory checks `data.weapons.is_empty()` and skips CombatComponent creation entirely. The weapon .tres files exist (44 files) but nothing points to them.

MovementController has `_state: State` (private) with no public getter. CombatComponent needs to know if the unit is already moving to avoid spamming move commands.

## Goals / Non-Goals

**Goals:**
- CombatComponent tracks a target, moves toward it if out of range, fires when in range + cooldown ready
- Hitscan damage: `target.HealthComponent.take_damage(damage)` — no projectile node
- Per-weapon cooldown timer based on `rate_of_fire`
- Range check: `attack_range * CELL_SIZE` converted to world distance
- `weapon_fired` signal for future projectile system hookup
- Infantry .tres files wired to weapon .tres files

**Non-Goals (MVP):**
- Turret rotation toward target
- Elite weapon promotion
- Ammo tracking / reload
- Burst fire
- Weapon auto-selection (anti-air vs ground)
- Sound / animation on fire
- Projectile visuals (#78)
- Armor damage calculation (#30 secondary)

## Decisions

### 1. Hitscan instead of projectile spawning

**Decision**: `_fire_weapon()` calls `target.HealthComponent.take_damage()` directly.

**Rationale**: The projectile system (#78) is a separate issue. Hitscan gives us functional combat now. The `weapon_fired` signal allows #78 to connect later and replace hitscan with visual projectiles without changing CombatComponent's interface.

**Alternative considered**: Spawn an invisible projectile node. Rejected — adds complexity for zero visual benefit in MVP, and the projectile system hasn't been designed yet.

### 2. Target tracking via `_physics_process` loop

**Decision**: `_attack()` sets `_target` and starts a `_physics_process` loop that checks range + cooldown each tick.

**Rationale**: `_attack()` is called once per click (not continuously). The loop handles the full engagement cycle: move → wait → fire → wait for cooldown → fire again. This matches how HarvestComponent and DockClientComponent work (set target, loop processes behavior).

**Alternative considered**: Poll in `_attack()` with await/timer. Rejected — GDScript `await` in component callbacks is fragile and doesn't compose well with the order system.

### 3. Movement integration via arrived signal

**Decision**: Connect to `MovementController.arrived` signal on first attack. When `arrived` fires, the next `_physics_process` tick re-checks range and fires if in range.

**Rationale**: Avoids fighting MC for control. MC handles pathfinding and movement. CombatComponent just watches distance. Pattern matches HarvestComponent (line 38: `mc.arrived.connect(on_arrived)`).

**Alternative considered**: Call `mc.set_target_position()` every frame. Rejected — wasteful and could cause pathfinding thrashing.

### 4. `is_moving()` getter on MovementController

**Decision**: Add `func is_moving() -> bool: return _state != State.IDLE`.

**Rationale**: CombatComponent needs to know if MC is already moving before issuing another move command. Without this, it would call `set_target_position()` every frame while the unit is en route. Minimal change — one getter method.

### 5. Weapon data wiring via .tres edits

**Decision**: Add `weapons = [ExtResource("m1carbine")]` to infantry .tres files.

**Rationale**: The data exists (weapon .tres files), just not wired. This is a .tres file edit, not a code change. EntityFactory already handles the rest — if `data.weapons` is non-empty, it creates CombatComponent and calls `configure(data)`.

## Risks / Trade-offs

- **Stale target after death** → `_physics_process` checks `is_instance_valid(_target)` every tick and checks HealthComponent. Target death clears `_target` and stops the loop. #82 (death handler) will remove the node, which `is_instance_valid` catches.

- **Movement spam** → `is_moving()` check prevents issuing move commands while MC is already moving. Only issues a new move if MC is idle AND target is out of range.

- **Multi-weapon entities** → MVP uses `_current_weapon_index` (single weapon). Multi-weapon cycling is a future enhancement. The cooldown array is per-weapon but only index 0 is used initially.

- **No death removal yet** → Target health reaches 0, `health_zero` emits, but the node stays in tree until #82. This is fine — `is_instance_valid` handles it, and the target is harmless at 0 HP.
