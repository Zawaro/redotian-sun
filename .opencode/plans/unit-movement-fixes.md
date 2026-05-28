# Unit Movement Implementation

## Summary

Complete rewrite of MovementController: cell-to-cell waypoint chasing replaced with Catmull-Rom spline path following, analytic tangent direction, multi-unit repulsion steering, ahead-only speed modulation, spline re-projection, SpatialHash autoload for O(N²)→O(9) neighbor queries.

## Changes

### scripts/components/MovementController.gd — Full rewrite

| Change | Description |
|--------|-------------|
| Waypoint chasing → Catmull-Rom spline | `_waypoint_index`/`_waypoints[i]` replaced by `_spline_t` monotonically advancing 0→num_segments, Catmull-Rom eval via `_get_spline_pos(t)` and `_get_spline_tangent(t)` |
| Analytic tangent direction | `_get_spline_tangent(_spline_t).normalized()` in both `_handle_rotating` and `_handle_moving_movement` — eliminates zero-vector at t=0 |
| Spline re-projection | 20% lerp back to spline each MOVING frame — unit stays within mm of spline, no offset at arrival |
| Repulsion steering | 3×3 neighbor cell query via `SpatialHash.instance.get_entries()`, push = normalize / dist² × REPULSION_STRENGTH × repulsion_weight |
| Repulsion weight fade | `clampf(dist_to_final / (cell_radius * 4.0), 0.0, 1.0)` — repulsion fades to 0 at destination |
| Deviation clamp fade | `limit_length(0.3 * repulsion_weight)` — clamp also fades, pure spline direction at arrival |
| Ahead-only speed modulation | `min_neighbor_dist_ahead` — only neighbors with `to_neighbor.dot(spline_dir) > 0` count; `smoothstep(0→1, t)` → speed 0.3→1.0 |
| Speed jitter | `randf_range(0.95, 1.0)` per unit at `_ready()`, applied in `step` computation |
| Approach phase | After spline exhaustion: `(final_pos - parent_pos).limit_length(move_speed * delta)`, snap at <0.001 |
| Re-path on IDLE cell | Every 10 frames, checks if next waypoint cell is IDLE-occupied → `set_target_position(final)` |
| WAIT timeout | 60-frame fallback, backs up `_spline_t` to `num_segments - 0.01` and retries ROTATING |
| `_build_blocked_cells` | Uses `SpatialHash.instance.all_entries()` instead of `get_tree().get_nodes_in_group("entities")` |
| `_is_cell_occupied_by_idle` | Delegates to `SpatialHash.instance.is_cell_idle(cell)` |
| `corner_blend_radius` removed | No longer needed — spline handles curvature intrinsically |
| `STEERING_RADIUS` → `REPULSION_STRENGTH` | `0.1` constant, inverse-square push away from neighbors |

### scripts/core/SpatialHash.gd — New autoload

| Component | Description |
|-----------|-------------|
| `class_name SpatialHash` | Type alias for static references |
| `static var instance` | Set in `_enter_tree()` |
| `_process` | Calls `rebuild()` every frame |
| `rebuild()` | Clears grid, iterates `"entities"` group, maps cell_key → [{ node, mc }] |
| `get_entries(cell)` | Returns array of entries for a given cell |
| `all_entries()` | Flattens all grid entries into single array |
| `is_cell_idle(cell)` | Returns true if any entry in cell has `_state == IDLE` |

### project.godot — Autoload registration

```ini
SpatialHashSingleton="*res://scripts/core/SpatialHash.gd"
```

### scenes/entities/units/nod/NodBuggy.tscn

- `rotation_speed = 240.0` — faster rotation for responsive turning

### scripts/core/DebugVisualizer.gd

- `_get_or_create_material(name: …)` → `_get_or_create_material(material_name: …)` — fixes `Node.name` shadowing warning