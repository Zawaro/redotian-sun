## Why

Tiberium crystals render as flat-colored boxes with no visual pop, so they read as generic terrain clutter rather than the glowing resource fields the game is meant to evoke. The scene's bloom pipeline is already enabled but tuned to be inert, so the fix is cheap: make the crystals emissive and let the existing post-process do the rest.

## What Changes

- Tiberium crystal cube materials become emissive: emission is enabled, tinted to the resource type's own color, and driven bright enough to cross the bloom threshold.
- The shared `WorldEnvironment` glow is retuned from effectively-off to a visible bloom (intensity, HDR threshold, and bloom spread) so emissive crystals produce a soft halo.
- Emission color derives from each `ResourceType.color`, so green/blue/red variants glow their own hue with no per-type code.
- No per-crystal lights are added — the glow is purely material emission plus screen-space bloom, so there is zero per-entity draw or shadow cost.
- Tiberium trees (TIBTREE placeholders) are intentionally left unchanged.

## Capabilities

### New Capabilities
- `tiberium-emission-glow`: Tiberium crystals emit their resource-type color and bloom via the shared world environment, with no per-entity light cost.

### Modified Capabilities
<!-- No existing spec's requirements change; the cube-cluster and depletion behavior in tiberium-art-placeholder is untouched. -->

## Impact

- `scripts/components/ResourceComponent.gd` — cached crystal material gains emission setup.
- `scenes/environment/DefaultWorldEnvironment01.tscn` — glow properties retuned (backward compatible; only property values change, no node/resource restructure).
- `test/unit/test_resource_component.gd` — add coverage for the emissive material builder.
- No API, autoload, or save-format changes.
