## Context

No audio system exists. The codebase has a well-established data-driven pattern: dynamic `.tres` loaders that scan directories and cache resources by `id` (`EntityFactory._scan_directory`, `TerrainCatalog._scan_directory`), and optional per-entity components attached conditionally based on `EntityData` fields (e.g. `ArtComponent` when `art_data` is set). The audio content already exists in `external_assets/audio/` (275 `.ogg` files, gitignored — copyrighted EA assets imported locally) and every file maps to a `references/sound.ini` `[SoundList]` id (274/274 matched, case-insensitive). `WeaponData.sound_report` already carries comma-separated fire-sound ids (e.g. `"INFGUN3,GOSTGUN1"`) that nothing plays yet. `references/rules.ini` defines the TS voice model: units have `VoiceSelect`/`VoiceMove`/`VoiceAttack`/`VoiceDie`/`VoiceFeedback`, each a comma-separated list of variant sound ids.

## Goals / Non-Goals

**Goals:**
- Engine-level `AudioManager` autoload usable by all future SFX/music (buses, spatial playback, event-driven).
- Data-driven: one `AudioData.tres` per sound, one `VoiceData.tres` per voice set, loaded by directory scan exactly like entity/terrain data.
- Unit select and order voices (GH #242).
- Graceful failure: missing id or failed load → `push_warning` + silent return.
- Author real content `.tres` from the available audio library.

**Non-Goals:**
- Music system (ambient, stingers, theme) — GH #255.
- Full faction/unit voice-set content mapping across all units — GH #251.
- Projectile landing sounds (combat is hitscan today; `ProjectileData` is defined but unused — explosion audio hooks in when projectiles land in a future change).
- Voice priority/ducking engine (per-sound `priority` is stored on `AudioData` for future use, not enforced this change).

## Decisions

### D1: `AudioManager` autoload with `_scan_directory` loader
`AudioManager` extends `Node`, registered in `project.godot` `[autoload]`. It exposes `register_data_set(path)` (idempotent per path) and a private `_scan_directory` cloned from `EntityFactory._scan_directory` (EntityFactory.gd:75). The scan loads each `.tres`, checks `resource is AudioData` or `resource is VoiceData`, and caches by `id`. Missing directory → `push_warning` + return.

*Alternatives:* a catalog-only approach (like `TerrainCatalog`) separate from playback. Rejected — the loader and playback are small enough to share one autoload, and other autoloads (EntityFactory, BuildingManager) already combine loading and behavior.

### D2: Two resource types, both standalone catalog items
- `AudioData` (extends Resource): `id`, `path`, `bus`, `priority`, `volume_db`, `is_spatial`. One `.tres` per sound file. This is what combat/effects/voices ultimately resolve to.
- `VoiceData` (extends Resource): `id`, plus `select/move/attack/die/feedback: Array[String]` holding audio ids. `VoiceData` is a **standalone catalog item** any entity can reference by id — no faction/player coupling (per product decision).

`VoiceData` stores audio ids (strings), not `AudioData` references, so `.tres` files stay decoupled and resolution happens through the `AudioManager` cache at playback time.

### D3: `VoiceComponent` attached only when needed
`EntityData` gains `voice_data: VoiceData` (mirrors `art_data` at EntityData.gd:294). `EntityFactory._add_components` (EntityFactory.gd:143) gains a conditional `_add_voice_component` that attaches `VoiceComponent` only when `data.voice_data` is set. `VoiceComponent.configure(data)` reads `data.voice_data` and stores it. The component exposes the voice set and its position for spatial playback.

*Alternatives:* no component, hooks reach into `get_node_or_null("VoiceComponent")`. The component exists to carry the reference and to keep select/order hooks uniform; entities without voice data simply lack the node.

### D4: Voice event hooks at existing choke points
- **Selection**: `SelectionManager.add_entity` (SelectionManager.gd:62) — after `set_is_selected(true)`, play `select` variant at the entity position. Guarded to local players only (selection already filters enemy units in the mouse path; `add_entity` is also used by the map editor, so gate on the entity having a `VoiceComponent`).
- **Order issue**: `MouseHandler._try_execute_orders` (MouseHandler.gd:269) and the ground-move branch (MouseHandler.gd:260-266) — after orders resolve and before/at `order.execute.call()`, map `OrderResult.cursor` → voice event and play once per selected unit. Mapping: `MOVE` → `move`; `ATTACK`, `HARVEST`, `ENTER`, `DEPLOY` → `attack`; all others → no voice.

The hooks live in the mouse/selection layer (not inside `OrderResolver`, which is a static helper) so voices fire exactly once per player action and follow the existing "signal up, call down" flow.

### D5: Combat and death sounds at existing choke points
- **Weapon fire**: `CombatComponent._fire_weapon` (CombatComponent.gd:178) — parse `weapon.sound_report` by comma, pick a random id, `AudioManager.play_sound(id, global_position)`. Empty string → skip silently.
- **Death**: connect to `HealthComponent.health_zero` (HealthComponent.gd:6) and play a death/explosion sound (`EXPNEW05` or similar) at the entity position.

These call `play_sound` directly — no `VoiceComponent`. Warhead-based explosion audio is deferred to the projectile system (non-goal).

### D6: Playback mechanics and buses
- `play_sound(id, position)` → resolve `AudioData` from cache → if missing or path fails to load → `push_warning` + return. If `is_spatial` and position given → `AudioStreamPlayer3D` (stream, `volume_db`, positioned, attached under `AudioManager`); else → `AudioStreamPlayer`. Both routed to the `AudioData.bus`.
- `play_voice(voice_id, event, position)` → resolve `VoiceData`, pick a random id from the event array, delegate to `play_sound`.
- `_ready()` ensures buses exist via `AudioServer.add_bus` when `Master`/`Music`/`SFX`/`Voice` are missing. A `default_bus_layout.tres` ships the layout so the editor shows the buses.
- Players are freed on `finished` (or via a `finished` signal connection) to avoid leaks.

*Alternatives:* a long-lived preloaded player pool. Rejected — unit/voice sounds are sparse; creating players per call and freeing on `finished` is simpler and matches the plan docs' "preload at startup" only as a later optimization.

### D7: Content authoring
Author `resources/audio/` `.tres` files from `external_assets/audio/` using `references/sound.ini` ids (lowercased filenames, uppercase ids in `.tres` to match `sound_report` values). Voice sets for existing GDI infantry/vehicle entities reference ids like `15-I000` family (generic infantry) and `25-I000` family (vehicles) per `rules.ini`. `default_bus_layout.tres` defines the four buses.

## Risks / Trade-offs

- [Spatial voices could be inaudible or positionally confusing] → Play select/order voices non-spatially if the unit is the camera focus, or keep them spatial but ensure the bus is loud enough. Start spatial (spec requirement); tune during playtesting.
- [Creating a player per call could accumulate nodes under heavy fire] → Free players on the `finished` signal; `AudioManager` owns them as children so cleanup is guaranteed.
- [274 audio `.tres` files is a lot of authored content] → Author only the sounds actually referenced now (weapon `sound_report` ids + voice sets used by existing entities), not all 274. Remaining ids added with #251.
- [`external_assets/` is gitignored — CI/test environments lack the `.ogg` files] → Tests must not require the real files; use `AudioData` with fake/missing paths and assert the graceful-failure path. Content `.tres` referencing absent files only warns, never crashes.
- [Buses created at runtime could double-create if layout already defines them] → `_ready()` checks `AudioServer.get_bus_index(name) == -1` before adding, and `default_bus_layout.tres` makes runtime creation a no-op in normal runs.

## Migration Plan

No backward-compatibility concern for packed scenes: `EntityData` gains an optional field (defaults to null), and entities without `voice_data` are unaffected. `AudioManager` is a new autoload — no existing behavior changes. Rollback is removing the autoload entry and the new files.
