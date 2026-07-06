## ADDED Requirements

### Requirement: SelectionVisuals is a separate node from SelectComponent
Health bar and outline mesh generation SHALL be handled by a dedicated `SelectionVisuals` child node, not inline in `SelectComponent._ready()`.

#### Scenario: SelectionVisuals renders vehicle health bar
- **WHEN** a Vehicle-type SelectComponent is selected
- **THEN** SelectionVisuals displays a billboard health bar above the entity

#### Scenario: SelectionVisuals renders structure select box
- **WHEN** a Structure-type SelectComponent is selected
- **THEN** SelectionVisuals displays a 3D corner-line select box with health bar grid

#### Scenario: SelectionVisuals renders infantry select box
- **WHEN** an Infantry-type SelectComponent is selected
- **THEN** SelectionVisuals displays a small quad select box

#### Scenario: SelectComponent delegates to SelectionVisuals
- **WHEN** SelectComponent receives a health_changed signal
- **THEN** it calls SelectionVisuals.update_health_bar() (presentation logic lives in SelectionVisuals)

### Requirement: Fragile relative node path replaced with export
BoundsSystem SHALL use `@export` for the camera pivot reference instead of `get_node_or_null("../MouseHandler/camera_pivot")`.

#### Scenario: Camera bounds work after scene reorganization
- **WHEN** the BoundsSystem node is moved in the scene tree
- **THEN** camera clamping continues to work because the camera pivot is wired via export, not relative path
