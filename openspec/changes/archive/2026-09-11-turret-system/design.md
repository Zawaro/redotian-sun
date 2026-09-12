## Context

Combat facing (#325) rotates the whole entity body to aim. Turreted Tiberian Sun units (deployed Tick Tank, Mammoth Mk.II, Titan, Wolverine) instead keep the chassis on course while a turret tracks the target. The data classes already carry dead turret stubs — `EntityData.turret: bool`, `EntityData.turret_anim: String`, `ArtData.turret_offset: float` — read into `CombatComponent.configure()` and then never used; no `.tres` authors them and no scene has a turret node.

Two structural constraints shape this design:

1. **Rendering is split.** `UnitMeshRenderer` bakes a unit's whole model into one merged `ArrayMesh` and draws it as one MultiMesh instance. A turret cannot be welded into that mesh and yawed; it must be a separate instance. Buildings are excluded from instancing (`_eligible_for_instancing()` allows only INFANTRY/VEHICLE/AIRCRAFT) and render through their node tree.
2. **Weapon resources are shared.** `90mm.tres` is mounted by both the mobile and deployed Tick Tank; `mammothtusk.tres` by two Mammoth variants. A weapon→turret binding cannot live on `WeaponData`.

The deployed Tick Tank is `entity_type = BUILDING` and its deploy link (`deploys_into`) is not even wired, so "mobile no turret / deployed turret" is already expressed as two entities — no runtime deploy-state turret logic is needed.

## Goals / Non-Goals

**Goals:**
- Art-data-owned socket table with 3D pivots and a rotatable/fixed capability bit.
- Per-unit weapon→socket binding supporting one weapon fired from several sockets.
- Per-mount-group fire channels with independent cooldowns and explicit SALVO/STAGGER discipline.
- Rotatable mounts fire while the body moves; fixed/body mounts keep the body-facing gate.
- Turret yaw is a single value consumed by both combat alignment and rendering.
- Turret rendering for both instanced units and node-tree structures, with placeholder boxes now.

**Non-Goals:**
- Building upgrades (GAVULC/GAPOWRUP) and structure guard AI — these stay in #245.
- Real turret models / per-turret GLB extraction in `ModelBaker` — a later change; placeholders suffice.
- Per-socket ammo/reload, independent per-socket target selection, turret idle spin.
- Reworking `MovementController` or `rotation_target_path`, which stay body-only.

## Decisions

### D1: The socket table lives on `ArtData`, not a `TurretData` on `EntityData`
`ArtData.sockets: Array[SocketData]` owns geometry (`pivot: Transform3D`, placeholder size, future model path) and the `yaw_free` capability. `EntityData` references sockets only by opaque string id. This preserves the project's art/behavior boundary. *Alternative considered:* a `TurretData` resource on `EntityData` — rejected (it puts art geometry on the behavior resource and the user rejected it).

### D2: Binding is `WeaponMountGroupData` on `EntityData`
A group names one `weapon_index`, one or more `socket_ids`, and the firing discipline. Multiple sockets per weapon support twin rocket turrets; a weapon absent from all groups is body-mounted. *Alternatives:* a parallel `weapon_socket_ids: PackedStringArray` (rejected — couples arrays by index and allows only one socket per weapon); `turret_index` on `WeaponData` (rejected — shared resource).

### D3: One capability bit collapses fixed vs rotatable
`SocketData.yaw_free` decides the gate: `true` → turret alignment, `false` → body facing. Fixed railguns and rotatable turrets share one code path and one data table. *Alternative:* a separate fixed-weapon code path — rejected (two systems to maintain).

### D4: Explicit `FireMode` plus `fire_delay`
`FireMode { SALVO, STAGGER }` states intent; `fire_delay: float` is the seconds value (`SALVO` = optional wind-up before the volley, `STAGGER` = gap between successive sockets). The group shares one rearm cooldown. *Alternative:* implicit delay-driven behavior — rejected as hard to read, and the user asked for a distinct, easy-to-understand mode parameter.

### D5: `TurretComponent` owns yaw as the single source of truth
Combat calls `slew`/reads alignment; the renderer reads `get_yaw`/`get_socket_world_transform`. Neither consumer owns the angle, so render and simulation cannot drift. `TurretComponent` never touches the body transform or `MovementController`. *Alternative:* `CombatComponent` owns yaw — rejected (couples rendering to combat, and structures need turrets without combat re-architecture).

### D6: Two render paths behind one data model
Instanced units render sockets through a new `UnitMeshRenderer` per-entity socket track (`entity * pivot * yaw`). Non-instanced entities (buildings, deployed Tick Tank) render sockets as node-tree child meshes yawed by `TurretComponent`, with fog handled by the node tree. *Alternatives:* force buildings through MultiMesh (rejected — instancing eligibility and building fog/ghost handling are node-tree based); node-tree for all turrets (rejected — defeats the chosen instanced path and real-model performance).

### D7: Placeholder turret meshes now
`SocketData.model_path` is reserved; until real models exist, a generated `BoxMesh` is baked into an `ArrayMesh` and bucketed under a synthetic key (e.g. `__socket:WxHxD`). *Alternative:* node-tree box children for every turret — rejected (a second mechanism that would be thrown away).

### D8: Single-socket default binding
If `ArtData.sockets` has exactly one socket and `EntityData.weapon_mount_groups` is empty, all weapons bind to that socket. This matches the common tank (one turret, one or two weapons) with no authoring burden.

### D9: Retire the dead stubs now
Remove `EntityData.turret`, `EntityData.turret_anim`, and `ArtData.turret_offset` in this change rather than shimming. Nothing authors them; `turret_anim` is a building-only INI concept with no replacement here. Coordinate with #397 so it does not also remove them.

### D10: Slot ownership becomes bucket-driven
The current `_release_slot` scans `_registry` and `break`s on the first slot match. With N sockets per entity, twin sockets sharing a mesh key corrupt each other's slot index. Fix ownership to be resolved from the bucket (slot → owning entry/socket) before adding the socket track.

### D11: Muzzle spawn anchors on the socket frame
Projectiles spawn from the firing socket's world transform (plus `barrel_length`), fixing the unit-center spawn. Full FLH population from art.ini remains #326; this change provides the frame #326 resolves against.

## Risks / Trade-offs

- **CombatComponent refactor breaks ~20 existing tests** → body-mounted is the default for any weapon without a group, preserving current behavior; keep `get_current_weapon()` as a group-0 accessor and update tests only where semantics genuinely change.
- **Slot corruption with multiple sockets** → make slot ownership bucket-driven (D10) before wiring sockets; add a twin-socket compaction test.
- **`ModelBaker` welds in-model turret geometry into the body** → turret geometry must be its own mesh key; placeholders make this a non-issue until real turret models land, and the socket track is keyed by mesh anyway.
- **Building turret fog/reparenting adds renderer-adjacent complexity** → keep structure turrets to the node-tree path and scope out building upgrades and guard AI (#245).
- **One body, several alignment authorities** → only body-mounted/fixed groups ever call `face_toward`; `yaw_free` groups only slew their own turret, so there is no race over the body heading.
- **Schema retirement collides with #397** → land #358 first or have #397 defer the turret fields.

## Migration Plan

1. Add `SocketData`, `WeaponMountGroupData`, `ArtData.sockets`, `EntityData.weapon_mount_groups`; remove `turret`, `turret_anim`, `turret_offset`. No authored `.tres` uses the removed fields, so no runtime data migration.
2. Add `TurretComponent`; refactor `CombatComponent` to mount groups with body-mounted fallback; anchor muzzle spawn on the socket frame.
3. Add the `UnitMeshRenderer` socket track (after the slot-ownership fix) and the structure node-tree turret path.
4. Author sockets/mount groups for the Mammoth Mk.II (3 rotatable + 2 fixed) and any other turreted entity; verify turretless units are unchanged.
5. Update `GLOSSARY.md` with socket, weapon mount group, salvo, and stagger.
6. Rollback: revert the branch. The only destructive part is the field removal, which no authored data depends on.

## Open Questions

- Whether `get_current_weapon()`/dead `cycle_weapon()` are kept as compatibility shims or removed with their tests migrated (deferred to implementation).
- Whether socket pivots are measured from the entity origin or the model root when a GLB has a non-identity model offset; this design assumes entity origin and adapts `ArtComponent`'s registration offset accordingly.
