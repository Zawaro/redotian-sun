## Context

Combat audio today has two working layers and two missing ones:

```
WeaponData.sound_report ──► CombatComponent._fire_weapon ──► AudioManager.play_report   ✅
VoiceData.die            ──► EntityFactory._on_entity_death ─► AudioManager.play_voice  ✅
WarheadData (no field)   ──► ???                                                        ❌ impact
EntityData (no field)    ──► ???                                                        ❌ unvoiced death
```

Damage reaches `HealthComponent.take_damage(damage, damage_type)` through two paths — hitscan (`CombatComponent._apply_hitscan_damage`) and projectile (`ProjectileController._detonate_on` → `HitboxComponent.receive_damage_source`) — and `HealthComponent` emits `damage_taken(amount, damage_type)` where `damage_type` carries the warhead id. `EntityFactory` already connects `health_zero` per entity to play the die voice; `BuildingManager` listens to the same signal for registry cleanup only. `AudioManager.play_report(ids, position)` already provides stacking-driven id rotation, per-id retrigger throttling, and graceful fall-through for unknown ids.

`entities/EntityFactory.create_entity` is the single creation path for units **and** buildings (`BuildingManager` calls it), so a death/impact listener wired there covers every entity.

`GameContext` provides the active rules; `GlobalRules.get_current().get_warhead(id)` resolves warhead data at runtime.

## Goals / Non-Goals

**Goals:**
- Play a warhead impact report on every damaging hit, spatially at the victim/impact point.
- Play a death sound for entities that have no die voice set (buildings, defenses, unvoiced units).
- Reuse `AudioManager`'s existing playback semantics — no new audio subsystem or API.
- Keep missing SFX non-fatal: warn, stay silent, continue gameplay.
- Define the new data fields so data files stay backward-compatible (empty defaults).

