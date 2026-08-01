## REMOVED Requirements

### Requirement: Infantry cell capacity

**Reason:** Generalized into the new `cell-occupancy` capability — capacity is scoped to `shares_cell` locomotors against a `GlobalRules.shared_slots_per_cell` knob instead of hardcoded to 3 infantry.

**Migration:** See `cell-occupancy/spec.md` (Shared cell capacity).

### Requirement: Sub-slot positioning

**Reason:** Moved to `cell-occupancy`; geometry now follows `CellSubPositions.get_slot_count()`.

**Migration:** See `cell-occupancy/spec.md` (Sub-slot positioning).

### Requirement: Infantry movement skips rotation

**Reason:** Rotation behavior is now driven by the `instant_turn` Locomotor flag.

**Migration:** See `locomotor/spec.md` (Locomotor drives MovementController behavior).

### Requirement: Infantry repulsion bypass

**Reason:** Generalized into `cell-occupancy` — repulsion bypass applies between any two `shares_cell` units.

**Migration:** See `cell-occupancy/spec.md` (Sharing repulsion bypass).

### Requirement: Infantry group pre-assignment

**Reason:** Formation distribution is a selection concern; moved to the `selection-manager` capability, keyed off `shares_cell`.

**Migration:** See `selection-manager/spec.md` (Sharers distribute by capacity).
