## ADDED Requirements

### Requirement: Resource files load without parse errors
Every scene (`.tscn`) and data (`.tres`) resource tracked in the project SHALL parse and load without errors under the engine's resource loader. A resource file SHALL use the serialized form its exported properties require and SHALL be loadable as the type implied by its file extension.

#### Scenario: Warhead data uses keyed multiplier dictionaries
- **WHEN** a warhead `.tres` under `resources/warheads/` defines `armor_damage_multipliers`
- **THEN** the property is serialized as a keyed dictionary over armor ids (e.g. `"none"`, `"wood"`, `"light"`, `"heavy"`, `"concrete"`), never as a positional array, and the file loads without a parse error

#### Scenario: Scene assigns meshes by sub-resource reference
- **WHEN** a node in a `.tscn` assigns a mesh or shape property
- **THEN** it uses a `SubResource`/`ExtResource` reference declared in the header, never a bare class name, and the scene loads without a parse error

#### Scenario: Resource extension matches loader
- **WHEN** a tracked file uses a `.tres` extension
- **THEN** the loader can load it (no `[gd_scene]` header fragments saved as `.tres`), and the export scan does not fail with "No loader found"

#### Scenario: Export resource scan passes
- **WHEN** the project is imported headless (`redot --headless --import`) or exported for any target
- **THEN** no resource reports a parse/load error and the export completes