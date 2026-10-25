## ADDED Requirements

### Requirement: Nightly load command

The system SHALL provide the executable `bin/nightly-load`, run from a checkout of this repository on the machine that holds the raw files, which loads the route days the production database lacks by running the route day loader of `derived:load` against the production database over an ssh port forward. Without arguments it SHALL print the plan and SHALL NOT write to the database. With `--load` it SHALL load the selected route days. `--recompute` SHALL be accepted alone or together with `--load` and includes the stored route days in the selection. The environment variable `ROUTE` (a page route `Id`) SHALL be accepted only together with `--recompute`; a `ROUTE` listed under another route's `member_routes` SHALL be a usage error whose message names the page route to use instead, and a `ROUTE` that is not a page route SHALL be a usage error. Any other argument SHALL be a usage error. The raw data root SHALL come only from the environment variable `TURNAROUND_DATA`, and the database password from `WEBSITE_DATABASE_PASSWORD`; when either is missing the command SHALL print the usage and exit with a non-zero status. The executable SHALL run Rails in the `production` environment: it SHALL set `RAILS_ENV` to `production` when the variable is unset and SHALL stop with a message when it is set to anything else; it SHALL set `SECRET_KEY_BASE_DUMMY` to `1` when neither `SECRET_KEY_BASE` nor `SECRET_KEY_BASE_DUMMY` is set; and it SHALL default `DB_HOST` to `127.0.0.1` and `DB_PORT` to the value of `TUNNEL_PORT`, itself defaulting to a fixed local port. The DuckDB CLI SHALL be required on the `PATH` with the same message as `derived:load`. A usage error, a missing environment variable, an invalid day configuration or a missing DuckDB CLI SHALL stop the command before the port forward is opened.

Before reading the database the command SHALL open an ssh port forward from `127.0.0.1:<DB_PORT>` to the database port on the loopback interface (`127.0.0.1`) of the host that `config/deploy.yml` names as the database accessory's host, as the configured ssh user (`root` when none is configured), with `BatchMode=yes`, `ExitOnForwardFailure=yes` and without a remote command, SHALL wait until the local port accepts a connection, and SHALL close the forward when the command finishes, whatever the outcome. When ssh exits before the port accepts a connection, or the port does not accept one within 20 seconds, the command SHALL print the reason and exit with a non-zero status without reading or writing the database.

The plan SHALL print, in this order: the target as `<user>@<host>` with the database name, and whether the migration versions agree; the page routes; the day range from the first day to the last candidate day, marked as the last day whose read window is over, with every skipped day in that range and its reason; the number of stored route days and, per route, the first day, the last day and the number of days; the number of route days to load with the route `Id`s grouped by day; the days whose raw files are incomplete, one line per day with the message of the day eligibility check; and, when `--load` was not given, a last line that says production was not touched and that `--load` loads. The exit status SHALL be 0 when there is nothing to load or every selected route day was written and no candidate day had incomplete raw files, and non-zero otherwise.

#### Scenario: Usage errors

- **WHEN** the command runs with any of the inputs below
- **THEN** it prints the usage with the reason, exits with a non-zero status, opens no port forward and writes nothing

##### Example: inputs that are usage errors

| Input | Reason |
| --- | --- |
| `--push` | unknown argument |
| `--load` without `TURNAROUND_DATA` | missing data root |
| `--load` without `WEBSITE_DATABASE_PASSWORD` | missing database password |
| `ROUTE=9001` without `--recompute` | `ROUTE` only narrows a recompute |
| `ROUTE=9050 --recompute` when 9050 is listed under route 9001's `member_routes` | message names 9001 as the page route to use |
| `ROUTE=4242 --recompute` when 4242 is not a page route | not a page route |

#### Scenario: Environment other than production

- **WHEN** `bin/nightly-load` is started with `RAILS_ENV=test`
- **THEN** it prints that it writes production and that `RAILS_ENV` has to be `production`, and exits with a non-zero status before Rails is loaded

#### Scenario: Plan writes nothing

- **WHEN** the command runs without `--load` while the fixture day 2026-10-19 is a candidate that the database lacks for route 9001
- **THEN** it prints 2026-10-19 with route 9001 under the route days to load, prints the last line naming `--load`, the loader is not invoked, and the row counts of `route_days` and every table linked to it are unchanged

#### Scenario: Port forward cannot be opened

- **WHEN** the ssh process exits before the local port accepts a connection
- **THEN** the command prints that the forward failed together with what ssh printed, exits with a non-zero status, and neither reads nor writes the database

