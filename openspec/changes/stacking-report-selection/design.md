## Context

`CombatComponent._play_fire_sound` (scripts/components/CombatComponent.gd:275) splits `WeaponData.sound_report` on commas and plays `ids[randi() % ids.size()]` — a uniform per-shot random pick. AudioManager already tracks every live player per sound id in `_active_players_by_id` (scripts/core/AudioManager.gd:41), enforces a per-id retrigger window (`RETRIGGER_INTERVAL_MS`), and caps concurrent copies (`MAX_STACK_PER_ID = 12`, dropping the oldest). The bus-level loudness rebalancing (`_renormalize_bus`) treats all copies equally regardless of which report entry produced them.

Ground truth for the intended behavior comes from the original game, tested by hand: the first `Report=` entry is the individual report heard from a lone shooter; as weapon-fire SFX stacks, later entries are used "instead of the first, depending on the amount of weapon fire sfx stacking". ModEnc's `Report=` documentation records the observable result of the same mechanism (each unit appears to consistently play one sound). Our per-shot `randi()` produces neither: a lone unit cycles all entries, and stacking changes nothing.

Data is already in place from the #349 fix on this branch: `resources/weapons/minigun.tres` carries `SLVKGUN1,INFGUN3,GOSTGUN1` — same three sounds as `[Minigun] Report=` in `references/rules.ini:7359`, reordered so `SLVKGUN1` (the original's audible lone-shooter report) is the first entry — with `slvkgun1.tres`/`gostgun1.tres` AudioData added. Every other committed weapon has a single-entry report.

## Goals / Non-Goals

**Goals:**

- Reproduce the original stacking-driven report selection: earliest non-saturated entry wins; saturation rotates fire into later entries.
- Keep the selection stateless per shot — derive it entirely from AudioManager's existing live-copy counts, no per-unit caches or random seeds.
- Leave single-entry reports byte-for-byte identical in behavior to today's `play_sound` path.
- Make the selection unit-testable: deterministic given a controlled stack state.

**Non-Goals:**

- Per-unit report locking (the ModEnc "chosen once at creation" reading). The empirical stacking test supersedes it, and a stateless per-shot rule needs no component-lifetime plumbing.
- Retrigger-window-driven rotation (rotating as soon as entry 0 is retrigger-locked). Live-copy counting alone approximates stacking fine; the retrigger window stays a loudness/density control, not a selection signal.
- Changes to voice (`play_voice`) selection, which keeps its random variant pick — die/select chatter is genuinely random in the original.
- Data changes to any weapon `.tres`.

## Decisions

### Selection lives in AudioManager, not CombatComponent

`AudioManager.play_report(ids: PackedStringArray, position: Vector3)` walks the list: first id whose `_active_players_by_id` count is below `REPORT_STACK_PER_ID` plays via the existing `play_sound`; unknown ids (no AudioData) warn once and fall through; if all entries are saturated, the last entry plays.

Rationale: only AudioManager knows live counts; passing the list there keeps CombatComponent free of audio concerns and makes the rule testable by seeding stacks directly through `play_sound`. Alternatives rejected: a `get_active_count` query consumed by CombatComponent (splits one rule across two files); caching the choice per unit at spawn (state, plumbing, and contradicts the stacking test).

### Rotation threshold: `REPORT_STACK_PER_ID = 3`

An entry is "saturated" once it has 3 live copies. A lone unit re-firing inside the sample's lifetime (~1 copy live) always replays entry 0 — the "individual report". Squads add overlapping copies; from the 4th concurrent shot of entry 0, fire rotates to entry 1, and so on.

`ponytail:` knob, tune from playtesting. Deliberately well below `MAX_STACK_PER_ID = 12` so rotation happens long before the hard cap starts dropping oldest copies.

### CombatComponent passes the raw list

`_play_fire_sound` keeps only the empty-check and split, then calls `play_report`. Edge-stripping moves into `play_report` (it owns sound ids; `play_voice` already passes pre-clean ids).

### Bus loudness rebalancing is untouched

`_renormalize_bus` already sums N concurrent copies — same or different ids — to one copy's loudness. Report rotation changes *which* ids stack, not how stacks are balanced. No interaction risk beyond re-running the existing tests.

## Risks / Trade-offs

- [Threshold feel is a guess until playtested] → `REPORT_STACK_PER_ID` is a named constant with the ponytail knob comment; tuning is a one-line change.
- [All-saturated fallback plays the last entry, which may itself exceed `MAX_STACK_PER_ID` and drop an oldest copy] → pre-existing behavior of `play_sound`, unchanged; dropping the oldest copy is the current policy for any over-cap play.
- [Unknown-id fall-through could mask a typo'd data id in a long list] → each unknown id warns once via the existing `push_warning` in `play_sound`'s path; `slvkgun1`/`gostgun1` AudioData are committed on this branch, so the minigun list resolves fully.
- [Stateless selection can alternate a single unit's sound across shots when neighbors fire in bursts] → with threshold 3 and the 100 ms retrigger window, a lone unit practically never leaves entry 0; burst-heavy stacks rotating entries is the desired original behavior.

## Migration Plan

Single commit on `fix/349-light-infantry-wrong-weapon-sound` together with the data rewiring already in the working tree. No scene or data migration; rollback is reverting the two scripts. CI (gdlint/gdformat + headless suite) gates the merge like any other change.

## Open Questions

(none — threshold and fallback were settled on the last entry; both are one-line tweaks if playtesting disagrees)
