# move-line-renderer Specification

## Purpose

A single shared `MoveLineRenderer` autoload renders all active move-target and rally lines through one `ImmediateMesh` buffer rebuilt once per frame, so N visible lines cost one draw call instead of N per-unit mesh rebuilds. Lines register/unregister with the renderer, and each fades independently via per-vertex alpha on a shared unshaded material.

## Requirements

### Requirement: Shared batched line renderer
The system SHALL provide a `MoveLineRenderer` autoload that renders all active move-target and rally lines through a single shared buffer. It SHALL own one `ImmediateMesh` (a single `MeshInstance3D` at the world origin) and one shared unshaded material configured with `vertex_color_use_as_albedo`, `no_depth_test`, and the rally-line render priority. Each frame it SHALL rebuild its buffer exactly once from the set of registered line sources, so N active lines render as one buffer rebuild and one draw call regardless of N.

#### Scenario: All active lines share one buffer
- **WHEN** 60 units have active move-target lines registered with the renderer
- **THEN** the renderer performs one surface rebuild for all 60 lines in its per-frame pass (not 60 per-unit rebuilds)

#### Scenario: Pull-model endpoint computation
- **WHEN** the renderer rebuilds its buffer
- **THEN** it reads each registered source's current line endpoint (so a line whose endpoint moves — e.g. an attack target being tracked — updates on the shared buffer without per-unit meshes)

### Requirement: Register / unregister lifecycle
A line source SHALL register with the renderer when its line becomes visible and unregister when it hides. The renderer SHALL render only registered sources, and SHALL drop a source when it unregisters, its owning node is freed, or it times out — no stale segments may persist in the shared buffer.

#### Scenario: Register on show, unregister on hide
- **WHEN** a unit's move-target line is shown
- **THEN** the unit registers with the renderer and its line appears in the shared buffer

#### Scenario: Unregister on timeout
- **WHEN** a unit's move-target line timer elapses (or the unit is deselected)
- **THEN** the unit unregisters and its line disappears from the shared buffer

#### Scenario: Freed sources are dropped
- **WHEN** a registered unit's node is freed
- **THEN** the renderer removes its line from the shared buffer without leaving stale geometry

### Requirement: Per-line fade
The renderer SHALL fade each line independently by writing per-vertex alpha driven by the line's age; the shared material SHALL apply per-vertex color so one material renders lines at different alphas in a single draw call.

#### Scenario: Line fades on its own schedule
- **WHEN** two lines with different ages are registered
- **THEN** each fades according to its own remaining lifetime while sharing the single material and buffer
