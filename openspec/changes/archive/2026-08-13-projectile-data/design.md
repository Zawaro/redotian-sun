## Context

`ProjectileData.gd` and ~20 projectile `.tres` files already exist (delivered early alongside the
entity-data population work). Weapons reference projectiles by string id via `WeaponData.projectile`,
and all current weapon references resolve. Two gaps remain against the intended schema: three
projectile properties from the source rules data are absent (sprite rotation, range-based
targeting, beam tint), and nothing guards that weapon references stay resolvable as data grows.

The class is deliberately schema-first — the projectile flight/combat system (#78) is not yet built,
so no runtime code reads these fields. Existing fields already carry a `# ponytail: schema-first,
no consumer yet` marker; the new fields follow the same convention.

## Goals / Non-Goals

**Goals:**
- Complete the `ProjectileData` schema so it fully describes the source projectile definitions.
- Keep all existing weapon → projectile references resolvable, and guard that with a test.

**Non-Goals:**
- Implementing projectile flight, homing, or combat behavior (that is #78).
- Adding a projectile registry/loader autoload — weapons already resolve by id string; a lookup
  layer belongs with the consumer that needs it.
- ArtData model/anim entries for projectiles (tracked separately).

## Decisions

- **Add three fields, no new class.** `rotates_to_face: bool`, `is_ranged: bool`, and
  `tint_color: Color` are added to the existing `ProjectileData` rather than introducing a
  separate visuals resource. Projectiles are small, flat records; a single resource matches the
  existing `EntityData`/`WeaponData` "one class, defaulted fields" pattern already used in this
  codebase. Alternative (a nested `ProjectileVisuals` resource) was rejected as premature — no
  consumer justifies the indirection.
- **`tint_color` defaults to opaque white** (`Color(1, 1, 1, 1)`) so "no tint" is the natural
  no-op; only laser-line style projectiles set a non-white tint.
- **Values are set per projectile from type semantics.** Since the raw rules file is not vendored
  in the repo, new-field values are assigned from each projectile's evident type (missiles/shells
  rotate to face; laser lines carry a tint) rather than invented precision. Defaults elsewhere.
- **Guard resolvability with a data test, not runtime code.** A unit test loads every projectile
  `.tres`, validates it, and asserts every weapon's `projectile` id resolves. This catches dangling
  references (the whole reason the class exists) without adding production lookup code before #78
  needs it.

## Risks / Trade-offs

- New-field values are best-effort from projectile semantics, not authoritative source data.
  → Mitigation: fields are schema-first with no consumer; values can be tuned when #78 renders
  projectiles. Defaults are no-ops, so wrong guesses are inert.
- The resolvability test couples weapons and projectiles.
  → Mitigation: that coupling already exists implicitly; the test makes a real invariant explicit
  and fails loudly if a future weapon adds a dangling projectile id.
