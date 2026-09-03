## Context

`CombatComponent._fire_weapon` (scripts/components/CombatComponent.gd:226) sets the post-shot cooldown to `60.0 / weapon.rate_of_fire`. The `WeaponData.rate_of_fire` doc comment (scripts/data/WeaponData.gd:12) codifies the same misreading: "shots per minute... TS formula: ROF = 60 / seconds_between_shots". The committed weapon data is a verbatim port of `references/rules.ini` (Minigun ROF=21, M1Carbine ROF=20, Bazooka ROF=60, ...), so every weapon currently fires at 1/4 the original cadence — Minigun 2.86 s between shots instead of 0.7 s.

The original engine semantics, per ModEnc's `ROF=` documentation (TS=yes): ROF is "how many frames the firer cannot fire after the last shot". TS logic ticks at 30 fps, so `seconds_between_shots = ROF / 30`. ModEnc also documents RearmDelay refinements (burst-index delays of 3-5 frames mid-burst, +0-2 random frames on the last burst shot, ROFMultiplier per country/difficulty, VeteranROF); our engine models none of these, and none are needed for the single-shot (Burst=1) cadence this change fixes.

The `combat-firing` spec (openspec/specs/combat-firing/spec.md:21-27) pins the wrong formula in both the requirement text and the "Fire rate timing" scenario, so the spec must move with the code.

## Goals / Non-Goals

**Goals:**

- Faithful TS fire cadence for every weapon: `seconds_between_shots = rate_of_fire / 30.0`.
- One named constant for the 30 fps logic rate, so the conversion has a single readable source of truth.
- Spec, doc comment, and code agree after this change.

**Non-Goals:**

- Mid-burst BurstDelay randomness (3-5 frame delays between burst shots) — Burst=1 weapons are unaffected and burst>1 weapons already loop through their own burst logic.
- The +0-2 random frames ModEnc adds to the last burst shot — jitter, not cadence.
- `ROFMultiplier` / `VeteranROF` application — `GlobalRules.veteran_rof` exists but is unused by CombatComponent today; wiring it is future work, and the new formula leaves a clean place for it (multiply the computed cooldown).
- Any `.tres` retuning — data already matches rules.ini.

## Decisions

### Constant `TS_LOGIC_FPS: float = 30.0` in CombatComponent

`_cooldowns[...] = weapon.rate_of_fire / TS_LOGIC_FPS`. Rationale: the formula reads as a frame-to-seconds conversion next to the constant it needs; alternatives rejected — a magic `30.0` inline (unexplained), a GlobalRules entry (nothing else about engine tick rate lives there; a const is not a playtest knob here since 30 fps is the original's fixed logic rate, not a tuning dial).

### ROF stays "frames" in WeaponData

The field keeps holding the rules.ini value verbatim (Minigun 21, not 0.7). Only the doc comment changes: "TS ROF rearm-delay frames (logic 30 fps); seconds_between_shots = ROF / 30". Rationale: `.tres` files stay diff-free against rules.ini, making future data audits a straight comparison.

## Risks / Trade-offs

- [Fire density rises 4x across all weapons] → AudioManager already bounds density: 100 ms retrigger window per id, `MAX_STACK_PER_ID` cap, bus loudness rebalancing, and stacking-driven report rotation. Sound stacks will now exercise the rotation path regularly, which is the intended original feel.
- [Projectile spam from faster fire] → projectiles are spawned per shot with the same path as today; no pooling assumptions exist in ProjectileController. If playtesting shows load, that is a rendering-budget concern, not this change.
- [Someone hand-tuned a weapon .tres ROF under the old formula] → verified: all committed ROF values match rules.ini verbatim (checked Minigun 21 and M1Carbine 20); a repo-wide diff against references/rules.ini is part of the tasks as a safety net.

## Migration Plan

Single commit on the #349 branch after the stacking-report-selection change. No data migration, no scene changes; rollback is a one-line revert. CI (headless suite + lint) gates as usual.

## Open Questions

(none)
