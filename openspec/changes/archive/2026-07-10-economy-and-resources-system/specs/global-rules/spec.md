## ADDED Requirements

### Requirement: Starting credits constant
GlobalRules SHALL contain `starting_credits: int` for the default credit balance at game start.

#### Scenario: Skirmish starting credits
- **WHEN** GlobalRules is loaded with `starting_credits = 0`
- **THEN** players start with 0 credits (skirmish default)

#### Scenario: Campaign starting credits
- **WHEN** a mission overrides `starting_credits = 2000`
- **THEN** the player starts that mission with 2000 credits

### Requirement: Tiberium value constant
GlobalRules SHALL contain `tiberium_value: float` defining credits earned per unit of tiberium refined.

#### Scenario: Default tiberium value
- **WHEN** GlobalRules is loaded with `tiberium_value = 1.0`
- **THEN** each tiberium unit refined into credits adds 1 credit

#### Scenario: Modified tiberium value
- **WHEN** a mod sets `tiberium_value = 1.5`
- **THEN** each tiberium unit refined adds 1.5 credits

### Requirement: Harvester fill rate constant
GlobalRules SHALL contain `harvester_fill_rate: float` defining tiberium units collected per second from a node.

#### Scenario: Default fill rate
- **WHEN** GlobalRules is loaded with `harvester_fill_rate = 2.0`
- **THEN** a harvester collects 2 tiberium units per second from a node
