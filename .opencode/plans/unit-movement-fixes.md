# Unit Movement Fixes - Implementation Plan

## Summary of Changes

Three issues found in the unit movement system need fixing: INF validation bug, stale task documentation, and missing debug logging.

---

## Fix 1: `scripts/components/MovementController.gd` line ~45 — Vector3.INF Validation Bug

**Problem:** `is_instance_valid(target)` returns true for any valid object instance — including `Vector3.INF`. A Vector3 with INF coordinates IS a valid GDScript object, so it passes this check and corrupts `_current_target`, causing units to fly off into infinity.

**Change at line 45 (in `set_target_position`):**

```gdscript
# BEFORE:
func set_target_position(target: Vector3) -> void:
	if not is_instance_valid(target):
		return

# AFTER:
func set_target_position(target: Vector3) -> void:
	if target.is_nan() or !target.is_finite():
		printerr("[MovementController] Ignoring invalid target position: ", target)
		return
```

This catches both `Vector3.INF`, `Vector3(-INF, -INF, -INF)`, and NaN values. GDScript's `is_finite()` returns true only if ALL components are finite (not INF or NAN).

---

## Fix 2: OpenSpec tasks.md — Uncheck Stale/Incomplete Tasks + Update Descriptions

**File:** `openspec/changes/unit-movement/tasks.md`

### Task 1.4 — UNCHECK [x] → [ ] and update description
```markdown
- [ ] 1.4 Implement set_target_position(target: Vector3): sets _current_target, transitions to MOVING if currently IDLE. NOTE: Target validation for INF/NaN positions is a known gap (tracked as Fix #5 in unit-movement fixes plan). Arrived signal only emitted on arrival detection — no early-return emission.
```

### Task 2.1 — Keep checked [x] but update description to match actual implementation
The task originally said "casts a ray from camera through mouse cursor targeting default collision layer (mask = 1), returning result.position or Vector3.INF sentinel" but the **actual implementation** uses `Plane(Vector3.UP, 0.0).intersects_ray()` — pure math intersection with Y=0 ground plane, not a physics query to layer 1. This is intentional per Phase 1 design (GroundPlane.tscn collision shapes are decoration only; world space Y=0 intersect is the target for this phase).

```markdown
- [x] 2.1 In `scripts/hud/MouseHandler.gd`, implement `_get_ground_position_at_mouse()` that uses Plane math: casts a ray from camera through mouse cursor position and intersects it with the Y=0 ground plane (`Plane(Vector3.UP, 0.0).intersects_ray(from, dir)`), returning intersection point or Vector3.INF sentinel. NOTE: Phase 1 intentionally uses mathematical plane intersection rather than physics query to collision layer 1 — GroundPlane.tscn static body is decoration only for this phase.
```

---

## Fix 3: `scripts/hud/MouseHandler.gd` — Add Debug Logging for Camera Failures

**Problem:** When `camera_controller` export fails (e.g., scene hierarchy issues, base map not loaded), all raycasting silently returns null/INF with zero indication of why. The existing print statements at lines 20-23 only check for SelectionManager but never log camera state.

### Change in `_handle_single_click()` — add camera debug logging around line 91:
```gdscript
func _get_camera_3d() -> Camera3D:
    if camera_controller and camera_controller.has_node("Camera3D"):
        return camera_controller.get_node("Camera3D") as Camera3D
    
    # Debug logging for diagnosis of missing camera in raycasting flow
    printerr("[MouseHandler] _get_camera_3d() returned null — " + \
        ("camera_controller is not set. " if !camera_controller else \
         "camera_controller has no 'Camera3D' child node. "))
    return null
```

### Change in `_ready()` — add camera debug logging around line 18:
```gdscript
func _ready():
    selection_rect.hide()
    
    # Debug logging for raycasting infrastructure
    if not camera_controller:
        printerr("[MouseHandler] WARNING: camera_controller export is null. " + \
            "All mouse-based interactions (selection, movement) will fail silently.")
    else:
        var cam3d = _get_camera_3d()
        if !cam3d:
            printerr("[MouseHandler] Camera3D not found under camera_controller path.")
    
    if selection_manager:
        print("SelectionManager found!")
