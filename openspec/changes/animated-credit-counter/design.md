## Context

The sidebar credit Label currently updates instantly on `EconomyManager.credits_changed`, and `EconomyAudioListener` (autoload, #266) plays `ECON_INCOME`/`ECON_SPEND` once per economy event, gated by a reason-string allowlist (`harvest`, `sell:*`, `build:*`, `prod:*`). Classic RTS money displays instead animate the counter toward the new balance with a tick per displayed step, counting up faster than down. AudioManager already provides retrigger throttling (per-id, overridable per `AudioData` — both econ sounds carry a 50 ms override) and the SFX loudness ceiling, so rapid ticking is safe to emit naively.

Constraints: signal-up/call-down (children emit, parents react); frame-rate-independent timing; tests run headless with the custom runner; audio files live in gitignored `external_assets/` and may be absent in CI — `AudioManager` warns and continues.

## Goals / Non-Goals

**Goals:**
- Counter that steps toward the target balance with direction-dependent cadence and proportional step size
- One tick sound per displayed step, direction choosing the id
- Single owner for display + tick behavior; delete the now-redundant event-driven listener

**Non-Goals:**
- No announcer/EVA-style voice feedback for economy states (no such system exists yet)
- No changes to `EconomyManager` API, signals, or the `AudioData` resources
- No per-player counter for spectated/allied balances — local player only, as today

## Decisions

1. **Counter state lives in `Sidebar`, not a new autoload or EconomyManager.** Direction and cadence are presentation concerns derived from how the *displayed* value moves; the ledger must stay a pure ledger. Sidebar already owns the Label and the local-player filter.
   - *Alternative considered*: keep `EconomyAudioListener` as the tick driver — rejected: it would have to duplicate the counter's target/displayed state to know when steps occur, and keeping both playback paths double-plays every tick.

2. **Direction comes from displayed-value movement, not reason strings.** `sign(target - displayed)` replaces the `INCOME_EXACT`/prefix allowlists. Cheaper, no two-sources-of-truth, and debug-cheat credits animate like any other gain (correct UI feedback — the number did go up). The allowlist's "enemy events stay silent" guarantee is preserved by the existing local-player check.
   - *Trade-off*: the reason allowlist's finer discrimination (e.g. silent categories) is lost. Nothing currently uses it.

3. **Time-based cadence, not frame counting.** Honor `frame-rate-independent-timing`: the step loop accumulates delta and steps when the elapsed time exceeds the direction's interval. Constants in `Sidebar` as playtest knobs (with `ponytail:` markers): `GAIN_STEP_INTERVAL = 0.0`, `SPEND_STEP_INTERVAL = 0.05`, `STEP_DIVISOR = 8`, `MIN_STEP = 1`, `MAX_STEP = 143`. These reproduce the classic feel at 60 fps; every knob is tunable without touching logic.
   - *Alternative considered*: per-animation fixed tick rate — rejected: loses the fast-up/slow-down contrast that carries the feel.

4. **Proportional step with clamp.** `step = clamp(abs(gap) / STEP_DIVISOR, MIN_STEP, MAX_STEP)`; sign applied toward the target. Sub-linear animation length for large dumps/purchases; MIN_STEP guarantees termination on odd balances; MAX_STEP caps the per-frame jump so tiny gaps still get a few ticks.

5. **Step loop as a separately callable method.** `_step_counter(delta: float)` contains the accumulate/step/play logic; `_process` just forwards delta and is disabled (`set_process(false)`) whenever displayed == target. Tests drive `_step_counter` directly with synthetic deltas — deterministic headless tests, no real-frame awaits, no time-mocking.

6. **Delete `EconomyAudioListener` and its autoload entry.** Its entire behavior is subsumed. Migration: its tests (`test/unit/test_economy_audio.gd`) are rewritten against the sidebar counter; `project.godot` loses one autoload (23 → 22); AGENTS.md autoload table updated.

## Risks / Trade-offs

- [Perceived tick density depends on `retrigger_ms`] → At full-rate gain stepping the 50 ms retrigger override drops ~2 of 3 tick requests; that still reads as a burst. If playtesting wants denser ticks, lower `retrigger_ms` on `econ_income.tres` — a data change, not code.
- [CI lacks the `.ogg` files] → `play_sound` already warns-and-continues; the counter must animate regardless of playback outcome (test asserts animation with a missing-file id).
- [Existing tests assert instant label equality] → `test_sidebar_credits.gd` assertions move to "settles at target"; the spec's forced-display scenario keeps a deterministic instant-equality case for ready/resync.
- [`_process` on a Control] → Negligible: processing is enabled only mid-animation and disabled on settle.

## Migration Plan

Single branch: rework Sidebar counter, delete listener, rewrite tests, update `project.godot` + AGENTS.md. Rollback = revert the branch; no data or save-format involvement.

## Open Questions

None — cadence/step constants ship as documented knobs.
