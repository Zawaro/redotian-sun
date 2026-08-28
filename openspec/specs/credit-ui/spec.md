### Requirement: Credit display label in Sidebar
The system SHALL display the current credit balance as an animated counter in a Label node above the building cameo grid in `Sidebar.tscn`. On a `credits_changed` signal for the local player, the counter SHALL store the new balance as its target and step a displayed value toward the target once per frame until the displayed value reaches the target; the Label text SHALL always show the displayed value. Step size SHALL be proportional to the remaining gap (remaining gap divided by a configurable divisor, clamped to a configurable minimum and maximum). Counting cadence SHALL be time-based and direction-dependent: counting up SHALL step at the full frame rate, counting down SHALL step at a configurable slower interval, so an equal-amount spend animation takes longer than its gain counterpart. When the displayed value equals the target, the counter SHALL be idle (per-frame processing disabled until the next credit change). Forced initialization — scene ready or balance resync — SHALL set the displayed value directly to the balance without animating.

#### Scenario: Label shows current balance on ready
- **WHEN** `Sidebar._ready()` runs
- **THEN** a Label displays `EconomyManager.get_balance(0)` prefixed with "$" immediately, with no animation

#### Scenario: Label counts toward the target on credit change
- **WHEN** `EconomyManager.add()` or `EconomyManager.deduct()` changes the local player's balance
- **THEN** the Label text updates over subsequent frames, stepping toward the new balance, and settles exactly at the new balance

#### Scenario: Large changes animate in a burst, small changes in few steps
- **WHEN** the gap between the displayed value and the target is large
- **THEN** each step covers the gap divided by the divisor (clamped), so the animation length grows sub-linearly with the amount changed

#### Scenario: Counting down is slower than counting up
- **WHEN** a gain and an equal-sized loss animate
- **THEN** the loss animation spans more time per step (spend step interval > gain step interval), both measured in seconds

#### Scenario: Counter is idle when settled
- **WHEN** the displayed value equals the target and no new `credits_changed` has arrived
- **THEN** the counter performs no per-frame updates (no label write and no tick) until the next credit change

#### Scenario: Other players' credit changes are ignored
- **WHEN** `credits_changed` fires for a player other than the local player
- **THEN** the counter does not animate and the Label is unchanged

### Requirement: Credit counter tick sounds
The credit counter SHALL play a tick sound on each displayed step while animating: `ECON_INCOME` while counting up, `ECON_SPEND` while counting down, routed through `AudioManager.play_sound` as non-spatial SFX. Only the local player's counter animates and ticks. Forced initialization SHALL NOT play any tick.

#### Scenario: Gain produces an up-tick burst
- **WHEN** a large credit gain animates
- **THEN** `ECON_INCOME` plays once per displayed step across the animation (repeats within the sound's retrigger window are dropped by `AudioManager` throttling)

#### Scenario: Spend produces down-ticks at the slower cadence
- **WHEN** a credit deduction animates
- **THEN** `ECON_SPEND` plays once per displayed step, at the slower count-down cadence

#### Scenario: Forced display is silent
- **WHEN** the counter is force-initialized (scene ready or balance resync)
- **THEN** no tick sound plays

#### Scenario: Other players' credit changes are silent
- **WHEN** `credits_changed` fires for a player other than the local player
- **THEN** no tick sound plays

### Requirement: Insufficient funds visual feedback
The Label SHALL change color when the player's credit balance is below the cost of the cheapest buildable item.

#### Scenario: Sufficient funds
- **WHEN** `credits >= min(cost of all buildable items)`
- **THEN** the Label color is white

#### Scenario: Insufficient funds
- **WHEN** `credits < min(cost of all buildable items)`
- **THEN** the Label color turns red
