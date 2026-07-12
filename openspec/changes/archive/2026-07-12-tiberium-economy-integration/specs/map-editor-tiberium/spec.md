## ADDED Requirements

### Requirement: Toolbar with toggleable tools
The map editor SHALL display a toolbar row at the top with horizontally arranged buttons: Save, Load, Paint Height, Paint Tiberium, Place Tree, Erase, plus a Strength HSlider and Radius SpinBox.

#### Scenario: Tool layout
- **WHEN** the map editor opens
- **THEN** the toolbar shows `[Save] [Load] | [Paint Height] [Paint Tiberium] [Place Tree] [Erase] | [Strength slider] [Radius spinbox]`

#### Scenario: Radio-button tool selection
- **WHEN** the player clicks a toggleable tool (Paint Height, Paint Tiberium, Place Tree, Erase)
- **THEN** the previously active tool is deactivated, and the clicked tool is activated

### Requirement: Paint Tiberium tool
The editor SHALL paint Tiberium pod entities on cells via click+drag, using the Strength and Radius parameters. Entities are placed at the center of 2×2 unit cells.

#### Scenario: Paint brush on single cell
- **WHEN** Paint Tiberium is active and the player clicks a cell
- **THEN** a pod entity is created via `EntityFactory.create_entity("TIB")` with `tiberium_amount = strength% * max_amount`, positioned at the cell center

#### Scenario: Paint brush radius
- **WHEN** Paint Tiberium is active and Radius = 3
- **THEN** all cells within a 3-cell radius of the clicked cell are painted in the same pass

#### Scenario: Paint adds to existing pod
- **WHEN** a cell already has a pod entity and the player paints over it
- **THEN** the pod's amount increases by `strength% * max_amount`, capped at `tiberium_max_amount`

### Requirement: Erase tool
The editor SHALL reduce Tiberium amount on cells via click+drag, using Strength and Radius.

#### Scenario: Erase reduces amount
- **WHEN** Erase is active and the player clicks a cell with a pod
- **THEN** the pod's amount is reduced by `strength% * max_amount`

#### Scenario: Erase despawns at zero
- **WHEN** Erase reduces a pod's amount to ≤ 0
- **THEN** the pod entity is removed from the scene

### Requirement: Place Tree tool
The editor SHALL place a TiberiumTree entity on a single-clicked cell. If the cell is occupied, the existing entity is replaced by the tree.

#### Scenario: Place tree on empty cell
- **WHEN** Place Tree is active and the player clicks an empty cell
- **THEN** a TiberiumTree entity is created via `EntityFactory.create_entity` at that cell's center

#### Scenario: Place tree replaces existing entity
- **WHEN** Place Tree is active and the player clicks an occupied cell
- **THEN** the existing entity is removed and a TiberiumTree entity is placed in its cell

#### Scenario: Place tree is single-click only
- **WHEN** the player drags while Place Tree is active
- **THEN** no entities are placed (only single-click triggers)

### Requirement: Entity tracking
The editor SHALL track painted/placed entities in a local `_painted_entities` dictionary keyed by cell position string.

#### Scenario: Track after paint
- **WHEN** a pod is painted on cell "5,3"
- **THEN** `_painted_entities["5,3"]` contains `{ node, data }` for that pod

#### Scenario: Track after erase
- **WHEN** a pod is erased and its entity removed
- **THEN** the entry is removed from `_painted_entities`

#### Scenario: Track after tree replacement
- **WHEN** a tree replaces an entity on a cell
- **THEN** the old entry is removed and the new tree entry is added

### Requirement: Editor visual feedback
Painted/placed entities SHALL be visible in the editor immediately (real entities with placeholder art).

#### Scenario: Pod visible after paint
- **WHEN** a pod is painted
- **THEN** a pod entity with placeholder cube art appears at the cell center

#### Scenario: Tree visible after place
- **WHEN** a tree is placed
- **THEN** a thin pole placeholder appears at the cell center
