## 1. Data Resources

- [x] 1.1 Create `scripts/data/AudioData.gd` (extends Resource): `id`, `path`, `bus`, `priority`, `volume_db`, `is_spatial` exports with defaults (bus=`SFX`, priority=10, is_spatial=true)
- [x] 1.2 Create `scripts/data/VoiceData.gd` (extends Resource): `id` plus `select`/`move`/`attack`/`die`/`feedback` as `Array[String]` exports; add a helper `get_event(event_name) -> Array[String]`
- [x] 1.3 Create `default_bus_layout.tres` at project root defining Master/Music/SFX/Voice buses
- [x] 1.4 Register `AudioManager` autoload in `project.godot` `[autoload]`

## 2. AudioManager

- [x] 2.1 Create `scripts/core/AudioManager.gd` (extends Node): `_ready()` ensures the four buses exist via `AudioServer.add_bus` when missing, then registers `res://resources/audio/`
- [x] 2.2 Implement `register_data_set(path)` (idempotent per path) and `_scan_directory(path)` mirroring `EntityFactory._scan_directory` (recursive, caches `AudioData`/`VoiceData` by `id`, missing dir → `push_warning` + return)
- [x] 2.3 Implement `play_sound(id, position)` — resolve `AudioData` from cache, load stream, missing id or failed load → `push_warning` + return; spatial (`AudioStreamPlayer3D`) vs non-spatial (`AudioStreamPlayer`) by `is_spatial`/position; apply `volume_db` and `bus`; free player on `finished`
- [x] 2.4 Implement `play_voice(voice_id, event, position)` — resolve `VoiceData`, pick random variant from the event array, delegate to `play_sound`; empty/missing event → silent return
- [x] 2.5 Implement `get_audio_data(id)` / `get_voice_data(id)` accessors for tests and hooks
- [x] 2.6 Add `_inject_autoloads` support in `test/run_tests.gd` for `AudioManager` (e.g. `_am` shorthand)

## 3. VoiceComponent and Entity Wiring

- [x] 3.1 Create `scripts/components/VoiceComponent.gd` (Node, script-only like `StatsComponent`): `@export var voice_data: VoiceData`, `configure(data: EntityData)` sets it from `data.voice_data`
- [x] 3.2 Add `voice_data: VoiceData` export field to `scripts/data/EntityData.gd` (Art group)
- [x] 3.3 Add `_add_voice_component(entity, data)` to `EntityFactory.gd` and call it conditionally in `_add_components` when `data.voice_data` is set
- [x] 3.4 Add `VoiceComponent` preload const to `EntityFactory.gd`

## 4. Voice Event Hooks

- [x] 4.1 Hook select voice in `SelectionManager.add_entity`: after selecting, resolve the entity's `VoiceComponent` and play a `select` variant at the entity position
- [x] 4.2 Hook order voice in `MouseHandler._try_execute_orders` and the ground-move branch: map `OrderResult.cursor` → voice event (`MOVE`→`move`; `ATTACK`/`HARVEST`/`ENTER`/`DEPLOY`→`attack`) and play once per selected unit
- [x] 4.3 Ensure order/select voices only play for local players' units (entities with a `VoiceComponent` and non-enemy stats)

## 5. Combat and Death Sounds

- [x] 5.1 Play weapon fire sound in `CombatComponent._fire_weapon`: split `weapon.sound_report` by comma, pick a random id, `play_sound(id, global_position)`; empty string → silent
- [x] 5.2 Play death/explosion sound on `HealthComponent.health_zero` at the dying entity's position

## 6. Content and Tests

- [x] 6.1 Author `AudioData.tres` files under `resources/audio/` for weapon `sound_report` ids (e.g. `INFGUN3`, `CHAINGN1`, `120MMF`) and generic infantry/vehicle voice ids (`15-I000` family, `25-I000` family) using `references/sound.ini` id mapping
- [x] 6.2 Author `VoiceData.tres` files for existing GDI infantry/vehicle entities per `references/rules.ini` `VoiceSelect`/`VoiceMove`/`VoiceAttack` variants; set `voice_data` on the matching `EntityData.tres`
- [x] 6.3 Write unit test `test/unit/test_audio_data.gd`: AudioData/VoiceData defaults, event lookup, variant arrays
- [x] 6.4 Write unit test `test/unit/test_audio_manager.gd`: directory scan caches by id, idempotent re-register, missing dir warns, `play_sound` with unknown id silently warns (no crash), `play_voice` empty event silent, sound routes to declared bus, `sound_report` comma-list pick
- [x] 6.5 Write unit test for `VoiceComponent`: attached only when `voice_data` set, absent otherwise
- [x] 6.6 Write integration test for select/order voice routing (mock `AudioManager`, assert event called with expected variants); test weapon fire with multi-id `sound_report`
