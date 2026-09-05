## ADDED Requirements

### Requirement: EntityData pip color for passenger seat pips
EntityData SHALL expose a `pip_color: Color` export (default white) with a `##` doc comment, defining the color of the seat pip drawn for this entity while it rides as a passenger in a transport. Transports and harvesters SHALL NOT require the field (cargo pips are unaffected).

#### Scenario: Infantry entity sets pip_color
- **WHEN** an infantry EntityData sets `pip_color` to a non-default color and that entity boards a transport
- **THEN** the transport's selection overlay draws that entity's seat pip in the configured color

#### Scenario: Default pip_color
- **WHEN** an EntityData leaves `pip_color` unset
- **THEN** the value defaults to white and seat pips for that entity draw white
