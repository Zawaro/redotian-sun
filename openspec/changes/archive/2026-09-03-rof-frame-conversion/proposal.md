## Why

Weapon fire cadence is 4x slower than the original game. `CombatComponent` converts `WeaponData.rate_of_fire` with `60.0 / rof` (treating it as shots per minute), but Tiberian Sun's `ROF=` is a rearm delay in engine frames at 30 fps logic (ModEnc, ROF, TS=yes): `seconds_between_shots = ROF / 30`. The light-infantry Minigun (ROF=21) therefore fires every 2.86 s instead of the original 0.7 s. The weapon `.tres` data itself matches `references/rules.ini` exactly — only the conversion is wrong. Surfaced by playtesting on the #349 branch after the weapon rewiring made light-infantry cadence directly audible.

## What Changes

- Fix the cooldown conversion in `CombatComponent._fire_weapon`: `weapon.rate_of_fire / 30.0` seconds instead of `60.0 / weapon.rate_of_fire`, via a named `TS_LOGIC_FPS` constant.
- Correct the `WeaponData.rate_of_fire` doc comment, which documents the wrong semantics ("shots per minute, ROF = 60 / seconds_between_shots").
- Update the `combat-firing` spec requirement "Fire rate cooldown per weapon" and its timing scenario to the frame-based formula.
- No weapon data changes: every committed `.tres` already carries the faithful rules.ini ROF value, so all weapons' cadence becomes faithful to the original with one formula fix.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `combat-firing`: The "Fire rate cooldown per weapon" requirement changes from `60.0 / weapon.rate_of_fire` seconds (ROF interpreted as shots per minute) to `weapon.rate_of_fire / 30.0` seconds (ROF interpreted as TS rearm-delay frames at 30 fps logic).

## Impact

- `scripts/components/CombatComponent.gd` — one cooldown line plus one constant.
- `scripts/data/WeaponData.gd` — doc comment only.
- `openspec/specs/combat-firing/spec.md` — requirement text and one scenario's numbers.
- `test/unit/test_combat_component.gd` — new regression test pinning the conversion (ROF=30 → 1.0 s); no existing test asserts the old formula.
- Gameplay ripple: all weapon cadences align with the original game (e.g. M1Carbine ROF=20 → 0.67 s, Bazooka ROF=60 → 2.0 s per rocket). Higher fire density is already governed by the AudioManager retrigger window, per-id stack cap, and stacking-driven report selection.
