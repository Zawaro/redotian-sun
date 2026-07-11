## ADDED Requirements

### Requirement: Cameo button shows cost tooltip on hover
Each building cameo button in the sidebar SHALL display a tooltip with the building's credit cost when hovered.

#### Scenario: Tooltip shows cost
- **WHEN** the player hovers over a cameo button
- **THEN** the tooltip text displays `$<cost>` where `<cost>` is the building's `EntityData.cost` value

#### Scenario: Tooltip hides on mouse exit
- **WHEN** the player moves the cursor away from the cameo button
- **THEN** the tooltip disappears
