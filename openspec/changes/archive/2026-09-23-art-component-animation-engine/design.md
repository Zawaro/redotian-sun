## Context

`ArtComponent` (scripts/components/ArtComponent.gd) currently loads an entity's base GLB and installs an empty `AnimationPlayer` as its own child in `_setup_animation_player()`; it never references the `AnimationPlayer` that the glTF importer creates inside the loaded model. As a result the existing animation surface (`ActiveAnimData`, `active_anims`, `door_anim`, `production_anim`, `buildup_name`, `deploying_anim`) has never played anything, and none of the four current GLBs (`games/ts/assets/models/`) contain animations. The art vocabulary is already authored in `references/art.ini` (`ActiveAnim`, `ActiveAnimTwo/Three`, `ActiveAnimDamaged`, `ActiveAnimPowered`, `DoorAnim`, `UnderDoorAnim`, `ProductionAnim`, `PreProductionAnim`, `Buildup`, `DeployingAnim`, `NewTheater`, `Rate`) but has no consumer.

ArtData is a `.tres`-authored `Resource` resolved through `GameContext`/`EntityFactory`. `ArtComponent` already connects sibling-component signals in `configure()` (`PowerComponent.power_state_changed`, `ExitComponent.unit_spawned`), so lifecycle triggers can follow the existing "signal up, call down" pattern without new cross-component calls. The active theater is available from `TerrainCatalog.get_active_theater_id()`. Units render through the static `ModelBaker`/`UnitMeshRenderer` bake path (`UnitMeshRenderer.register`), so per-unit animation is not available on that path.

## Goals / Non-Goals

**Goals:**
- One resource shape for every animated visual: a GLB, an offset, playback config, a role, and a power flag.
- A working engine that finds each clip GLB's own `AnimationPlayer`, plays it, and honors speed and loop.
- Suffix-based theater resolution with a generic fallback, driven by one `new_theater` bool.
- Per-animation power gating and 50% damaged-state swap.
- One-shot lifecycle clips: buildup on placement, door open/close, production during a factory exit.
- Verified with synthetic `PackedScene` + `AnimationPlayer` fixtures (no animated art exists yet).

**Non-Goals:**
- GLB punctual lights and `powered_light` (own ticket).
- Deploy/undeploy whole-art swap (needs a `DeployComponent` transition window; own ticket).
- Terrain art per-file theater split (own ticket).
- Superweapon silo door, 25% extra-damage FX/smoke, animated unit sub-meshes.
- Authoring any actual animated GLB.

## Decisions

### One `AnimClipData` resource with a `role`, not parallel fields

Every art.ini key is the same tuple: separate file + offset + playback config + trigger. Modeling 20 of them as discrete `String` fields on `ArtData` would duplicate loader logic, theater resolution, and validation per field, and the Inspector cannot validate a raw path string. A single `Array[AnimClipData]` with a `role` enum gives one loader, one resolver, one validator, and matches the existing `Array`-of-Resource patterns (`ArtData.sockets: Array[SocketData]`, `EntityData.weapons: Array[WeaponData]`).

Alternatives considered: keep `ActiveAnimData` for looping clips and add parallel fields for one-shots (rejected — two shapes, inconsistent); a per-key dictionary (rejected — stringly typed). The class rename is cheap: `ActiveAnimData` is referenced only by `ArtData`, `ArtComponent`, and one test.

### Each clip keeps its own `AnimationPlayer`

Clips are separate GLBs, each importing with its own root `AnimationPlayer`. `ArtComponent` holds `{node, player, entry, normal/damaged node}` records instead of merging animations into one player and rebasing tracks. Merging would require retargeting every track onto the art component and mapping loop/speed per track; playing each model's own player is a direct `play(clip, speed)` and keeps offsets/local transforms intact.

### Theater resolution by filename suffix, one bool

TS `NewTheater` swaps a single filename character; we use a clearer full-id suffix (`_temperate`, `_snow`) before the extension, resolved with `ResourceLoader.exists` and falling back to the generic authored path. This costs one already-present `new_theater` bool and zero per-entry parameters. It is deliberately different from the terrain path, which uses an explicit `TerrainArtData.theater_overrides` dictionary resolved by `TerrainCatalog.resolve_art()`; terrain migration to the same convention is a separate ticket. The inconsistency is accepted now because terrain elements are catalog-keyed and uniform while entity art is per-asset, and because the user explicitly preferred the automatic form.

### Power loss pauses every gated clip; one-shots do not loop

