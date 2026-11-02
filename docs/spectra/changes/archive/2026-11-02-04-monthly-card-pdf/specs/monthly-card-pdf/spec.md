## Purpose

Print the month card of each route once its month's data is complete, keep the printed file unchanged, and let anyone download it. It exists so that a month card can be cited: everyone who fetches it gets the same bytes, and any correction leaves a record.

## ADDED Requirements

### Requirement: Monthly cards command

The system SHALL provide the executable `bin/monthly-cards`, run from a checkout of this repository on the machine that holds the raw files, connecting to the production database over the same ssh port forward and migration version check as `bin/nightly-load` and holding the same lock, so that neither runs while the other does. It SHALL refuse to run unless `RAILS_ENV` is production. Without arguments it SHALL print one line per page route and month from `first_month` of `config/route_cards.yml` to the previous Taipei month, naming the state: printed with its version, ready, waiting with the waiting days, needing a reload with the days, or holding a local copy the database lacks with its versions. It SHALL NOT write anything without arguments. Any argument other than `--print`, `--revise`, `--sample` or `--restore` SHALL be a usage error, and a malformed `config/route_cards.yml` SHALL stop the command with a message before the forward is opened.

#### Scenario: Plan only

- **WHEN** the command runs without arguments in the Taipei month 2026-12 with `first_month` 2026-11
- **THEN** it prints one line per page route for 2026-11 and writes nothing

#### Scenario: No month due

- **WHEN** the command runs without arguments in the Taipei month 2026-11 with `first_month` 2026-11
- **THEN** it says the first month is 2026-11, prints no line for a route and exits with status 0

#### Scenario: Unknown argument

- **WHEN** the command runs with `--foo`
- **THEN** it prints the usage, exits with status 1 and opens no forward

#### Scenario: Wrong environment

- **WHEN** `RAILS_ENV` is development
- **THEN** the executable says that it writes production and exits with status 1 before Rails is loaded

#### Scenario: Another run holds the lock

- **WHEN** another `bin/nightly-load` or `bin/monthly-cards` holds the lock
- **THEN** the command says so, opens no forward and exits with status 0

### Requirement: Printing a month that is ready

With `--print`, for each page route and month from `first_month` to the previous Taipei month that has no printed version, the command SHALL compute the coverage of `monthly-card`. A month that is not ready SHALL be skipped. A month with a covered day that needs loading again SHALL be skipped and named. For a ready month it SHALL store the coverage in an unprinted route card, check the month card page, print it and store the result. A printed version SHALL NOT be changed. The PDF bytes SHALL be stored apart from `route_cards`, in `route_card_pdfs`, which SHALL NOT reference `route_days`. A failure on one route and month SHALL NOT stop the others, and the exit status SHALL be non-zero when any failed; a skipped month SHALL NOT make the exit status non-zero.

#### Scenario: Month ready

- **WHEN** 2026-11 of route 15373 is ready and has no printed version
- **THEN** version 1 of its route card has a PDF, a SHA-256, a byte count, a summary, a program version and a print time

#### Scenario: Already printed

- **WHEN** 2026-11 of route 15373 has a printed version 1 and `--print` runs again
- **THEN** the printer is not called for it and the row is unchanged

#### Scenario: Still waiting

- **WHEN** a day of 2026-11 is waiting
- **THEN** the printer is not called, the output names the day and the exit status is 0

#### Scenario: A day not loaded again

- **WHEN** 2026-11 of route 15373 is ready and its route day of 2026-11-05 has `rest_windows_loaded` false
- **THEN** the printer is not called, the output names 11-05 and the exit status is 0

#### Scenario: One route fails

- **WHEN** printing route 15373 fails and route 10712 is ready
- **THEN** route 10712 is printed, the output names the failure of 15373, and the exit status is 1

#### Scenario: Current month

- **WHEN** the Taipei date is 2026-12-15
- **THEN** 2026-12 is not printed and has no line in the plan

#### Scenario: Not a derived table

- **WHEN** `bin/push-derived` lists the derived tables
- **THEN** `route_card_pdfs` is not among them

### Requirement: Checks around the printer

Before printing, the system SHALL fetch the month card page and SHALL treat it as a failure unless the response is 200, its `turnaround-card` meta equals the route `Id`, the month and the version, and the page carries no `data-card-incomplete` notice. After printing, the system SHALL treat it as a failure unless Chrome exited with status 0 within its time limit, the file starts with `%PDF-` and it is at least 100 KB. A failure SHALL leave the route card without a PDF. The stored summary and program version SHALL be the ones the checked page carries.

#### Scenario: Error page

