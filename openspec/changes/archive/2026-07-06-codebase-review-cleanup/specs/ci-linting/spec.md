## ADDED Requirements

### Requirement: CI runs GDScript lint on every push and PR
The GitHub Actions workflow SHALL include a lint job that runs `gdlint` on all GDScript files.

#### Scenario: Lint passes on clean code
- **WHEN** a push or PR contains no style violations
- **THEN** the lint job succeeds

#### Scenario: Lint catches PascalCase variable
- **WHEN** a GDScript file contains `var MyVariable = 5`
- **THEN** the lint job fails with a naming convention violation

### Requirement: CI checks GDScript formatting on every push and PR
The GitHub Actions workflow SHALL include a format check that runs `gdformat --check` on all GDScript files.

#### Scenario: Format check passes on formatted code
- **WHEN** all GDScript files conform to gdformat style
- **THEN** the format check job succeeds

#### Scenario: Format check catches unformatted code
- **WHEN** a GDScript file has inconsistent indentation or spacing
- **THEN** the format check job fails with the offending file listed