**Non-Goals:**
- Re-implementing weapon fire SFX or die-voice playback (#242/#349 already shipped them).
- Armor-type-specific impact sounds (the #243 wording "per WarheadData/armor interaction"); one impact report per warhead is sufficient for the mission.
- Visual impact/explosion effects — that is #321 / #186.
- Real audio asset import — C5 (#251); this change authors placeholder `AudioData` wiring only.
- A global size→sound table; death sound is per-entity data.

## Decisions

### Decision 1: Trigger impact SFX at the damage funnel, not the shot sites
Connect `HealthComponent.damage_taken` in `EntityFactory.create_entity` and play the resolved warhead's `sound_impact` at the entity's position.

- **Why:** `damage_taken` is the single funnel both hit paths already carry the warhead id through. One connection covers hitscan, projectile, and any future damage source (splash, ambient) with no per-site duplication. It also keeps `HealthComponent` free of an audio dependency (signal-up, call-down).
- **Alternative rejected:** play at `CombatComponent._apply_hitscan_damage` and `ProjectileController._detonate_on` (or the unused `ProjectileController.impacted` signal). Shot-accurate and fires once per shot, but two call sites that already disagree on the warhead type plumbing, and every new damage source must remember to add a third.
- **Alternative rejected:** play inside `HealthComponent.take_damage`. Fewest lines, but couples a low-level stat component to `AudioManager` and `GlobalRules`.

### Decision 2: Impact data lives on `WarheadData.sound_impact`
A comma-separated id list, shaped like `WeaponData.sound_report`, fed to `AudioManager.play_random` (random pick among the known ids).

- **Why:** the issue assigns impact to the warhead; reusing the report-list shape means the field gets graceful unknown-id handling for free. Impacts are one-shots, so random selection matches the original `AnimList` behavior better than weapon-fire stacking rotation. The values are derived from each warhead's `AnimList` animations' `Report=` in `references/art.ini` (source of truth), not hand-picked.
- **Alternative rejected:** `ProjectileData.sound_impact` — protrudes only for projectile weapons; hitscan and AoE would need a parallel field.
- **Alternative rejected:** armor-type-specific impact sounds — added data authoring and per-victim sound selection for marginal gain; revisit only if playtests demand it.

### Decision 3: Death sound lives on `EntityData.sound_die`, with voice precedence
`_on_entity_death(entity, data)` plays `VoiceData.die` when present, else `EntityData.sound_die`.

- **Why:** infantry already encode their death in `VoiceData.die` (`DEDMAN*`/`DEDGIRL*` per the reference), so the existing path is left untouched. `sound_die` is derived from the entity's `Explosion=` animations' `Report=` in `references/art.ini`, covering vehicles and buildings. Vehicles have no `VoiceDie` in the reference, so the vehicle voice set's hand-added `EXPNEW05` die entry is cleared and vehicle deaths use `sound_die`. Explicit per-entity data beats a derived size heuristic.
- **Alternative rejected:** a `GlobalRules` size→sound table keyed off `hitbox_size` — less authoring, but coarse and hard to override per structure.
- **Alternative rejected:** always play an explosion alongside the die voice — double-sounds units and contradicts the existing "die voice" requirement.

### Decision 4: Resolve warhead data at play time via `GlobalRules`
The impact handler looks up `GlobalRules.get_current().get_warhead(damage_type)` and treats a miss (crush, drowning, empty type) as silent.

- **Why:** reuses the existing registry, makes non-weapon damage silent by construction, and avoids per-entity caching of warhead resources. Fall-through is the same graceful-failure contract as `play_random`.

### Decision 5: Content is placeholder wiring, not assets
Author `AudioData.tres` entries for every referenced explosion id (`EXPNEW01`–`EXPNEW15` as used) pointing at `res://games/ts/external_assets/audio/<id>.ogg`, and set ids on warhead and weapon-related entity data.

- **Why:** `games/ts/external_assets/` is gitignored, so a missing path already degrades to a warning + silence via `AudioManager`. Wiring the ids now means C5 (#251) only has to drop in the files. Tests verify playback against the committed `test/fixtures/audio/test_tone.wav`, matching the `test_entity_death` fixture pattern.

### Decision 6: `_on_entity_death` gains an optional `data` parameter
`func _on_entity_death(entity: Node3D, data: EntityData = null) -> void`, with the `health_zero` lambda passing the created `data`.

- **Why:** preserves existing direct callers (`test_entity_death` calls `EntityFactory._on_entity_death(entity)`), which then simply skip the `sound_die` fallback. No call-site churn.

### Decision 7: Weapon report data is in this change's scope
Populate empty `WeaponData.sound_report` values from `references/rules.ini`, and correct `minigun`'s order to the reference value `INFGUN3,GOSTGUN1,SLVKGUN1`.

- **Why:** #243 spans "weapon fire, warhead impact, death". The playback system existed, but 24 weapons carried an empty report, so their fire was silent. The minigun reorder is intentional and changes the primary fire report because `play_report` plays the first entry; it matches `rules.ini [Minigun] Report=`. `test_weapon_sfx_wiring.gd` freezes the full weapon→report mapping so the reference contract is explicit.

### Decision 8: SFX values and weapon attachments are derived from the reference
Warhead `sound_impact` is derived from each warhead's `AnimList` animations' `Report=` (`references/art.ini`); entity `sound_die` is derived from each entity's `Explosion=` animations' `Report=`. Entities whose reference section defines `Primary=`/`Secondary=` but carried no `weapons` get those weapons attached.

- **Why:** the previously hand-picked ids did not match the reference (e.g. `SA` small arms is silent, `AP` is `EXPNEW14`, the default vehicle/building death is `EXPNEW09,11,12,14,15`; `EXPNEW01` is the `[General] BlowupSound`, not a death sound). Deriving from `rules.ini`/`art.ini` makes the data audibly correct and testable. Attaching weapons is required or most warhead impacts can never fire.
- **Alternative rejected:** approximate ids by sound.ini prose labels ("BIG BUILDING EXPLOSION") — plausible but not the actual wiring the reference uses.
- **Alternative rejected:** a `GlobalRules` default death sound — the reference has no global default; each entity carries its own `Explosion=`.

## Risks / Trade-offs

- **AoE damage (future #323) plays one impact sound per victim, not once at the blast center** → the per-id retrigger window (`RETRIGGER_INTERVAL_MS`) collapses same-id duplicates within 100 ms, so a single explosion reads as one sound. Revisit if blast-center positioning matters.
- **A killing hit plays both the impact report and the death sound** → intended; a lethal hit should read as impact + destruction. If it doubles too loud, the `sound_die` id set is the tuning knob.
- **Zero-damage hits are silent** because `take_damage` early-outs before emitting `damage_taken` → acceptable; there is no ricochet effect to sound.
- **Two `health_zero` listeners exist for buildings (EntityFactory and BuildingManager)** → only `EntityFactory._on_entity_death` plays audio, so no double play; the BuildingManager handler stays registry-only.
- **The `audio-system` main spec is currently missing its `## Purpose` headers** (pre-existing debt surfaced by `openspec validate`) → out of scope here; the delta adds requirements without reworking the main file.

## Migration Plan

- Additive data fields with empty defaults: existing `.tres` warheads and entities load unchanged and stay silent until ids are authored.
- No scene or `project.godot` changes.
- Rollback is reverting the field reads; data files with the new fields remain harmless.

## Open Questions

- Which explosion ids map to which structure class for the mission (tiny/medium/large)? Resolved during data authoring in the tasks phase, pending the C5 asset set.
- Should the impact report also sound on projectile fizzle (no victim)? Currently no damage → no impact sound.
