## Context

Tiberium crystals are drawn by `ResourceComponent._ensure_visual_nodes()`, which builds three seeded cube-cluster stages and assigns each `MeshInstance3D` a shared `StandardMaterial3D` cached per `resource_type_id` in a static dictionary. The material currently sets only `albedo_color` from `ResourceType.color`.

`DefaultWorldEnvironment01.tscn` already declares `glow_enabled = true` on its `Environment`, but with `glow_intensity = 0.1` and default HDR threshold (~1.0) the bloom pass produces no visible halo — it is on but effectively inert. The project uses the Forward+ renderer, where glow is fully supported.

Constraints: GDScript only, hundreds of crystals may exist at once, and the issue explicitly rules out per-entity lights and any shadow-cost approach.

## Goals / Non-Goals

**Goals:**
- Tiberium crystals visibly glow in their resource-type color with a soft bloom halo.
- Blue/red/other variants glow their own hue automatically from `ResourceType.color`.
- Zero per-entity runtime cost beyond the already-shared material and the already-enabled bloom pass.

**Non-Goals:**
- Per-crystal or dynamic lighting (`OmniLight3D` etc.).
- Changing the cube-cluster geometry, stage logic, or depletion behavior.
- Glowing tiberium trees (TIBTREE placeholders) — deferred until real art lands.
- Per-type tunable glow strength — every type uses one shared energy value.

## Decisions

**Decision: Emission via the shared cached material, not per-instance.**
The material is already cached per `resource_type_id` and reused across every cube of that type, so enabling emission on it costs nothing per crystal. Emission color is set to the same `ResourceType.color` as albedo, and `emission_energy_multiplier` is a single script constant (`3.0`) chosen so the brightest color channel exceeds the bloom threshold (e.g. green `0.8 * 3 = 2.4 > 0.9`).
- Alternative — per-instance emissive material: rejected, defeats the cache and scales cost with crystal count.
- Alternative — `OmniLight3D` per crystal: rejected per the issue; per-draw and per-shadow cost at scale.

**Decision: Extract material construction into a small static helper `_build_material(color)`.**
The material was built inline inside a deep loop that needs a live scene tree, terrain, and global rules — untestable in a unit. Pulling the albedo+emission setup into a pure static function lets a unit test assert the emission properties without standing up a scene. The cache path calls the helper.
- Alternative — leave inline and skip the unit test: rejected, the emission config is the whole point of the change and should have a regression guard.

**Decision: Tune the existing `Environment` glow in place.**
Set `glow_intensity` to `1.0`, add `glow_hdr_threshold = 0.9` (so HDR emission above it blooms while normal-lit geometry does not), and add `glow_bloom = 0.2` (a small unconditional spread for a softer halo). Only property values change; no sub-resources or nodes are restructured, so existing scenes that instance this environment stay compatible.
- Alternative — a dedicated glow level curve / separate post environment: rejected as over-engineered for one tuning pass.

## Risks / Trade-offs

- [Bloom is a screen-space, scene-wide effect — other bright/HDR surfaces could also start blooming] → Threshold `0.9` with normal albedo lighting staying under ~1.0 keeps everyday geometry below the bloom cutoff; only the intentionally-boosted emissive crystals cross it.
- [Shared energy constant may look too hot for some future resource colors] → Emission color already varies per type; if a variant needs different strength later, promote the constant to a `ResourceType` field. Deferred (YAGNI) — no current type needs it.
- [Compatibility renderer would ignore glow] → Project is Forward+; documented as a non-issue.

## Open Questions

None — values are tunable in the scene and the script constant if art review wants adjustment.
