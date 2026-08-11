# spatial-hash Specification — perf-284 delta

## ADDED Requirements

### Requirement: Reconcile skips unchanged positions
`SpatialHash._reconcile` SHALL skip the `world_to_cell` + `cell_key` recomputation for an entry whose cached position has not changed since the previous reconcile pass, so the steady-state (idle) majority of entries costs a position comparison instead of a full cell recompute each physics tick. When an entry's position, movement state, or shares flag has changed, the reconcile SHALL perform the identical update the full-scan path performed before this change, so the resulting `_grid`, `_blocked_cells`, and `_shared_cell_counts` remain identical to the pre-change behavior.

#### Scenario: Unchanged entry skipped
- **WHEN** an idle unit remains at the same position and state across two reconcile passes
- **THEN** the second pass compares the cached position and performs no `world_to_cell`/`cell_key` recomputation for that entry

#### Scenario: Moved entry still reconciled identically
- **WHEN** an entry's position changes between reconcile passes
- **THEN** its entry is moved to the new cell key with the same grid/blocked/shared mutations as before the position short-circuit
