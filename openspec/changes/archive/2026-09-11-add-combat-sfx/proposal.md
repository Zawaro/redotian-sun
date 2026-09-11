## Why

Combat today plays weapon fire reports (`WeaponData.sound_report`) and die voices (`VoiceData.die`), but hits and unvoiced destructions are silent. `WarheadData` carries no impact sound, and entities without a `VoiceData` — buildings, defenses, and other unvoiced entities — have no death sound at all. The `audio-system` spec explicitly defers this layer ("Explosion/effect SFX for unvoiced entities SHALL be assigned in a future issue") — that future issue is #243.

## What Changes

- Add `WarheadData.sound_impact: String` — a comma-separated audio id list using the same convention as `WeaponData.sound_report`.
- Add `EntityData.sound_die: String` — a comma-separated audio id list for entities that have no `VoiceData.die` set.
- On every damaging hit, play the warhead's impact report spatially at the victim position through `AudioManager.play_report` (reusing stacking rotation and graceful failure).
- Extend the death handler: play `VoiceData.die` when present, otherwise play `EntityData.sound_die`, otherwise nothing.
- Populate `WeaponData.sound_report` for weapons whose report was empty, using the `Report=` values in `references/rules.ini`; `minigun`'s report order is corrected to the reference order.
- Author `AudioData.tres` for the referenced explosion ids and for every newly wired weapon report id, so the ids resolve once the assets are present.
- Relocate the gitignored `external_assets/` tree to `games/ts/external_assets/` and rewrite all `res://` references, scoping assets per game and clearing the repo root.
- Weapon fire playback and die-voice plumbing already exist (#242/#349); this change wires the missing weapon report data and adds the impact/death layer — it does not re-implement the playback system.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `audio-system`: add requirements for warhead impact SFX and unvoiced destruction SFX, fulfilling the previously deferred "future issue" for unvoiced destruction.
- `entity-data`: add the `sound_die` field to the `EntityData` resource class.

## Impact

- **Data:** `scripts/data/WarheadData.gd` (new `sound_impact`), `scripts/data/EntityData.gd` (new `sound_die`).
- **Runtime:** `scripts/entities/EntityFactory.gd` (damage listener + death fallback), reusing `scripts/core/AudioManager.gd` (`play_report`) and `GlobalRules.get_warhead`.
- **Content:** `games/ts/audio/` (explosion and weapon-report `AudioData.tres`); `games/ts/weapons/*.tres` (`sound_report`); `games/ts/warheads/*.tres` (`sound_impact`); unvoiced structure/vehicle `.tres` (`sound_die`).
- **Assets/repo:** `external_assets/` moved under `games/ts/`; `res://` references, `.gitignore`, and `plans/` docs updated to the new path.
- **Tests:** `test_weapon_sfx_wiring.gd`, `test_combat_sfx.gd`, `test_entity_data.gd`, and `test_warhead_data.gd` coverage.
- **Compatibility:** no `.tscn` changes; existing `.tres` files remain loadable (new fields default empty); missing SFX degrades to silence with a warning, as today.
