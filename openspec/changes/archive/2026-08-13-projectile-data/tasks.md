## 1. Extend ProjectileData schema

- [x] 1.1 Add `rotates_to_face: bool` (Visuals group) to `scripts/data/ProjectileData.gd`
- [x] 1.2 Add `is_ranged: bool` (Targeting group) to `scripts/data/ProjectileData.gd`
- [x] 1.3 Add `tint_color: Color` defaulting to opaque white (Visuals group) to `scripts/data/ProjectileData.gd`

## 2. Populate projectile .tres files

- [x] 2.1 Add the three new fields to every `.tres` under `resources/projectiles/` with type-appropriate values (missiles/shells/lobbed rotate to face; laser lines carry a tint; defaults otherwise)

## 3. Guard weapon → projectile resolvability

- [x] 3.1 Add `test/unit/test_projectile_data.gd` that loads every projectile `.tres`, validates it, and asserts every weapon `.tres` `projectile` id resolves to an existing projectile

## 4. Quality gate

- [x] 4.1 `gdformat` + `gdlint` clean on changed scripts/tests; no tabs in multiline strings
- [x] 4.2 Headless test suite passes (`N passed, 0 failed`)
