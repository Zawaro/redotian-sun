## ADDED Requirements

### Requirement: Power bar derives from rules
The sidebar power bar SHALL read its full-bar scale and fill-curve exponent from the active `GlobalRules` (`power_bar_max_output`, `power_bar_curve_exponent`). When no rules are active it SHALL fall back to a generic default scale of 2000.0 and curve 0.4.

#### Scenario: Rules-driven fill
- **WHEN** the active rules set `power_bar_max_output = 2000.0` and `power_bar_curve_exponent = 0.4`
- **THEN** `output = 2000` yields a displayed fill of 1.0 and `output = 500` yields `(0.25)^0.4`

#### Scenario: No rules fallback
- **WHEN** no GlobalRules are active
- **THEN** the curve uses the 2000.0 / 0.4 fallback and clamps to `[0,1]` without error
