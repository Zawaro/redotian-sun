## MODIFIED Requirements

### Requirement: Infantry entity data includes weapons
Infantry entity .tres files SHALL populate the `weapons` array with references to WeaponData .tres files. EntityFactory SHALL create a CombatComponent when `data.weapons` is non-empty.

#### Scenario: GDI Light Infantry has weapon
- **WHEN** `gdi_light_infantry.tres` is loaded
- **THEN** `weapons` SHALL contain a reference to `m1carbine.tres`

#### Scenario: Nod Light Infantry has weapon
- **WHEN** `nod_light_infantry.tres` is loaded
- **THEN** `weapons` SHALL contain a reference to `m1carbine.tres`

#### Scenario: EntityFactory creates CombatComponent
- **WHEN** an entity is created with non-empty `weapons` array
- **THEN** EntityFactory SHALL instantiate CombatComponent and call `configure(data)`