- **WHEN** the month card page answers 500
- **THEN** Chrome is not started, the output names the status and no PDF is stored

#### Scenario: Another month's page

- **WHEN** the page's `turnaround-card` meta names another month
- **THEN** Chrome is not started and no PDF is stored

#### Scenario: Figures incomplete

- **WHEN** the page carries a `data-card-incomplete` notice
- **THEN** Chrome is not started and no PDF is stored

#### Scenario: Not a PDF

- **WHEN** Chrome exits with status 0 and the file is 2 KB of text
- **THEN** no PDF is stored and the output says the file is not a usable PDF

#### Scenario: Chrome missing

- **WHEN** the configured Chrome executable does not exist
- **THEN** the route and month fail with a message naming `CHROME_PATH`

#### Scenario: Chrome never finishes

- **WHEN** Chrome is still running at its time limit
- **THEN** Chrome is stopped, no PDF is stored and the output says it ran out of time

#### Scenario: A page of another program version

- **WHEN** the page carries the program version abc1234 and the summary with 21 weekdays, and the command runs from another commit
- **THEN** the stored program version is abc1234 and the stored summary has 21 weekdays

### Requirement: Local copy of a printed card

After the database write succeeds, the system SHALL write the PDF to `<TURNAROUND_DATA>/cards/<YYYY-MM>/<route Id>-v<version>.pdf` and, beside it, a JSON file of the same name holding the route, the month, the version, the coverage, the summary, the program version, the print time, the revision reason, the SHA-256 and the byte count. It SHALL NOT overwrite an existing file: an existing file SHALL be a failure naming it. With `--print`, a printed version whose files are missing SHALL get them from the stored bytes without printing. A month with a local copy of a version the database has not printed SHALL NOT be printed or revised: the command SHALL name that version and `--restore`, and the exit status SHALL be non-zero, without arguments as well as with `--print`.

#### Scenario: Local copy

- **WHEN** route 15373 of 2026-11 is stored as version 1
- **THEN** `<TURNAROUND_DATA>/cards/2026-11/15373-v1.pdf` has the same SHA-256 as the stored bytes and `15373-v1.json` beside it holds the same SHA-256 and the row's print time

#### Scenario: Database rebuilt

- **WHEN** `<TURNAROUND_DATA>/cards/2026-11/15373-v1.pdf` exists, the database has no printed version of that month and `--print` runs
- **THEN** the printer is not called, the file is byte for byte unchanged, the output names version 1 and `--restore`, and the exit status is 1

#### Scenario: An earlier write failed

- **WHEN** version 1 of 2026-11 of route 15373 is printed, its local files are missing and `--print` runs
- **THEN** the printer is not called and `15373-v1.pdf` has the same SHA-256 as the stored bytes

### Requirement: Restoring printed cards

`--restore` SHALL go through the local copies under `<TURNAROUND_DATA>/cards`. A copy whose PDF has the SHA-256 its JSON names, of a version the database has not printed, SHALL be stored with the row as its JSON gives it. A version printed with the same SHA-256 SHALL be left as it is. A version printed with another SHA-256, a PDF that does not match its JSON, or a PDF without its JSON SHALL be a failure naming the file and SHALL change nothing for it; the other copies SHALL still be restored and the exit status SHALL be non-zero.

#### Scenario: Rebuilt database

- **WHEN** a local copy of version 2 of 2026-11 of route 15373 exists with the reason 資料重算, the database has no row for it and `--restore` runs
- **THEN** version 2 has the stored bytes of the copy and the coverage, summary, program version, print time and reason of its JSON, and a following `--print` does not call the printer for that month

#### Scenario: Already there

- **WHEN** version 1 is printed with the same SHA-256 as its local copy
- **THEN** the row is unchanged and the exit status is 0

#### Scenario: Different bytes

- **WHEN** version 1 is printed with a SHA-256 other than that of its local copy
- **THEN** the row is unchanged, the output names the file and the exit status is 1

#### Scenario: Damaged copy

- **WHEN** a local PDF does not have the SHA-256 its JSON names and another route's copy is fine
- **THEN** the damaged one is not stored and is named, the other is stored, and the exit status is 1

### Requirement: Corrected versions

`--revise` SHALL take `ROUTE`, `MONTH` and `REASON` from the environment, all required, and SHALL add a route card with the next version number and that reason, going through the same checks, even when the month was printed before. It SHALL NOT change earlier versions. A month without a printed version SHALL be a usage error. A coverage that is not ready SHALL be a failure that adds nothing. A revision that failed SHALL leave its route card without a PDF, and the next `--revise` of that month SHALL use that route card with the new reason.

