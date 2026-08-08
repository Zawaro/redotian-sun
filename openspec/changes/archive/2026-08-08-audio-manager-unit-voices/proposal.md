## Why

There is no audio system (only a stray reference in BuildingManager). The mission needs unit feedback voices — selecting a unit and issuing it an order must produce an audible response, as in Tiberian Sun ("Sir, yes sir!", vehicle reports, etc.). The audio content already exists in `external_assets/audio/` (275 `.ogg` files, every one matching a `sound.ini` `[SoundList]` ID), and weapons already carry `sound_report` IDs (`WeaponData.sound_report`, e.g. `INFGUN3`) that nothing plays yet. This change lays the engine-level audio foundation and wires up unit select/order voices (GH #242).

## What Changes

- Add `AudioManager` autoload: dynamic `.tres` loader (mirrors `EntityFactory._scan_directory`), audio buses (Master/Music/SFX/Voice), event-driven playback (`play_sound`, `play_voice`).
- Add `AudioData` resource — one `.tres` per sound file: id, path, bus, priority, volume, spatial flag.
- Add `VoiceData` resource — standalone voice set keyed by `id`: event (`select`/`move`/`attack`/`die`/`feedback`) → list of audio IDs (variants picked at random).
- Add `VoiceComponent` — optional per-entity holder, attached only when `EntityData.voice_data` is set (mirrors `ArtComponent`).
- Play select voice on unit selection (`SelectionManager.add_entity`) and order voice on order issue (`MouseHandler._try_execute_orders`), mapping `OrderResult.cursor` → voice event.
- Play weapon fire sounds via `WeaponData.sound_report` at the existing `CombatComponent._fire_weapon` choke point; death/explosion sounds via the `HealthComponent.health_zero` signal.
- Missing audio ID or failed load → `push_warning` + silent return (no crash when a unit has no voice data).
- Author real content `.tres` files in `resources/audio/` from the available audio library.

## Capabilities

### New Capabilities
- `audio-system`: AudioManager autoload with dynamic `.tres` loader, bus management, and event-driven sound/voice playback with graceful failure.

### Modified Capabilities
<!-- None — no existing spec's requirements change. -->

## Impact

- New autoload registered in `project.godot` (`AudioManager`).
- New resource scripts: `scripts/data/AudioData.gd`, `scripts/data/VoiceData.gd`.
- New component: `scripts/components/VoiceComponent.gd`.
- Modified: `EntityData.gd` (+`voice_data` field), `EntityFactory.gd` (attach VoiceComponent), `SelectionManager.gd` (select voice), `MouseHandler.gd` (order voice), `CombatComponent.gd` (fire sound), `HealthComponent.gd` consumer (death sound).
- New `default_bus_layout.tres` (Master/Music/SFX/Voice buses).
- New content: `resources/audio/*.tres` (one per sound + one per voice set).
- Audio files imported from `res://external_assets/audio/` (gitignored — copyrighted EA assets, imported locally only).
