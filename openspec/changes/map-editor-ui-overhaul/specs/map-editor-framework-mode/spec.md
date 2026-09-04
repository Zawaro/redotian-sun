## ADDED Requirements

### Requirement: Framework mode toggle
The editor SHALL provide a Framework mode toggle (top-bar tool button, mirrored by a View menu check item). When enabled, terrain cells SHALL render as flat placeholder tiles colored by land type (marble-madness style) instead of resolved art; when disabled, normal art resolution returns. Framework mode SHALL be a render-only state — it SHALL NOT mutate any terrain data.

#### Scenario: Toggle renders placeholders
- **WHEN** the player enables Framework mode
- **THEN** every rendered cell displays as a flat tile colored by its land type, including pinned cliff cells

#### Scenario: Toggle restores art
- **WHEN** the player disables Framework mode
- **THEN** cells render their resolved art again with no data having changed

#### Scenario: Edits stay visible in framework view
- **WHEN** Framework mode is on and the player paints a LAT
- **THEN** the painted cells change placeholder color immediately

### Requirement: Framework colors distinguish land types
Framework placeholder colors SHALL be distinct per land type (including the cliff/resource types) so surfaces are tellable apart in the placeholder view.

#### Scenario: Distinct colors
- **WHEN** Framework mode renders cells of clear, water, and cliff types side by side
- **THEN** the three placeholder colors are visually distinct
