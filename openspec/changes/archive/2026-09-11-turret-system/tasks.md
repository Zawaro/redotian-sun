## 1. Data Schema

- [x] 1.1 Add `scripts/data/SocketData.gd` (`class_name SocketData extends Resource`) with `id`, `pivot: Transform3D`, `yaw_free: bool = true`, `barrel_length: float`, `placeholder_size: Vector3`, `model_path: String`
- [x] 1.2 Add `sockets: Array[SocketData]` and `get_socket(id) -> SocketData` to `ArtData.gd`; validate unique socket ids; remove `turret_offset`
- [x] 1.3 Add `scripts/data/WeaponMountGroupData.gd` with `weapon_index: int`, `socket_ids: PackedStringArray`, `fire_mode: FireMode`, `fire_delay: float`, and a `FireMode { SALVO, STAGGER }` enum
- [x] 1.4 Add `weapon_mount_groups: Array[WeaponMountGroupData]` to `EntityData.gd`; remove `turret` and `turret_anim`
- [x] 1.5 Add `EntityData.validate()` checks: group socket ids resolve on `art_data`, weapon index in range, non-empty socket ids; add `ArtData.validate()` duplicate-id check

## 2. Schema Tests

- [x] 2.1 Unit test: `SocketData` 3D pivot round-trips; `get_socket` unknown id returns null; empty sockets default
- [x] 2.2 Unit test: validation rejects duplicate socket ids, unknown socket in a group, and out-of-range weapon index
- [x] 2.3 Unit test: single-socket default binds all weapons; no sockets leaves all weapons body-mounted
- [x] 2.4 Verify `EntityData`/`ArtData` no longer compile with `turret`, `turret_anim`, `turret_offset` (no dangling references)

## 3. TurretComponent

- [x] 3.1 Add `scripts/components/TurretComponent.gd` owning per-socket yaw with `slew`, `get_yaw`, `get_socket_world_transform`; fixed sockets never yaw; never touch the body transform or MovementController
- [x] 3.2 Attach `TurretComponent` from `EntityFactory` when `ArtData.sockets` is non-empty
- [x] 3.3 Unit tests: slew rate/threshold, fixed socket no-yaw, independent socket yaws

## 4. Combat Mount Groups

- [x] 4.1 Refactor `CombatComponent.configure()` to build per-group channels (weapon, sockets, capability, fire_delay) with body-mounted fallback for unmounted weapons
- [x] 4.2 Replace the single-weapon `_physics_process` with per-group cooldown/range evaluation; `yaw_free` groups gate on `TurretComponent.slew`, body/fixed groups keep `_is_facing_target`
- [x] 4.3 Implement `SALVO`/`STAGGER` scheduling per group with `fire_delay` and a shared group cooldown of `rate_of_fire / 30.0`
- [x] 4.4 Keep `get_current_weapon()` as a group-0 accessor; remove or migrate the dead `cycle_weapon()`/`_current_weapon_index` and its tests
- [x] 4.5 Tests: rotatable mount fires while body moves; fixed/body holds fire until aligned; multiple groups fire independently; salvo same-tick; stagger spacing

## 5. Socket Muzzle Spawn

- [x] 5.1 Spawn projectiles from the firing socket's world transform + `barrel_length`, falling back to the entity transform for body mounts
- [x] 5.2 Tests: turret muzzle offset+yaw; body mount at entity transform; hitscan fallback unchanged

## 6. UnitMeshRenderer Socket Track

- [x] 6.1 Fix slot ownership to be bucket-driven so multiple sockets per entity (including twin sockets sharing a mesh key) compact correctly
- [x] 6.2 Add per-entity socket instances (register/release/migrate) with transform `entity.global_transform * pivot * yaw`
- [x] 6.3 Generate placeholder box meshes bucketed under a synthetic key; wire `ArtComponent` to register sockets after model/placeholder finalization
- [x] 6.4 Extend fog freeze/park/tombstone to the socket group atomically
- [x] 6.5 Tests: sockets allocated with body; fixed socket rest orientation; group migration; twin-socket compaction; placeholder box rendered

## 7. Structure Turret Path

- [x] 7.1 Render sockets via a node-tree child mesh for non-instanced entities, yawed by `TurretComponent`, visibility following entity fog
- [x] 7.2 Test: deployed-style building entity yaws a turret and fires at an off-facing target

## 8. Data Wiring

- [x] 8.1 Author sockets (3 rotatable + 2 fixed) and mount groups for `games/ts/entities/vehicles/gdi_mammoth_mk2.tres` + its `ArtData`
- [x] 8.2 Author the deployed Tick Tank socket (structure path) and any other turreted entity art
- [x] 8.3 Regression: turretless units fire exactly as before (body-facing)

## 9. Docs, Lint, Archive

- [x] 9.1 Update `GLOSSARY.md` with socket, weapon mount group, salvo, and stagger
- [x] 9.2 Run `redot --headless -s test/run_tests.gd`; run `gdlint` + `gdformat --check` on touched scripts and tests
- [x] 9.3 Re-run `openspec validate turret-system` and archive the change
