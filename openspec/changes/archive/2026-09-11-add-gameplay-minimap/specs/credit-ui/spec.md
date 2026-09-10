## RENAMED Requirements

- FROM: ### Requirement: Credit display label in Sidebar
- TO: ### Requirement: Credit display label in gameplay HUD

## MODIFIED Requirements

### Requirement: Credit display label in gameplay HUD

The system SHALL display the current credit balance as an animated counter in a Label node at the top of the right-hand gameplay HUD column, above the minimap and above the Sidebar build panel. On a `credits_changed` signal for the local player, the counter SHALL store the new balance as its target and step a displayed value toward the target once per frame until the displayed value reaches the target; the Label text SHALL always show the displayed value. Step size SHALL be proportional to the remaining gap (remaining gap divided by a configurable divisor, clamped to a configurable minimum and maximum). Counting cadence SHALL be time-based and direction-dependent: counting up SHALL step at the full frame rate, counting down SHALL step at a configurable slower interval, so an equal-amount spend animation takes longer than its gain counterpart. When the displayed value equals the target, the counter SHALL be idle (per-frame processing disabled until the next credit change). Forced initialization — scene ready or balance resync — SHALL set the displayed value directly to the balance without animating.

**FROM:** `Sidebar.tscn`
**TO:** top of the right-hand HUD column (above the minimap)

#### Scenario: Label shows current balance on ready
- **WHEN** the credit display label initializes
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
