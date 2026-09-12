## ADDED Requirements

### Requirement: Turret mounts track the target while closing
Weapons mounted on a `yaw_free` turret socket SHALL slew toward the target every physics tick a target exists, including while the target is out of weapon range and the body is chasing it. This tracking SHALL NOT require the body to face the target and SHALL NOT itself fire the weapon; firing remains gated by range, cooldown, and turret alignment.

#### Scenario: Chase tracking
- **WHEN** a turreted unit is ordered to attack an enemy beyond weapon range and drives toward it
- **THEN** the turret continues to yaw toward the enemy during the approach, and the weapon does not fire until the enemy is in range and the turret is aligned
