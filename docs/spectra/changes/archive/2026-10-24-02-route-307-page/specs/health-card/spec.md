## MODIFIED Requirements

### Requirement: Invocation and parameters

The system SHALL provide the executable `bin/health-card` accepting `--data DIR`, `--route ID`, `--day YYYY-MM-DD`, and optionally `--also-route ID` (repeatable, the `Id` of a member route counted with the route), `--static-day YYYY-MM-DD`, `--out PATH`, `--inspect-dir DIR`. When `--data` is absent the system SHALL use the environment variable `TURNAROUND_DATA`. When `--static-day` is absent it SHALL equal `--day`. When `--out` is absent the card SHALL be written to standard output. When `--inspect-dir` is absent it SHALL be `tmp/health-card/<route>-<day>` relative to the repository root. The executable SHALL NOT load Rails. The card's route line SHALL list the route `Id` followed by every `--also-route` `Id`, joined by 「・」.

#### Scenario: Defaults applied

- **WHEN** the operator runs `bin/health-card --data /x --route 9001 --day 2026-10-19`
- **THEN** the static snapshot day is 2026-10-19, the card goes to standard output and the inspection files go to `tmp/health-card/9001-2026-10-19`

#### Scenario: Member routes given

- **WHEN** the operator runs `bin/health-card --data /x --route 9001 --also-route 9050 --day 2026-10-23 --static-day 2026-10-23`
- **THEN** the run uses the route `Id`s 9001 and 9050, and the card's route line reads 測試幹線（路線 Id 9001・9050）

#### Scenario: Missing required parameter

- **WHEN** the operator omits `--day`
- **THEN** the usage text is printed to standard error, the exit code is 1 and no file is written