#### Scenario: Revise a printed month

- **WHEN** `ROUTE=15373 MONTH=2026-11 REASON=資料重算 bin/monthly-cards --revise` runs and version 1 is printed
- **THEN** version 2 exists with the reason 資料重算 and a PDF, and version 1 is byte for byte unchanged

#### Scenario: Reason missing

- **WHEN** `REASON` is absent
- **THEN** the usage is printed, nothing is written and the exit status is 1

#### Scenario: After a failed revision

- **WHEN** version 2 of a month has no PDF because printing failed and `--revise` runs again with another reason
- **THEN** version 2 has the new reason and a PDF and no version 3 exists

### Requirement: Sample print

`--sample` SHALL take `ROUTE`, `MONTH` and `OUT` from the environment, all required, and SHALL write the printed file to `OUT` going through the same checks, without regard to `first_month`, and without storing any PDF. A route card row added only to open the page SHALL be removed afterwards; an existing row SHALL be left as it was. A coverage that is not ready SHALL be printed anyway with a line naming the waiting days.

#### Scenario: A month before the first month

- **WHEN** `ROUTE=15373 MONTH=2026-10 OUT=/tmp/x.pdf bin/monthly-cards --sample` runs with `first_month` 2026-11 and no row exists
- **THEN** `/tmp/x.pdf` is written and `route_cards` has no row for that route and month afterwards

#### Scenario: A print that fails

- **WHEN** the same command runs and the printer fails
- **THEN** the output names the failure, the exit status is 1 and `route_cards` has no row for that route and month afterwards

### Requirement: Downloading a printed card

The system SHALL serve the latest printed version of a month at `/routes/<Id>/cards/<YYYY-MM>.pdf` as `application/pdf`, as an attachment named `turnaround-<Id>-<YYYY-MM>.pdf`, with the SHA-256 as its entity tag and a public cache lifetime of one day. The parameter `version` SHALL select a printed version. The response SHALL be 404 when the route is not a page route, when the month has no printed version or when the selected version is not printed. A request whose `If-None-Match` names that entity tag SHALL be answered 304 without reading the PDF bytes. No other page SHALL read the PDF bytes.

#### Scenario: Latest version

- **WHEN** 2026-11 of route 15373 has printed versions 1 and 2 and the PDF address is requested
- **THEN** the body is version 2 and the file name is turnaround-15373-2026-11.pdf

#### Scenario: Older version

- **WHEN** the same address is requested with `version=1`
- **THEN** the body is version 1

#### Scenario: Not printed yet

- **WHEN** 2026-11 has a route card without a PDF
- **THEN** the PDF address answers 404

#### Scenario: Not changed

- **WHEN** the PDF address is requested with `If-None-Match` naming the SHA-256 of the latest version
- **THEN** the response is 304 and `route_card_pdfs` is not read

#### Scenario: The month card page of a printed month

- **WHEN** the month card page of a route with printed months is requested
- **THEN** `route_card_pdfs` is not read

### Requirement: Month card list

The system SHALL serve at `/routes/<Id>/cards` a list of the printed months of a page route, newest first, each with its weekdays and holidays, its missing days, 部分月份 when partial, a link to its PDF with its size, and for a corrected month the reason and a link to each earlier version. It SHALL begin with one sentence saying what the card is. Without a printed month it SHALL say which month comes first and when it is printed, the month being the later of `first_month` and the previous Taipei month. The response SHALL be 404 for a route that is not a page route. Reading the list SHALL NOT load the PDF bytes.

#### Scenario: One printed month

- **WHEN** route 15373 has 2026-11 printed with 21 weekdays, 9 holidays and 2026-11-05 missing
- **THEN** the list shows one row with 21 個平日、9 個假日, 少 11-05 and a link to `/routes/15373/cards/2026-11.pdf`

#### Scenario: Corrected month

- **WHEN** 2026-11 has printed versions 1 and 2 with the reason 資料重算
- **THEN** the row links to `/routes/15373/cards/2026-11.pdf`, shows 資料重算 and links to `/routes/15373/cards/2026-11.pdf?version=1`

#### Scenario: Nothing printed yet

- **WHEN** the Taipei date is 2026-11-02, `first_month` is 2026-11 and the route has no printed month
- **THEN** the list says 第一份是 2026 年 11 月，12 月初印出來

#### Scenario: A row without a PDF

- **WHEN** a route card of 2026-12 has no PDF yet
- **THEN** it does not appear in the list

#### Scenario: Member route

- **WHEN** `/routes/19108/cards` is requested and 19108 is a member route
- **THEN** the response is 404
