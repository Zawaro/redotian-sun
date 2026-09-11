## 1. Data Model Fields

- [x] 1.1 Add `sound_impact: String = ""` to `scripts/data/WarheadData.gd` under a doc comment describing the comma-separated report convention (mirrors `WeaponData.sound_report`).
- [x] 1.2 Add `sound_die: String = ""` to `scripts/data/EntityData.gd` under a doc comment describing the comma-separated death-report convention and its independence from `voice_data`.
- [x] 1.3 Confirm existing `.tres` warhead/entity files still load with the new fields defaulting to `""` (no data migration).

## 2. Warhead Impact Playback

- [x] 2.1 In `EntityFactory.create_entity`, connect `HealthComponent.damage_taken` to a handler (e.g. `_on_entity_damaged(entity, damage_type)`) alongside the existing `health_zero` connection.
- [x] 2.2 Implement `EntityFactory._on_entity_damaged(entity, damage_type)`: resolve `GlobalRules.get_current().get_warhead(damage_type)`; when a warhead with non-empty `sound_impact` resolves, call `AudioManager.play_report(sound_impact.split(",", false), entity.global_position)`.
- [x] 2.3 Ensure non-warhead damage types (crush, drowning, empty) resolve to no warhead and play nothing with no warning.

## 3. Unvoiced Death Playback

- [x] 3.1 Change `EntityFactory._on_entity_death(entity, data: EntityData = null)` and pass the created `data` through the `health_zero` lambda in `create_entity`.
- [x] 3.2 In `_on_entity_death`, keep the existing die-voice branch; when the voice is absent or its die event is empty, play `data.sound_die` through `AudioManager.play_report` at the entity position when non-empty; otherwise stay silent.
- [x] 3.3 Verify `BuildingManager._on_building_destroyed` remains registry-only (no audio), so building destruction plays exactly one death sound.

## 4. Content Wiring (Placeholders)

- [x] 4.1 Author placeholder `AudioData.tres` for the mission explosion ids referenced by this change (e.g. `EXPNEW01`, `EXPNEW05`, `EXPNEW06`) under `games/ts/audio/`, `bus = "SFX"`, path pointing at `res://games/ts/external_assets/audio/<id>.ogg` (resolves at C5, silent until then).
- [x] 4.2 Set `sound_impact` on the warheads used by gdi1a weapons (e.g. `sa.tres`, `ap.tres`, `artyhe.tres`, `hollowpoint.tres`) to the appropriate explosion id.
- [x] 4.3 Set `sound_die` on unvoiced structure/defense entity data (and any unvoiced vehicle that lacks a `VoiceData.die`) to the appropriate explosion id.
- [x] 4.4 Confirm `gdi_vehicle_voice.tres` die entry (`EXPNEW05`) still resolves now that the AudioData exists, and that no entity plays both a die voice and `sound_die`.

## 5. Tests

- [x] 5.1 Unit: `WarheadData.sound_impact` defaults to `""` and round-trips a comma-separated value.
- [x] 5.2 Unit: `EntityData.sound_die` defaults to `""` and round-trips a comma-separated value.
- [x] 5.3 Unit: a damaging hit with a warhead whose `sound_impact` resolves spawns an `AudioManager` player on the `SFX` bus at the victim position; the test swaps in the committed `test/fixtures/audio/test_tone.wav` fixture (do not depend on `games/ts/external_assets/`).
- [x] 5.4 Unit: a hit whose `damage_type` is not a registered warhead (e.g. crush) spawns no player.
- [x] 5.5 Unit: an unvoiced building with `sound_die` set plays the death sound on zero health.
- [x] 5.6 Unit: an entity with both a die voice and `sound_die` plays only the die voice (regression for precedence).
- [x] 5.7 Unit: an entity with neither die voice nor `sound_die` is silent and frees normally.
- [x] 5.8 Unit: a missing/unknown `sound_impact` or `sound_die` id warns and does not raise.
- [x] 5.9 Regression: the existing weapon-fire report and die-voice tests still pass unchanged (#242/#349 behavior preserved).

## 6. Weapon Report Wiring

- [x] 6.1 Populate `WeaponData.sound_report` for every weapon whose report was empty, using the `Report=` values from `references/rules.ini` (24 weapons).
- [x] 6.2 Correct `minigun`'s report order to the reference order (`INFGUN3,GOSTGUN1,SLVKGUN1`), which changes the primary fire report.
- [x] 6.3 Author committed `AudioData.tres` for the newly referenced weapon report ids under `games/ts/audio/`.
- [x] 6.4 Add `test_weapon_sfx_wiring.gd` freezing the rules.ini weapon→report mapping and asserting every report id resolves to a committed `AudioData`.

## 7. External Asset Relocation

- [x] 7.1 Move the gitignored `external_assets/` tree to `games/ts/external_assets/`.
- [x] 7.2 Rewrite all `res://external_assets/` references in tracked `.tres` files to `res://games/ts/external_assets/`.
- [x] 7.3 Keep `.gitignore` matching `external_assets/` at any depth and update `plans/` references.

## 8. Verification

- [x] 8.1 Run `redot --headless -s test/run_tests.gd` and confirm all tests pass.
- [x] 8.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`.
- [x] 8.3 After `gdformat`, run `grep -P '\t' scripts/**/*.gd` and confirm no tabs were introduced.
