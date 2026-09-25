## Context

`FxData`/`FxSystem` draw every particle as a `QuadMesh`. The archived MVP's
`BulletHitSmall` impact rides the SPRITE path, so it looks like a fire flash.
The engine has no plane emission shape (`EMISSION_SHAPE_PLANE` is absent in
Redot 26.2), so a flat spawner is authored as a box with zero height.

## Goals / Non-Goals

- **Goals:** a triangle particle primitive; a flat, small-debris SA impact.
- **Non-Goals:** new process/emission behavior, more primitive types
  (quads/triangles cover the near-term debris and spark needs), per-particle
  mesh switching within one effect.

## Decisions

### Draw shape is a small enum on FxData

`ParticleShape { QUAD, TRIANGLE }` with `QUAD` as the default keeps every
existing particle effect byte-for-byte identical. The mesh is generated in
`FxSystem._build_particle_mesh` (a `QuadMesh`, or a one-triangle `ArrayMesh`)
and sized by the existing `quad_size`, so `quad_size` keeps its meaning across
shapes. The draw material is attached the way each mesh type expects
(`QuadMesh.material` vs `ArrayMesh.surface_set_material`).

### Flat spawn is a zero-height box

Redot 26.2 has no plane emission shape, so the impact spawns from
`EMISSION_SHAPE_BOX` with `emission_box_extents.y = 0` — a flat rectangle in
the ground plane. This is the standard stand-in and needs no engine change.

### Colours come from the initial ramp

Debris should be a mix of yellow, gray, and brown shards rather than a single
tint, so the impact uses `color_initial_ramp` (a `GradientTexture1D` sampled per
particle) plus `vertex_color_use_as_albedo` on the draw material. The material
is unshaded and non-billboard-tumbling is avoided by using billboard-enabled so
shards stay visible from the isometric camera.

## Risks / Trade-offs

- **The triangle mesh has no texture/normal mapping.** It is a flat unshaded
  shard, which is the intended look; a future textured debris effect can use the
  `QUAD` shape with an atlas instead.
- **`ArrayMesh` per effect instance.** Each triangle effect builds its own tiny
  mesh on spawn. It is one triangle; the cost is negligible next to the
  `GPUParticles3D` itself, and caching is deferred to FX pooling (#456).

## Migration Plan

Additive default (`QUAD`); the SA impact is the only content reworked, and its
old sprite art is deleted.

## Open Questions

- The shard count/size/lifetime are first-pass values to tune in the editor.