#### Scenario: Forward argument list

- **WHEN** `config/deploy.yml` names `203.0.113.5` as the database accessory's host, configures no ssh user, and `DB_PORT` is set
- **THEN** the forward is opened with `ssh -o BatchMode=yes -o ExitOnForwardFailure=yes … -N -L 127.0.0.1:<DB_PORT>:127.0.0.1:<database port> root@203.0.113.5`, and the process is terminated when the command finishes, also when the command failed

### Requirement: Route days selected for loading

The command SHALL select the route days to load as the product of the page routes (the keys of the route list configuration, in configuration order, or only `ROUTE` when given) and the candidate days, minus the route days the database already stores, unless `--recompute` is given, in which case the stored route days are included. The candidate days SHALL run from the configured first day to the last candidate day, excluding the configured skipped days. The last candidate day SHALL be the Taipei date of the current time minus two hours, minus one day, so that a day becomes a candidate at 02:00 Taipei time of the following day and not before. Every candidate day SHALL pass the day eligibility check of `derived:load` once; a day that fails it SHALL be reported with the check's message, SHALL have none of its route days loaded, and SHALL count as a day with incomplete raw files. The route days SHALL be loaded in ascending day order and, within a day, in the configuration order of the routes.

#### Scenario: Last candidate day follows the clock

- **WHEN** the plan is computed at the Taipei times below with the first day 2026-10-19 and no skipped days
- **THEN** the day range ends at the last candidate day shown

##### Example: 02:00 is the boundary

| Current time (Taipei) | Last candidate day |
| --- | --- |
| 2026-10-26 01:59 | 2026-10-24 |
| 2026-10-26 02:00 | 2026-10-25 |
| 2026-10-26 23:59 | 2026-10-25 |

#### Scenario: Stored and skipped route days are left out

- **WHEN** the page routes are 9001 and 9100, the candidate days are 2026-10-19 to 2026-10-23, 2026-10-20 is skipped with a reason, and the database stores route 9001 on 2026-10-19 and route 9100 on 2026-10-19 and 2026-10-21
- **THEN** the route days to load are, in order, 9001 and 9100 on 2026-10-21 (only 9001), 2026-10-22 (both) and 2026-10-23 (both), the skipped day is printed with its reason, and the stored days are printed per route

##### Example: the order of the route days to load

- **GIVEN** the configuration lists 9001 before 9100
- **WHEN** the selection above is made
- **THEN** the route days are loaded in the order (2026-10-21, 9001), (2026-10-22, 9001), (2026-10-22, 9100), (2026-10-23, 9001), (2026-10-23, 9100)

#### Scenario: Recompute includes the stored route days

- **WHEN** the command runs with `--recompute` on the selection above
- **THEN** the route days to load also include (2026-10-19, 9001), (2026-10-19, 9100) and (2026-10-21, 9100), and 2026-10-20 is still left out

#### Scenario: Recompute narrowed to one route

- **WHEN** the command runs with `--recompute` and `ROUTE=9100` on the selection above
- **THEN** only route 9100's route days are selected: 2026-10-19, 2026-10-21, 2026-10-22 and 2026-10-23

#### Scenario: Day with incomplete raw files

- **WHEN** a candidate day fails the day eligibility check of `derived:load`
- **THEN** the day is printed with the check's message, none of its route days is loaded, the other candidate days are still loaded, and the exit status is non-zero

### Requirement: Derived days configuration

The system SHALL read the first day and the skipped days from `config/derived_days.yml`, a file with exactly two keys: `first_day`, a date written `YYYY-MM-DD`, and `skipped_days`, a mapping from dates written `YYYY-MM-DD` to a non-empty reason. The mapping SHALL be allowed to be empty. The file SHALL NOT have per-environment sections. A missing key, an extra key, a malformed date or a blank reason SHALL make `bin/nightly-load` print what is wrong, exit with a non-zero status and open no port forward.

#### Scenario: Valid configuration

- **WHEN** the file has `first_day: 2026-10-19` and `skipped_days` mapping 2026-10-23 and 2026-10-24 each to a reason
- **THEN** the first day is 2026-10-19 and both days are skipped with those reasons

#### Scenario: Invalid configuration

- **WHEN** the file has any of the faults below
- **THEN** the command prints the fault, exits with a non-zero status and opens no port forward

##### Example: faults

| File content | Fault |
| --- | --- |
| no `first_day` key | missing key |
| `first_day: 2026-13-01` | malformed date |
| `skipped_days` with the key `2026-10-23` and an empty value | blank reason |
| `skipped_days` with the key `yesterday` | malformed date |
| an extra key `last_day` | extra key |

