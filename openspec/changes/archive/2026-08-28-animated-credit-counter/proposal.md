## Why

The HUD credit counter currently jumps straight to the new balance, and credit sounds fire once per economy event. Classic RTS credit displays do neither: the counter counts toward the new balance and a short tick plays on each displayed step, so a single 500-credit harvester unload reads as a rapid tick burst and a large purchase reads as a slower, heavier count-down. This cadence — fast counting up, slower counting down, step size proportional to the gap — is the feel the sidebar's money display should reproduce, and the pieces it needs (event-driven credit SFX, `AudioManager` retrigger throttling, the credits label) already exist.

## What Changes

- The sidebar credit Label becomes an **animated credit counter**: on `credits_changed` for the local player it stores the new balance as a target and steps a displayed value toward it every frame until settled.
- Step size is proportional to the remaining gap (gap divided by a constant divisor, clamped to a minimum and maximum), so small changes settle in a step or two and large ones burst briefly.
- Counting direction changes the cadence: gains step at full rate, spends step at a slower interval (configurable constant), giving spending a heavier feel. Timing is time-based, not frame-count based (frame-rate-independent-timing).
- A tick sound plays on each displayed step: `ECON_INCOME` while counting up, `ECON_SPEND` while counting down, via `AudioManager.play_sound` (non-spatial, SFX bus, existing 50 ms retrigger override on the sound data). Forcing the display on load/initialization plays nothing.
- The display-driven counter **replaces the event-driven one-shot playback** in `EconomyAudioListener`: reason-string allowlisting (harvest/sell/build/prod prefixes) is dropped in favor of counting direction, and the listener autoload is removed with its responsibility folded into the sidebar counter. This also means debug-cheat credits animate like any other gain.
- The existing `EconomyManager` API, signals, and both `ECON_INCOME`/`ECON_SPEND` `AudioData` resources are unchanged.

## Capabilities

### New Capabilities

- *(none)*

### Modified Capabilities

- `credit-ui`: The "Credit display label in Sidebar" requirement changes from instant text updates driven solely by the signal to an animated counter that steps toward the target balance (per-frame stepping replaces the no-polling guarantee while an animation is active; idle when settled). A new requirement covers display-driven tick sounds: one tick per displayed step, direction chooses the sound id, silent on forced initialization.

## Impact

- `scripts/ui/Sidebar.gd` — counter state (displayed/target), time-based stepping in `_process` (enabled only while animating), tick playback per step.
- `scripts/core/EconomyAudioListener.gd` — deleted; `project.godot` — `EconomyAudioListener` autoload entry removed (autoload count 23 → 22); AGENTS.md autoload table updated.
- `test/unit/test_economy_audio.gd` — rewritten against the sidebar counter (deduction → down-tick burst, gain → up-tick burst, other-player silence, forced-display silence, cadence constants honored); `test/integration/test_sidebar_credits.gd` — label assertions move from instant equality to settle-at-target behavior.
- No changes to `EconomyManager`, `AudioManager`, `AudioData`, or the `econ_income.tres`/`econ_spend.tres` resources.
