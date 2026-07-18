## MODIFIED Requirements

### Requirement: Tiberium pod placeholder uses 3-stage seeded cube clusters
TiberiumComponent SHALL display 3 visual stages of procedurally generated cube clusters, seeded per-cell for unique placement. The material SHALL read emission settings from ArtData if available on the EntityData.

#### Scenario: Stage 0 — low amount
- **WHEN** `amount / max_amount <= 0.33`
- **THEN** 3 small cubes (size 0.15–0.35) are visible at random positions within the cell, seeded by cell position

#### Scenario: Stage 1 — medium amount
- **WHEN** `amount / max_amount` is between 0.34 and 0.66
- **THEN** 2 big cubes (0.35–0.55) + 3 small cubes (0.15–0.25) are visible

#### Scenario: Stage 2 — full amount
- **WHEN** `amount / max_amount >= 0.67`
- **THEN** 5 big cubes (0.35–0.55) are visible

#### Scenario: Visual update on collect
- **WHEN** `collect()` is called and amount crosses a stage boundary
- **THEN** `_update_visual()` switches to the new stage

#### Scenario: Per-cell seeded variance
- **WHEN** two Tiberium pods have the same stage
- **THEN** their cube positions differ (seeded by cell position)

#### Scenario: Material emission from ArtData
- **WHEN** the EntityData has art_data with `emission_enabled = true`
- **THEN** the BoxMesh material SHALL have emission applied with the ArtData's emission_color and emission_energy_multiplier

#### Scenario: Material without ArtData
- **WHEN** the EntityData has no art_data
- **THEN** the material SHALL use only albedo_color from ResourceType (existing behavior)

### Requirement: Tiberium pod self-destructs on depletion
TiberiumComponent SHALL destroy its parent entity via `queue_free()` when `amount <= 0` after a `collect()` call.

#### Scenario: Depleted pod
- **WHEN** `collect()` reduces `amount` to 0
- **THEN** the parent entity is queued for deletion via `queue_free()`

#### Scenario: Harvest loop handles deletion
- **WHEN** the pod entity is queued for deletion
- **THEN** the harvester's `is_instance_valid()` guard and `_current_tiberium_node = null` assignment handle it without error
