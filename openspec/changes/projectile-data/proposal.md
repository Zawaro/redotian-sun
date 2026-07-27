## Why

Weapon `.tres` files reference a projectile by string id (`WeaponData.projectile`), and a
`ProjectileData` resource class plus ~20 projectile `.tres` files already exist to make those
references resolvable. However, the class is missing three projectile properties defined in the
source rules data — sprite rotation, range-based targeting, and beam tint — so the schema cannot
yet fully describe projectiles like laser lines or rotating missiles. There is also no test
guarding that every weapon's projectile reference actually resolves to a projectile file, which is
the entire point of the class.

## What Changes

- Add three missing fields to `ProjectileData`:
  - `rotates_to_face: bool` — projectile sprite rotates to face its travel direction
  - `is_ranged: bool` — projectile is limited to weapon range then detonates (range-based targeting)
  - `tint_color: Color` — tint applied to the projectile/beam graphic (used by laser-line projectiles)
- Populate the three new fields in all existing projectile `.tres` files with type-appropriate values.
- Add a test that loads every projectile `.tres`, validates it, and asserts that every weapon
  `.tres` `projectile` reference resolves to an existing projectile id (no dangling references).

## Capabilities

### New Capabilities

- `projectile-data`: `ProjectileData` resource class defining the visual and behavioral properties
  of in-flight projectiles, and the projectile `.tres` definitions that weapons reference by id.

### Modified Capabilities

(none — no existing spec defines projectiles)

## Impact

- **Modified**: `scripts/data/ProjectileData.gd` (three new `@export` fields).
- **Modified**: 20 projectile `.tres` files under `resources/projectiles/` (three new fields each).
- **New**: `test/unit/test_projectile_data.gd` guarding load/validation and weapon reference resolution.
- **No breaking changes**: new fields default to no-op values; `WeaponData` and existing weapon
  files are untouched. Feeds the future projectile system (#78) as schema-first data.
