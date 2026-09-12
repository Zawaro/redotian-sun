## Why

Combat currently forces a unit's **whole body** to face its target before firing (#325), and the turret schema is dead: `EntityData.turret`, `EntityData.turret_anim`, and `ArtData.turret_offset` have zero consumers and zero authored `.tres`. Tiberian Sun vehicles and defenses instead track targets with independently-yawing turrets while the chassis holds course, and the Mammoth Mk.II carries several turrets that fire different weapons on their own schedules. There is no mechanism for any of that today, and multi-barrel/multi-turret units also need independent muzzle channels and a per-unit weapon→turret binding (a weapon resource is shared across units, so the binding cannot live on `WeaponData`).

## What Changes

- Add a `SocketData` resource owned by `ArtData.sockets`: a stable string id, a **3D** `pivot: Transform3D`, a `yaw_free` capability flag (rotatable vs fixed), a barrel length for muzzle placement, a placeholder box size, and a reserved turret-model path.
- Add `WeaponMountGroupData` on `EntityData`: per-unit binding of one weapon to one or more sockets, plus an explicit `FireMode` (`SALVO` / `STAGGER`) and `fire_delay`. A weapon absent from every group stays body-mounted and keeps today's whole-body facing behavior.
- Add `TurretComponent`, which owns per-socket yaw as the single source consumed by both combat alignment and rendering.
- Refactor `CombatComponent` to per-mount-group fire channels with independent cooldowns; a `yaw_free` group fires while the body moves (gated on turret alignment), a body-mounted/fixed group keeps the #325 body-facing gate.
- Spawn projectiles from the firing socket's world transform instead of the unit center (anchors #326's FLH resolver).
- Render instanced unit turrets as their own `UnitMeshRenderer` instances (`entity * pivot * yaw`); render structure/building turrets through a node-tree turret child path, so the deployed Tick Tank and defensive structures work even though buildings are not instanced.
- **BREAKING** (data schema): remove `EntityData.turret`, `EntityData.turret_anim`, and `ArtData.turret_offset`. No authored `.tres` uses them today, so there is no runtime data to migrate; `turret_anim` is a building-only INI concept and is not replaced here (structure turret art lands with the structure-turret requirement).

## Capabilities

### New Capabilities
- `turrets`: socket data model (SocketData on ArtData), per-unit weapon mount groups and fire modes, TurretComponent per-socket yaw, rotatable-vs-fixed firing gates, and both the instanced and node-tree turret render paths.

### Modified Capabilities
- `combat-firing`: per-mount-group cooldowns and fire discipline replace the single active-weapon behavior; muzzle spawn originates from the socket frame.
- `combat-facing`: firing no longer requires body alignment for weapons mounted on a rotatable socket; the existing body-facing gate applies only to body-mounted/fixed weapons.
- `unit-multimesh-rendering`: the renderer gains a per-entity socket instance track alongside the body instance, with group-atomic slot lifecycle, migration, and fog handling.

## Impact

- New: `scripts/data/SocketData.gd`, `scripts/data/WeaponMountGroupData.gd`, `scripts/components/TurretComponent.gd`.
- Modified: `scripts/data/ArtData.gd`, `scripts/data/EntityData.gd`, `scripts/components/CombatComponent.gd`, `scripts/components/ArtComponent.gd`, `scripts/entities/EntityFactory.gd`, `scripts/core/UnitMeshRenderer.gd` (and later `scripts/core/ModelBaker.gd` for real turret models).
- Data: `games/ts/entities/vehicles/gdi_mammoth_mk2.tres` and other turreted entities gain sockets/mount groups; `ArtData` files for those entities gain sockets.
- Tests: `test/unit/test_combat_component.gd`, `test/unit/test_unit_mesh_renderer.gd`, `test/unit/test_fog_ghosts.gd`, plus new data/component tests.
- Docs: `GLOSSARY.md` gains socket/turret/mount-group/fire-mode terms.
- Coordinates with #245 (structure upgrades + guard AI stay out of scope), #326 (FLH resolver consumes the socket frame), and #397 (must not delete fields this change wires).
