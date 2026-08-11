## Context

GH #279: issuing a move order to a group of infantry sustains an ~80% FPS drop while the group moves. Profiling (60 light infantry, 5-frame capture) attributes it to `ShroudSystem` re-stamping:

- `VisionComponent._physics_process` 21ms — on every cell crossing it calls `_unregister()` + `_register()`, i.e. two full disc shadowcasts per crossing.
- `_stamp_reveal` 20.5ms / 42 calls (0.49ms each); `_cell_reachable` 15.5ms / 3360 calls — **73% of stamp cost is per-cell Bresenham LOS walks** over the ~80-cell sight-5 disc.
- ≈ 4.2 crossings/frame → ≈ 4.1ms/frame sustained in shroud stamping alone.

Current flow (`ShroudSystem.gd`): `register_revealer`/`unregister_revealer` each call `_stamp_reveal(st, center, radius, height, blocks, ±1)`, which re-runs `_shadowcast_cells` (per-cell Bresenham LOS, `_cell_reachable`) over the whole disc and adjusts `visible_count` + dirty flags. The two discs of a 1-cell move overlap almost completely — the overlap is stamped twice for nothing.

## Goals / Non-Goals

**Goals:**
- Cut per-crossing shroud cost from two full O(r²) LOS disc stamps to one O(r) crescent re-stamp, keeping `visible_count`, `explored`, and the resolve cadence exact for all cells except documented shadow-edge flips.
- Keep the existing Bresenham LOS algorithm and `register_revealer`/`unregister_revealer` semantics untouched.
- Land it with tests (behavioral + a perf guard) and leave existing fog-of-war tests passing.

**Non-Goals:**
- Not changing the LOS algorithm (recursive shadowcast) — out of scope; the double-stamp is the measured bottleneck.
- Not deferring re-stamps to the resolve cadence — rejected (see Decisions).
- Not touching `MovementController` (2.3ms/frame in the same profile), the move-target line / `SelectionOverlay` process cost, or the fog renderer.

## Decisions

### D1: `ShroudSystem.move_revealer(player_id, key, new_cell)` owns the move diff
`VisionComponent` keeps calling into ShroudSystem on crossings, but the unregister+register pair becomes a single `move_revealer` call. The diff must live in ShroudSystem because it needs the revealer table, `_stamp_reveal` internals, and per-player `st` state.
- **Alternative**: client-side diff in `VisionComponent` — rejected, would duplicate table/stamp access and leak the model.
- **Alternative**: keep unregister+register — rejected, that is the measured 2× waste.

### D2: Crescent via geometric symmetric-difference box scan, reusing `_cell_reachable`
`move_revealer` does NOT store per-revealer revealed-cell sets (would be O(r²) memory per revealer). Instead it iterates the bounding box of the two discs (`(2r+2)²` cells of cheap `in_disc` arithmetic) and selects the geometric symmetric difference — the entering crescent (new disc only) and exiting crescent (old disc only). Only those O(r) cells run LOS:
- entering crescent cell: `+1` iff `_cell_reachable(new_cell, cell, ...)`
- exiting crescent cell: `-1` iff `_cell_reachable(old_cell, cell, ...)`
- overlap cells: **skipped entirely** — their aggregate `visible_count` contribution is unchanged, so no re-stamp is correct and free.
- **Rationale**: for a 1-cell move the box scan is ~256 cheap arithmetic tests but only ~20–30 LOS walks, vs 2 × 80 LOS walks today. For the sight-20 sensor array the box scan is 1764 cheap tests with only ~O(40–80) LOS walks — still ~10× cheaper than two full discs. No allocation of large sets.
- **Alternative**: exact crescent that re-evaluates overlap reachability — rejected, it re-walks the full disc (no savings).

### D3: Extract the per-cell stamp body so both full stamps and crescents share it
Refactor `_stamp_reveal`'s per-cell loop (`visible_count[idx] += delta`, `explored` latch, `_mark_dirty`, `_revealable`/bounds guard) into a small helper (e.g. `_apply_cell(st, idx, delta)`). `_stamp_reveal` becomes shadowcast + `_apply_cell` over the disc; `move_revealer` becomes crescent cells + `_apply_cell`. Same clamping (`maxi(count + delta, 0)`), same dirty dedup, one code path.

### D4: Each revealer caches the cells it contributes +1 to
The pure "skip overlap" crescent leaks counts: a flip cell keeps a stale +1 that no future LOS check decrements (exiting checks `_cell_reachable(old, cell)` — false for the flip cell — so it is never cleaned, and death's disc re-stamp misses it too). To make exiting and death exact, each revealer entry gains a `"cells"` Dictionary (Vector2i → true) of exactly the cells this revealer currently contributes +1 to:
- `register_revealer` computes the revealed set once, caches it, and stamps it.
- `move_revealer` entering cells add to the cache (+1), exiting cells remove from it (-1) — membership, not reachability, drives cleanup.
- `unregister_revealer` subtracts the cache instead of re-running the disc — exact for moved revealers, identical to the old behavior for stationary ones, and cheaper (no shadowcast at death).
- Invariant: cache always matches applied deltas, so counts can never leak. The only approximation left is a lingering shadow-edge cell staying visible while it stays in the overlap; it self-corrects when the cell exits the disc or the revealer dies. This is the documented spec scenario.
- **Alternative**: no cache, cache-less crescent — rejected, it leaks stale counts (see above).

### D5: Guard rails mirror `unregister_revealer`
`move_revealer` no-ops when the key is missing (grid reinit or already-unregistered), when `new_cell == old_cell`, or when `_cell_count <= 0` / center out of bounds.

### Rejected alternative: defer re-stamps to the resolve cadence
Batching crossings into the 0.25s resolve concentrates ~120 stamps into a single ~15ms hitch every 0.25s (per-frame average identical, worst frame far worse). Only worthwhile if a stamp becomes cheaper — it does not here. Rejected on the profile data.

## Risks / Trade-offs

- **Shadow-edge flip staleness** → A revealer's overlap cell whose LOS flips (segment passes within ~1 cell of a blocker) is not re-stamped on that move. It keeps its previous state — possibly stale-visible — until the cell exits the disc or the revealer dies, then self-corrects; counts never leak (the per-revealer cell cache drives exact cleanup). Mitigated by the spec scenario "Shadow-edge flip self-corrects".
- **Behavior change for callers that relied on unregister+register for moves** → Only `VisionComponent` moves revealers in production; temp reveals and buildings never move. Grep confirms no other `register_revealer` callers mutate centers (tests register static revealers). Low risk.
- **Count corruption if a stale key is passed** → Guarded no-op (D5), same contract as `unregister_revealer`.
- **Existing test churn** → `test_shroud_system` / `test_fog_renderer` / `test_unit_mesh_renderer` register static revealers (no moves) — unaffected. "Revealer moves" assertions in `test_shroud_system` will need updating from the unregister+register pattern to `move_revealer`.

## Migration Plan

Internal API addition only — no data, scene, or resource changes. Rollback is reverting the commit; the old unregister+register path remains valid (tests keep `register_revealer`/`unregister_revealer` working for the cases that still use them).

## Open Questions

- None blocking. (Minor: whether `move_revealer` returns a bool for callers — not needed; the key guard is the contract.)
