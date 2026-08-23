## Context

The Windows export aborts on resource parse/load failures (issue #313), caused entirely by malformed data/scene files — no code is at fault:

- 6 warhead `.tres` files serialize `armor_damage_multipliers` (a `Dictionary`) as a positional `PackedFloat32Array([...])` left over from before #26 keyed multipliers by armor type. Both the container type and the `PackedFloat32Array([...])` bracket syntax are invalid in `.tres` form.
- `scenes/entities/terrain/ResourceCrystal.tscn` assigns `mesh = CubeMesh` (bare class names) instead of sub-resource references.
- `scripts/components/HitboxComponent.tres` carries a `[gd_scene]` header with a `.tres` extension — no loader handles it as a PackedScene.

**Second, distinct failure (folded into #313):** packed builds (`pck` on any target) fail at runtime to populate their data catalogs. All 10 entity ids a test map spawns print `EntityFactory: Unknown entity id:`, and terrain art prints `no art for family ''`. Reproduced on an Aug-22 Linux pack built before the #313 fix; the `.tres` files, `EntityData.gdc`, `.remap`, and `global_script_class_cache` are all present inside the pack. Works in-editor, fails only from the pack. This points to the shared `register_data_set()` resource directory-scan + `load()` of script-classed `.tres` failing inside a pack (script/class resolution against compiled `.gdc` + uid remap).

Stakeholders: export pipeline (fails today), combat system (must stay intact — user explicitly requires the HitboxComponent to keep working: hit detection, projectile impact, warhead FX), gameplay boots (packed builds must spawn the map's entities).

## Goals / Non-Goals

Goals:
- Export resource scan passes with zero parse/load errors.
- No gameplay/balance change: warhead values preserved exactly.

Non-Goals:
- No `.gd` script changes, no new loaders, no migration tooling, no test-fixture rewrites.

## Decisions

**D1 — Serialize warhead multipliers as keyed dictionaries.**
`WarheadData.armor_damage_multipliers` is `Dictionary` (scripts/data/WarheadData.gd:23); the canonical sibling files serialize `{"none": .., "wood": .., "light": .., "heavy": .., "concrete": ..}`. The 6 broken files get the same form. Key assignment is derived by position against the canonical armor order (`none`, `wood`, `light`, `heavy`, `concrete`) — the same order every other warhead uses and the registry defines. Ambiguous files
 - `fire2`: array `[6.0, 1.48, 0.59, 0.06, 0.02]` — identical values to `fire.tres`, mapping = clone of fire.
 - `veinholewh` / `firestormwh` / `ioncannonwh`: uniform `[1.0,1.0,1.0,1.0,1.0]` → all `1.0`, mapping is order-insensitive.
 - `ionwh`: `[0.9, 0.75, 0.6, 0.25, 1.0]` → `none:0.9, wood:0.75, light:0.6, heavy:0.25, concrete:1.0`. (U-shaped concrete=1.0 is plausible for ion; if a future rules.ini check contradicts it, that is a separate data fix — serialization itself just needs a valid mapping.)
 - `tankogas`: `[0.9, 1.0, 0.6, 0.25, 0.1]` → same-position mapping.

Alternatives considered: (a) keeping `PackedFloat32Array` and changing the field type — rejected, rework of WarheadData code + breaks the keyed design; (b) dropping the files — rejected, loses 6 warheads.

**D2 — `ResourceCrystal.tscn`: add a `CubeMesh` sub-resource.**
Replace the three `mesh = CubeMesh` lines with a single `[sub_resource type="CubeMesh" id="CubeMesh_..."]` referenced as `SubResource(...)` on all stage nodes — the same pattern as `[sub_resource type="BoxMesh" ...]` in GDI placeholder scenes.

**D3 — Delete `scripts/components/HitboxComponent.tres`.**
It is an orphan: the path and its uid `uid://clfyqn8olrw57` appear nowhere in `scripts/`, `scenes/`, or `resources/` (verified via ripgrep + `.godot` cache). Its entire content — a `BoxShape3D(1,1,1)` — already exists in the canonical `scenes/components/HitboxComponent.tscn` (sub_resource `BoxShape3D_nystl`). 

Deliberate choice given the user requirement: **the canonical HitboxComponent (`.gd` + `.tscn`) is untouched and stays fully functional**. Only the stray `.tres` fragment, which export chokes on as `expected type: PackedScene`, goes away. Combat behavior (projectile hit detection, warhead FX surface rendering via `EntityFactory` instantiations) is orthogonal to this orphan.

Alternatives considered: (a) converting the `.tres` to a loadable PackedScene — kept only if any reference existed; none do, so deleting is the minimal fix. (b) Renaming to `.tscn` — no consumer needs it, still orphaned.

**D4 — Packed-build data catalog: trim the `.remap` suffix during directory scans.**
Diagnosis (instrumented `_scan_directory` in a fresh Linux pack) proved the scan and `load()` were never the problem: inside a `.pck`, `DirAccess` enumerates resource files as `<name>.<ext>.remap` (Redot stores the remap redirect in the pack directory listing), so the `ends_with(".tres")` guard never fired and `_entity_cache` stayed empty. Every `.tres`-style entry came back as `X.tres.remap`, the scan cached nothing, and `create_entity` reported every id unknown.

Fix: normalize each enumerated name with `file_name.trim_suffix(".remap")` before the extension check and use the trimmed path as `full_path`. The ResourceLoader already resolves the real packed resource from the trimmed path (it follows the implicit remap), so no id list, no late hook, no new dependency. Verification: a headless run of `TestMap02` from the exported pack now spawns all 10 entity ids and resolves every terrain art family (zero `Unknown entity id:`, zero `no art for family ''`).

Alternatives considered (chosen one is bolded):
- **D4a — `trim_suffix(".remap")` in each `register_data_set()` scan (EntityFactory, TerrainCatalog, AudioManager):** minimal, shared-pattern-preserving, editor-safe (`.remap` is a no-op on plain files), fixes all three catalogs at once. **Chosen**.
- D4b — export config/`binary_format` changes to hide `.remap`: treats a normal pack feature as a bug, doesn't generalize, risks re-breaking with default presets.

**D5 — `test_terrain_system.gd` housekeeping:** fold the pre-existing parse error into this change. Fix the script so it parses (keeping the assertions meaningful per repo test rules) or, if the test is genuinely stale, document why and remove it deliberately — never weaken an assert to silence a failure.

## Risks / Trade-offs

- [Keyed mapping drift vs. rules.ini semantics] → Values are copied verbatim from the existing arrays; the mapping only converts container syntax. Any balance error is pre-existing, not introduced, and boxed in a single diff per file.
- [HitboxComponent appears to be "removed"] → The proposal/specs explicitly state the `.gd` + canonical `.tscn` stay; only an orphaned fragment is removed. Deletion is verified by the zero-reference grep before merge.
- [`.tres` parse still blocked by Redot 26.2 quirks] → Mitigation: `redot --headless --import` gate before the export step; iterate against actual output.

## Migration Plan

1. Edit 6 warhead `.tres` (line 10) → keyed dictionaries. ✔ done
2. Edit `ResourceCrystal.tscn` → sub-resource CubeMesh. ✔ done
3. `git rm scripts/components/HitboxComponent.tres`. ✔ done
4. Re-index import: `redot --headless --import` — no parse errors. ✔ verified
5. Re-run Windows export to confirm completion. ✔ verified (exit 0)
6. Repro packed-build catalog failure on a fresh Linux export; instrument `_scan_directory`; fix per D4a/D4b; re-export and verify map boots with all 10 entity ids + terrain arts.
7. Fix `test/unit/test_terrain_system.gd` parse error (D5).

Rollback: `git revert` of the branch; the files are static data, no migration needed.

## Open Questions

- None blocking. Confirm the `ionwh`/`tankogas` mappings against `rules.ini` opportunistically if a source copy is found, but the serialization fix does not depend on it.