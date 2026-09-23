## ADDED Requirements

### Requirement: Bridge component attached to bridge overlay entities
`EntityFactory` SHALL attach a `BridgeComponent` to an entity whose `EntityData` declares a bridge kind. The component SHALL join the `"bridge"` group so the live registry resolves the entity's `(cell, level)` surface, and SHALL expose the entity's bridge kind (low/high/rail), end flag, piece identifier, deck level, and walkable surface height. Non-bridge entities SHALL NOT receive the component. The attach branch SHALL pass the entity's deck level and kind into the component.

#### Scenario: Bridge entity gets component
- **WHEN** a bridge overlay entity is created
- **THEN** it has a `BridgeComponent` and is a member of the `"bridge"` group

#### Scenario: Non-bridge entity unaffected
- **WHEN** a non-bridge entity is created
- **THEN** it has no `BridgeComponent` and is not in the `"bridge"` group

#### Scenario: Component publishes deck surface data
- **WHEN** a high bridge entity's component resolves its surface
- **THEN** it reports the deck level, kind, and the surface height (ground plus `bridge_rise`)

#### Scenario: Rail bridge attaches as high
- **WHEN** a rail bridge entity is created
- **THEN** its component reports the rail kind on a high deck level