`ArtComponent` pauses every clip whose entry has `requires_power = true`, regardless of role. On restore, `ACTIVE` clips resume from their preserved playhead; event-driven one-shot clips stay paused until retriggered. `_connect_siblings()` runs before the model-load branch in `configure()` so the synchronous cache-hit/placeholder path builds clips with the real power and damaged state, not the defaults. Loop mode is role-driven: only `ACTIVE` honors the `loop` flag, every other role is forced `LOOP_NONE` (a `BUILDUP` stuck on `LOOP_LINEAR` never emits `animation_finished` and would leave the building hidden; a `DOOR` would cycle instead of holding). Door clips rest on frame 0 while idle via `play` + `seek(0)` + `pause`, since a never-played player shows the bind pose. Each clip player's animation libraries are duplicated on configure so per-instance loop edits cannot mutate the shared `PackedScene` served by the `BatchLoader` cache.

Alternatives considered for loop control: trust the schema `loop` default (rejected — `true` silently breaks one-shots); duplicate only when a loop value differs (rejected — same code path, no benefit).

### Damaged swap hides/shows nodes rather than swapping clips

Because the damaged state is a separate GLB (`damaged_model_path`), the swap is node visibility on `health_changed`: at ratio ≤ 0.5 show the damaged node and hide the normal node, above 0.5 reverse. This avoids stopping/restarting the base player and keeps the normal clip's playhead intact.

### Animation authoring is keyframed, not baked

glTF animations are keyframe channels; Blender's default `Sampling Animations` bakes every frame. For the small looping clips here (antenna, doors), disabling sampling exports sparse keyframes and smaller files. No baking is required by the engine. Documented for asset authors in tasks.

### Deploy/undeploy animation is a separate change

"Deploy replaces the whole building art and reverses on sell/undeploy" needs the entity swap to wait for an animation. `DeployComponent` today creates/frees the source and target immediately after an optional rotation (`_complete_deploy` → `_do_deploy`), with no transition window. Adding that window is a component-lifecycle change (hidden building created first, gameplay gated until the clip finishes, reverse before freeing). It is split out to keep this change reviewable (#438).

## Risks / Trade-offs

- [Renaming `ActiveAnimData` breaks any stale scene/resource referencing it by script] → Only `ArtData`, `ArtComponent`, and `test_power_grid.gd` reference it; regenerate the `.uid` and update all three in one commit.
- [Theater `ResourceLoader.exists` calls during load add filesystem checks] → Resolution runs once per clip at model finalize, not per frame; results are the paths actually loaded and cached by `BatchLoader`.
- [Suffix convention can silently miss a variant on a typo] → Generic fallback always exists and the loaded path is used for the cache key, so a miss degrades to the generic art rather than erroring.
- [Larger footprint: each building gets N extra nodes/players] → Only buildings are animated (units render through the static bake path); clip count is authored, small, and GLBs load through the existing `BatchLoader`/threaded path.
- [No animated art exists to validate against] → All behavior is covered by synthetic fixtures; real-asset verification is a follow-up once the first animated GLB lands.
- [Unit sub-meshes cannot animate through `UnitMeshRenderer`] → Out of scope (#437). `_build_clips()` is not guarded for instanced unit types, so an animated unit clip would double-render alongside the MultiMesh; this is documented in a code comment rather than guarded, since no unit art authors clips and the art model is expected to grow in later tickets.

## Migration Plan

1. Add `AnimClipData` (new `.uid`), delete `ActiveAnimData` (and its `.uid`) in the same commit.
2. Update `ArtData` (`animations`, folded one-shots, `validate()`), `ArtComponent`, and `test_power_grid.gd`.
3. No `.tres` migration needed: no art resource currently sets `active_anims`.
4. Rollback: revert the commit; no persisted runtime state depends on the schema.

## Open Questions

- Should the final `role` enum keep every art.ini role now (inert until implemented), or only the roles implemented in this change? The spec assumes the full enum so the schema does not churn later.
- After terrain art moves to per-file theater variants, should `TerrainCatalog.resolve_art` be rewritten onto the same suffix helper to remove the duplicate resolution logic?

## Asset authoring contract (Blender → Redot)

For whoever authors the animated GLBs:

- **One GLB per clip.** Active, damaged, door, production, and buildup visuals are separate files referenced by `AnimClipData.model_path` / `damaged_model_path`. Do not merge several animations into the base building model.
- **Keep keyframes, not baked frames.** In the glTF exporter disable `Sampling Animations` so object animations export as sparse keyframes (smaller, and the engine plays them at `speed_scale`). Light/material property animation would need `KHR_animation_pointer` and is not relied on — do on/off and flicker in code.
- **Pivot at the entity origin, footprint centered.** Author the clip at the origin; set placement with `AnimClipData.offset` in the `.tres`, not by moving the model in Blender.
- **Clip naming is optional.** The engine plays `clip_name` when set, otherwise the player's first animation. The damaged GLB may name its action differently — the engine falls back to that file's first animation.
- **Theater variants are filenames.** With `ArtData.new_theater`, name the variant `<base>_<theater>.<ext>` using the theater id (`_temperate`, `_snow`). Always ship the generic file as the fallback; a missing variant degrades to it silently.

