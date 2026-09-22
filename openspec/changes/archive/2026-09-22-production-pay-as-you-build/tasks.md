## 1. Player roster signal

- [x] 1.1 Add `signal players_changed` to `PlayerManager`
- [x] 1.2 Emit it at the end of `begin_mission`, `_init_from_map_config`, and `_init_defaults`

## 2. Credit HUD

- [x] 2.1 Connect `PlayerManager.players_changed` in `CreditCounter` to a non-animated resync
- [x] 2.2 Implement `_update_credits_color()`: red when balance < cheapest buildable cost, else white
- [x] 2.3 Recompute the color on ready, `credits_changed`, and `prerequisites_changed`

## 3. Pay-as-you-build production

- [x] 3.1 Drop the `can_afford` gate from `start_production` (keep queue-type + prerequisite checks)
- [x] 3.2 Add `production_stalled` / `production_resumed` signals and a `_stalled` map
- [x] 3.3 Advance progress only when the current increment's `deduct` succeeds; keep the accumulator on failure
- [x] 3.4 Increment `item.deducted` only on successful deduction
- [x] 3.5 Gate `_complete_item` on the residual balance clearing; inline pending queues stay stalled
- [x] 3.6 Emit stall/resume on the transition edge; clear stall state when a queue is erased

## 4. EVA hook

- [x] 4.1 Subscribe `AudioManager` to `ProductionManager.production_stalled` in `_ready`
- [x] 4.2 Ignore non-local players and the `no_cost` cheat
- [x] 4.3 Return silently when the `EVA_INSUFFICIENT_FUNDS` audio id is absent (asset not yet imported)

## 5. Mission economy

- [x] 5.1 Raise `games/ts/missions/gdi01.tres` `starting_credits` to a buildable amount

## 6. Tests

- [x] 6.1 `test_production_manager`: zero-balance start queues the item
- [x] 6.2 `test_production_manager`: starved queue stalls at $0 and resumes after `add`
- [x] 6.3 `test_production_manager`: a failed deduction does not inflate `item.deducted`
- [x] 6.4 `test_production_manager`: completion is withheld while underpaid, then completes when paid
- [x] 6.5 `test_player_manager`: `begin_mission` emits `players_changed`
- [x] 6.6 Credit counter: resync on `players_changed` and red/white color thresholds

## 7. Verification

- [x] 7.1 `redot --headless -s test/run_tests.gd`
- [x] 7.2 `gdlint` + `gdformat --check` on changed files
- [x] 7.3 `openspec validate production-pay-as-you-build --strict`
- [x] 7.4 Archive the change
