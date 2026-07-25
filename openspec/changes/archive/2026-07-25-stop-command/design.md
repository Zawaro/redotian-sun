## Context

The game currently has no Stop command. Units can only be redirected or left idle by issuing new move orders. In the original Tiberian Sun, pressing S instantly halts all unit activity — movement, harvesting, attacking — with graceful cell-aligned stopping. Units don't freeze mid-path; they finish transitioning to the nearest cell center before becoming idle.

Current movement system: `MovementController` uses a state machine (`IDLE`, `ROTATING`, `MOVING`, `WAIT`) with spline-based path following. Harvesting is managed by `HarvestComponent` with its own state machine. Both are triggered by orders from `MouseHandler` via `OrderSystem`.

## Goals / Non-Goals

**Goals:**
- Add Ctrl+S hotkey that stops all selected units instantly
- Units finish current cell transition before stopping (no mid-path freeze)
- Harvesting is cancelled and resource cells are released
- New move orders during stop override the stop

**Non-Goals:**
- Guard mode (not implemented yet)
- Attack cancellation (combat system incomplete, `_attack()` is a no-op)
- Stop cursor visual (can be added later)

## Decisions

### 1. Graceful stop via `_stopping` flag vs. immediate freeze

**Decision**: Use a `_stopping` flag that lets the unit continue moving to the next cell center before stopping.

**Rationale**: In Tiberian Sun, units settle at valid cell positions when stopped. Immediate freeze leaves units between cells, which looks broken and causes pathfinding issues. The flag approach is minimal — just a bool check at the end of `_handle_moving_movement()`.

**Alternatives considered**:
- Immediate freeze (OpenRA style): Simpler but leaves units in invalid positions. Rejected based on user testing of original TS.
- Path truncation: Rewrite waypoints to end at current cell. More complex, same result as flag approach.

### 2. Cell arrival detection

**Decision**: Check distance to current cell center (`< 0.1`) and dot product with movement direction (`< 0` means passed center).

**Rationale**: Two conditions cover both cases — approaching cell center (close enough) and passed cell center (moving away). No threshold tuning needed beyond the 0.1 distance check.

### 3. WAIT state handling

**Decision**: If unit is WAIT state and already at destination cell center with cell clear, stop immediately. Otherwise, let WAIT continue.

**Rationale**: WAIT state means the unit is already at or near its destination cell but the cell is occupied. If the cell clears and the unit is centered, there's no reason to continue waiting.

### 4. Harvesting cancellation

**Decision**: Reuse existing `HarvestComponent.cancel_harvest(true)` which releases resource cells and transitions to IDLE.

**Rationale**: Already implemented and tested. The `true` parameter indicates player-commanded cancellation.

## Risks / Trade-offs

- **[Risk]** Unit stops in a cell that's about to be occupied by another unit → **Mitigation**: Cell occupation is checked each frame in `_handle_moving_movement()`, so the unit will naturally avoid occupied cells.
- **[Risk]** Stopping a large group of units simultaneously could cause cell contention → **Mitigation**: Each unit independently finds its nearest cell center, and SpatialHash handles cell reservations.
- **[Trade-off]** Units don't stop instantly (takes ~1 frame to reach cell center) → Acceptable for visual correctness.