### Requirement: Migration versions agree before loading

After opening the port forward and before writing anything, the command SHALL compare the set of versions in the database's `schema_migrations` with the set of versions of the migration files of the checkout. When the sets differ, the command SHALL print the versions only the database has and the versions only the checkout has, exit with a non-zero status and write nothing.

#### Scenario: Database has a version the checkout lacks

- **WHEN** `schema_migrations` holds the version 20991231000000 and no migration file has it
- **THEN** the command prints that version as present only in the database, exits with a non-zero status, and the loader is not invoked

#### Scenario: Checkout has a version the database lacks

- **WHEN** the checkout has a migration version that `schema_migrations` does not hold
- **THEN** the command prints that version as present only in the checkout, exits with a non-zero status, and the loader is not invoked

#### Scenario: Versions agree

- **WHEN** both sets are equal
- **THEN** the plan says the versions agree and the command continues

### Requirement: One failing route day does not stop the others

With `--load`, the command SHALL load every selected route day with the route day loader of `derived:load`, each in the loader's own transaction. When a route day fails, the command SHALL print the day, the route `Id` and the failure message, and SHALL continue with the next route day; route days written before and after it SHALL stay. For every route day written the command SHALL print the day, the route `Id` and the counts the loader returns, worded as `derived:load` words them. The command SHALL end with one line giving the numbers of route days written, route days failed and days with incomplete raw files, and SHALL exit with a non-zero status when either of the last two is not zero.

#### Scenario: One route day fails

- **WHEN** route days (2026-10-19, 9001), (2026-10-19, 9100) and (2026-10-23, 9001) are selected and the loader raises for (2026-10-19, 9100)
- **THEN** the output has a failure line naming 2026-10-19 and 9100 with the message, the other two route days are written, the last line reports 2 written, 1 failed and 0 days with incomplete raw files, and the exit status is non-zero

#### Scenario: Fixture route day written

- **WHEN** the command runs with `--load` on the fixture data root with route 9001 and the single candidate day 2026-10-19
- **THEN** it prints `2026-10-19 9001 寫入：趟次 27、折返停留 18、趟次站 96、兩端公廁 5 間、靜止格 1 格`, the database stores that route day, the last line reports 1 written, 0 failed and 0 days with incomplete raw files, and the exit status is 0

#### Scenario: Nothing to load

- **WHEN** every selected route day is already stored and no candidate day has incomplete raw files
- **THEN** the command prints that there is nothing to load and exits with status 0

### Requirement: One load at a time

Before opening the port forward, the command SHALL take an exclusive, non-blocking lock on the file `tmp/nightly-load.lock` under the checkout root and hold it until it finishes. When the lock is held by another process, the command SHALL print `另一個 bin/nightly-load 還在跑，這次不做`, exit with status 0, and open no port forward.

#### Scenario: Lock held

- **WHEN** another process holds the lock on `tmp/nightly-load.lock` and the command runs with `--load`
- **THEN** it prints `另一個 bin/nightly-load 還在跑，這次不做`, exits with status 0, opens no port forward and the loader is not invoked

#### Scenario: Lock released

- **WHEN** a run has finished, with or without failures
- **THEN** the lock is released and the next run takes it

### Requirement: Push refuses to drop route days it does not have

`bin/push-derived --push` SHALL, after its existing version and schema checks and before dumping, read the `(route_id, day)` pairs of the production `route_days` and compare them with this database's. When production has a pair this database lacks, the command SHALL print those route days per route as the route `Id`, the first day, the last day and the number of days, SHALL say that they were written into production by the nightly load, that a push would delete them and that a recompute is `bin/nightly-load --recompute` on the machine that holds the raw files, SHALL exit with a non-zero status, and SHALL NOT dump, back up or replace anything. When production has no such pair, the behavior of the push SHALL be unchanged.

#### Scenario: Production has a day this database lacks

- **WHEN** this database stores route 9001 on 2026-10-19 and production stores route 9001 on 2026-10-19 and 2026-10-20
- **THEN** `--push` prints route 9001 with 2026-10-20 to 2026-10-20 and 1 day, names `bin/nightly-load --recompute`, exits with a non-zero status, and no dump, backup or replace command is run

#### Scenario: Production has nothing this database lacks

- **WHEN** production stores exactly the route days this database stores
- **THEN** `--push` proceeds to dump, back up, replace and verify as before
