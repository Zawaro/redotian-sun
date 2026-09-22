## Context

The economy is a pure ledger (`EconomyManager` holds no per-frame state). `ProductionManager`
already deducts gradually during production, so the funding model is nearly there — the defect is
that the *start* gate requires the full cost and the *progress* loop advances without checking
whether the deduction succeeded.

## Decisions

### 1. Start gate = prerequisites only

`start_production` keeps the `buildable_queue` and `PrerequisiteSystem.can_build` checks and drops
the `can_afford` early return. A zero-balance player can queue the item; it simply does not advance
until credits exist. This also makes the `no_cost` debug cheat consistent (previously it was honored
in `deduct` but not in the start gate).

### 2. Progress is bound to payment

Each frame computes the owed increment from the accumulator (`cost * speed / build_time * delta`).
If the integer amount is > 0, it is deducted; **only on success** does `item.deducted` grow and
`item.progress` advance. On failure the queue is marked stalled, the accumulator is left intact for
the next frame, and progress holds. This makes "credits at $0" mean "no progress", and any income
resumes it. Partial balances work because the per-frame increment is small.

- Zero-cost entities and the `no_cost` cheat never stall (deduct returns true / no work to pay).
- `_complete_item` deducts the residual rounding; if that fails it returns without completing and
  the queue stays stalled.

### 3. Stall is an edge, not a level

`_stalled: Dictionary` per queue key. `production_stalled` fires on the false→true transition,
`production_resumed` on true→false. This bounds the EVA trigger to one line per starvation event
instead of one per frame.

### 4. EVA is a seam

No announcer system or asset exists. `AudioManager._ready` connects to `production_stalled` and, for
the local player only, calls `play_sound(EVA_ID)` — but returns silently when `get_audio_data(EVA_ID)`
is `null`. Dropping the asset in later activates the line with no code change. `no_cost` suppresses
it.

### 5. HUD resync via a roster signal

`PlayerManager` gains `players_changed`, emitted after `begin_mission` / `_init_from_map_config` /
`_init_defaults`. `CreditCounter` connects it and force-displays the new balance. The map is still
added before `begin_mission`; the signal is what closes the gap. `PlayerManager` stays unaware of
`EconomyManager` (no dependency cycle).

## Risks / trade-offs

- **QoL regression vs. classic.** Removing the affordability gate means clicking a cameo always
  queues it. That matches the requested model; the insufficient-funds color + EVA line carry the
  feedback.
- **Stall granularity.** Stalling holds at most one frame's increment of progress; with heavy
  income the queue keeps pace. Not a concern at RTS build times.
- **`insufficient_funds` on EconomyManager stays as-is** (fires on a failed deduct). Production now
  also emits at the queue level; the two are complementary — the queue signal is the EVA trigger
  because it is per-build and edge-triggered.

## Open questions

- Actual EVA audio id/asset: deferred. The hook uses `EVA_INSUFFICIENT_FUNDS` as the placeholder id.
