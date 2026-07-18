## Context

HitboxComponent exists as an Area3D with a BoxShape3D collision shape but has zero signal connections — it detects nothing. HealthComponent has `take_damage(damage: int)` but no damage_type parameter. No collision layer constants exist; layers are hardcoded magic numbers scattered across MouseHandler and EntityFactory.

The damage pipeline currently has no entry point: `weapon → projectile → ??? → hitbox → health`. This change closes the hitbox→health gap.

```
BEFORE:
  Projectile ──▶ HitboxComponent (inert) ──✕──▶ HealthComponent

AFTER:
  Projectile ──▶ HitboxComponent (signals) ──▶ get_damage_info() ──▶ take_damage(damage, type)
```

## Goals / Non-Goals

**Goals:**
- HitboxComponent detects entering areas/bodies and forwards damage to HealthComponent
- Damage forwarding uses a duck-typed protocol (`get_damage_info()`) so projectiles define their own damage shape
- Collision layers are named constants, not magic numbers
- EntityFactory configures hitbox layers per entity type
- HealthComponent `take_damage()` accepts optional `damage_type` for future armor calculation

**Non-Goals:**
- Projectile implementation (separate issue — projectiles don't exist yet)
- Armor zone mapping (front/side/rear — deferred per issue #29)
- Damage multiplier zones (headshots — not in original TS)
- CombatComponent firing logic (separate issue #28)

## Decisions

**1. Duck-typed `get_damage_info()` protocol over typed interface**

Projectiles implement `get_damage_info() -> Dictionary` returning `{"amount": int, "type": String}`. HitboxComponent checks `has_method("get_damage_info")` before calling.

Alternatives considered:
- **Typed Projectile class**: Would require all damaging entities to extend a base class. Too rigid — melee attacks, environmental damage, and future mod content all need to deal damage without sharing a class hierarchy.
- **Signal-based**: HitboxComponent emits `area_entered`, parent handles routing. More flexible but pushes boilerplate into every entity parent. The forwarding logic is the same everywhere — belongs in the hitbox.

**2. Collision layer constants on HitboxComponent**

`LAYER_HITBOX_GROUND = 1 << 1`, `LAYER_HITBOX_AIR = 1 << 2`, `LAYER_HITBOX_BUILDING = 1 << 3`, `LAYER_PROJECTILE = 1 << 4`. Existing layers (terrain=1, select=15, interact=16) are unchanged.

Alternatives considered:
- **Separate CollisionLayers.gd autoload**: More discoverable but adds an autoload for 5 constants. Overkill — these only matter in EntityFactory and HitboxComponent.
- **EntityData export**: Let each entity define its own layers. Flexible but defeats the purpose of standardization. Layers should be systematic, not per-entity.

**3. Default `damage_type = ""` on HealthComponent.take_damage()**

Backward compatible — existing callers (MapEditor, ResourceComponent) pass only damage. The empty string signals "untyped damage" for future armor lookup.

## Risks / Trade-offs

- **[No projectiles yet]** → The `get_damage_info()` protocol is untested end-to-end. Mitigation: protocol is simple (one method, one dict shape), and the existing test suite (203 tests) passes.
- **[Stale LSP errors]** → LSP reports `take_damage()` wrong-arg-count because it caches old signatures. Mitigation: `gdformat` and `gdlint` pass; runtime tests pass.
- **[Melee not covered]** → HitboxComponent only detects Area3D/PhysicsBody3D entries. Melee attacks would need a different detection mechanism (range check from CombatComponent). Acceptable — melee is a separate concern.
