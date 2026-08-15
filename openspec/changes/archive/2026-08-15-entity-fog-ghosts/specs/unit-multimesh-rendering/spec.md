## ADDED Requirements

### Requirement: Post-destruction tombstone ghosts
A unit whose MultiMesh instance is frozen as a fog ghost SHALL, when the unit is destroyed while still in fog, retain its frozen instance as a tombstone rather than releasing the slot. The tombstone SHALL be released when the unit's last-known cell becomes visible, reverts to shroud, or when fog is toggled off at runtime. Tombstone retention SHALL NOT alter slot compaction, `visible_instance_count`, or region bucket capacity for live instances beyond the reserved tombstone slot.

#### Scenario: Unit destroyed in fog leaves tombstone
- **WHEN** a frozen enemy unit is destroyed while its cell is in fog
- **THEN** its frozen MultiMesh instance persists at the last-known position

#### Scenario: Tombstone released on reveal
- **WHEN** the cell holding a tombstone becomes visible
- **THEN** the tombstone instance is released and its slot returns to normal bookkeeping

#### Scenario: Tombstone released on fog toggle-off
- **WHEN** fog_of_war is toggled off at runtime
- **THEN** all tombstones are released
