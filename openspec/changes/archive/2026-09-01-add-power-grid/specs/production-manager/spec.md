## ADDED Requirements

### Requirement: Low power slows production
ProductionManager SHALL multiply each queue's effective production speed by the owner's current build-rate multiplier from PowerGrid (1.0 when healthy). Production SHALL slow under power deficit but SHALL NOT halt. The per-queue speed cache SHALL be invalidated when PowerGrid emits `grid_state_changed` for the queue's player. When PowerGrid is absent (e.g. isolated unit tests), the multiplier SHALL fall back to 1.0.

#### Scenario: Healthy grid keeps normal speed
- **WHEN** a player's grid is healthy and a queue computes its speed
- **THEN** the speed equals the existing multiple-factory speed with no power multiplier

#### Scenario: Deficit slows production
- **WHEN** a player's grid is in low power with build-rate multiplier r
- **THEN** every queue of that player advances at `speed × r` (e.g. ≈ 60% with output 100 against drain 150)

#### Scenario: Recovery restores speed
- **WHEN** the grid returns to healthy
- **THEN** the next speed lookup returns the unmultiplied speed

#### Scenario: Cache invalidated on grid change
- **WHEN** `grid_state_changed(player_id)` emits
- **THEN** cached speeds for that player's queues are dropped and recomputed on next lookup
