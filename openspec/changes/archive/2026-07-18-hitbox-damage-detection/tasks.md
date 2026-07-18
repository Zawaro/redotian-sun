## 1. HealthComponent damage_type support

- [x] 1.1 Add `damage_type: String = ""` parameter to `take_damage()` method
- [x] 1.2 Update `damage_taken` signal to emit `(damage_amount: int, damage_type: String)`

## 2. HitboxComponent damage detection

- [x] 2.1 Define collision layer constants (`LAYER_HITBOX_GROUND`, `LAYER_HITBOX_AIR`, `LAYER_HITBOX_BUILDING`, `LAYER_PROJECTILE`)
- [x] 2.2 Connect `area_entered` and `body_entered` signals in `_ready()`
- [x] 2.3 Implement `_try_deal_damage()` with `get_damage_info()` duck-typed protocol
- [x] 2.4 Emit `received_damage(damage, damage_type, source)` signal on hit

## 3. EntityFactory collision layer configuration

- [x] 3.1 Set collision layer per entity type in `_add_hitbox_component()` (ground/air/building)
- [x] 3.2 Set collision mask to `LAYER_PROJECTILE` on all combat hitboxes

## 4. Verification

- [x] 4.1 Run `gdlint` on all modified files
- [x] 4.2 Run `gdformat --check` on all modified files
- [x] 4.3 Run full test suite (203 passed, 0 failed)
