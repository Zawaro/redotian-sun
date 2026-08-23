## Why

Exporting to Windows fails because the export resource scan hits parse errors in three resource groups, aborting the build (#313). Six warhead `.tres` files still serialize `armor_damage_multipliers` as a positional `PackedFloat32Array` (invalid for the current `Dictionary` field and invalid `.tres` syntax), `ResourceCrystal.tscn` assigns bare `CubeMesh` class names instead of sub-resources, and `scripts/components/HitboxComponent.tres` is a stray scene-header file with a `.tres` extension that no loader can handle (it expects a PackedScene).

Additionally, **packed builds fail at runtime to populate their data catalogs**: on any exported target (Windows, Linux) the `EntityFactory`, `TerrainCatalog`, and shared `register_data_set()` / `_scan_directory()` loads come up empty, producing `Unknown entity id:` for every map entity and `no art for family ''` for terrain. This is a separate, pre-existing bug (reproduced on an Aug-22 build made before the #313 fix) and is folded into this change.

## What Changes

- Rewrite `armor_damage_multipliers` in 6 warhead `.tres` files (`fire2`, `ionwh`, `tankogas`, `veinholewh`, `firestormwh`, `ioncannonwh`) as keyed dictionaries over the canonical armor ids (`none`, `wood`, `light`, `heavy`, `concrete`), preserving the values already present in the arrays.
- Fix `scenes/entities/terrain/ResourceCrystal.tscn` — replace bare `mesh = CubeMesh` assignments with a `SubResource` CubeMesh referenced by all three stage nodes.
- Remove the stray `scripts/components/HitboxComponent.tres` fragment (orphaned duplicate, referenced nowhere; its BoxShape3D content is already in the canonical `scenes/components/HitboxComponent.tscn`). **The HitboxComponent itself stays — hit detection, projectile impact, and warhead FX rendering surface must remain functional.**
- Add a guardrail: the export resource scan SHALL pass with no parse errors (validated via `redot --headless --import`).
- Root-cause and fix packed-build data-catalog loading so exported games resolve all entity ids and terrain art families (the `register_data_set()` directory scan must load `.tres` from a `.pck`).
- Fold in housekeeping: fix or document the pre-existing parse error in `test/unit/test_terrain_system.gd`.

## Capabilities

### New Capabilities
- `resource-loadability`: All scene and data resources tracked in the project SHALL parse and load without errors (no parse failures in `.tscn`/`.tres`), so the export pipeline packs cleanly. Data files SHALL use the serialized form their exported properties require (e.g., keyed dictionaries, sub-resource references), and no `.tres`-extension file SHALL masquerade as a scene.
- `packed-data-catalog`: A `.pck` build (`redot --headless --export-*`) SHALL resolve and register its data catalogs (entities, terrain objects, art, theaters) at runtime via the shared `register_data_set()` scan, so `EntityFactory` / `TerrainCatalog` / `AudioManager` return registered entries in exported builds just as they do in the editor.

### Modified Capabilities
- `armor-types`: The armor-multiplier validation requirement gains a scenario covering the legacy positional-array serialization failing to load (regression from #26).

## Impact

- `resources/warheads/{fire2,ionwh,tankogas,veinholewh,firestormwh,ioncannonwh}.tres` — serialization format fixed, values unchanged (no behavior change).
- `scenes/entities/terrain/ResourceCrystal.tscn` — sub-resource mesh reference fixed.
- `scripts/components/HitboxComponent.tres` — deleted (unused orphan); `.gd` + `.tscn` config unchanged.
- `scripts/entities/EntityFactory.gd`, `scripts/core/TerrainCatalog.gd` (and possibly the shared scan) — packed-load fix.
- `test/unit/test_terrain_system.gd` — housekeeping fix/documentation.
- Windows/Linux export completes; packed game boots with populated catalogs.