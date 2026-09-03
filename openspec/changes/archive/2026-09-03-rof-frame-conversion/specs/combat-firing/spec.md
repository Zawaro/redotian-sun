## MODIFIED Requirements

### Requirement: Fire rate cooldown per weapon
CombatComponent SHALL maintain a cooldown timer per weapon index. After firing, the timer SHALL be set to `weapon.rate_of_fire / 30.0` seconds, treating `rate_of_fire` as the original Tiberian Sun `ROF=` rearm-delay frames at the engine's 30 fps logic rate. The weapon SHALL NOT fire while its cooldown timer is positive.

#### Scenario: Fire rate timing
- **WHEN** a weapon with `rate_of_fire = 20` fires
- **THEN** the next shot from that weapon SHALL be delayed by 0.667 seconds (20/30)

#### Scenario: Cooldown ticks down
- **WHEN** `_physics_process(delta)` runs with a positive cooldown
- **THEN** the cooldown SHALL decrease by `delta`
