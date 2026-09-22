## Why

Investigation of "I cannot build the GDI Power Plant" surfaced a cluster of economy/production defects:

1. **Builds can't start without full funds.** `ProductionManager.start_production` refuses unless
   `EconomyManager.can_afford(cost)` is true, and a failed start is silent — the cameo click looks
   dead. Classic C&C behavior is to start and fund the build as it progresses.
2. **The credit HUD lies after mission boot.** The map (and its `CreditCounter`) enters the tree
   before `PlayerManager.begin_mission` rebuilds the roster, so the counter displays the autoload's
   pre-mission balance (GlobalRules `10000`) while the real balance is the mission's. `begin_mission`
   emits no credit change to correct it.
3. **Deduction accounting is wrong.** When `EconomyManager.deduct` fails, `_process` still increments
   `item.deducted` and advances progress, so a queue counts credits it never took and never stalls.
4. **Completion isn't gated on payment.** `_complete_item` ignores the result of its final `deduct`,
   so an under-paid building can finish and be placed.
5. **No insufficient-funds feedback.** The `credit-ui` "Insufficient funds visual feedback"
   requirement is specced but has no implementation (`CreditCounter.gd` has no color logic), and
   `EconomyManager.insufficient_funds` has no consumer.

## What Changes

- **Pay-as-you-build.** `start_production` requires prerequisites only; the queue funds itself during
  production and stalls (not fails) when credits run out, resuming automatically once credits arrive.
- **Stall/resume signals.** `ProductionManager` emits `production_stalled(queue_key)` /
  `production_resumed(queue_key)` on the transition edge, once per stall — the trigger for EVA
  "insufficient funds". `AudioManager` subscribes; the call is silent until an
  `EVA_INSUFFICIENT_FUNDS` audio asset is imported, so no announcer system is invented now.
- **Correct accounting.** `item.deducted` increments only on a successful `deduct`; completion holds
  until the remaining balance clears.
- **HUD resync.** `PlayerManager` emits `players_changed` when it (re)builds the roster; the credit
  counter resyncs to the local player's balance without animation.
- **Insufficient-funds color.** Implement the already-specced red-until-cheapest-buildable feedback.
- **Mission economy.** Raise `gdi01`'s starting credits so the placeholder mission is buildable.

## Impact

- `scripts/production/ProductionManager.gd` — start gate, `_process` funding loop, completion gate,
  new signals.
- `scripts/core/PlayerManager.gd` — `players_changed` signal.
- `scripts/ui/CreditCounter.gd` — resync + insufficient-funds color.
- `scripts/core/AudioManager.gd` — subscribe to `production_stalled` for the EVA hook.
- `games/ts/missions/gdi01.tres` — starting credits.
- Specs: `production-manager`, `credit-ui`.
- Tests: production funding/stall, player roster signal, credit counter resync/color.
