## MODIFIED Requirements

### Requirement: Day coverage

With `range=day` the page SHALL cover the selected day. With `range=7d` it SHALL cover the selected day and those of the six Taipei days before it that are stored for the route and have the same day type as the selected day, as defined by `day-types`. The page SHALL state whether the covered days are weekdays or holidays in a day type tag, and SHALL list each covered date as a tag whose text is the date with its day of week and nothing else. A covered date with a calendar note SHALL carry the note as the title of its tag, shown when a pointer rests on the tag, and a covered date without a note SHALL carry no title. The day type tag and every date tag SHALL be green when the covered days are holidays and SHALL keep the neutral grey of the page's tags when they are weekdays. The page SHALL link to the latest stored day on or before the selected day whose day type differs from the selected day's, keeping the range and naming that day and its day type; when there is no such day, the page SHALL NOT show that link. When the selected day is not stored, the page SHALL respond 200, state that the day has no data and list the stored days.

#### Scenario: Seven days with gaps

- **WHEN** route 9001 has the stored weekdays 2026-10-19, 2026-10-20 and 2026-10-22 and a visitor requests `?day=2026-10-22&range=7d`
- **THEN** the page covers exactly 2026-10-19, 2026-10-20 and 2026-10-22, states that they are weekdays and lists them with their days of week

#### Scenario: Seven days keep the selected day's type

- **WHEN** route 9001 has stored weekdays and holidays in the same seven Taipei days and a visitor selects a holiday with `range=7d`
- **THEN** the page covers only the holidays of those seven days and links to the latest weekday before them

##### Example: the Retrocession Day weekend

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24, 2026-10-25 and 2026-10-26, the last with the note 補假
- **WHEN** a visitor requests `/routes/9001?day=2026-10-26&range=7d`
- **THEN** the page states holidays, covers exactly the tags 2026-10-24（六）, 2026-10-25（日） and 2026-10-26（一）, the last with the title 補假 and the other two with no title, and links to `/routes/9001?day=2026-10-23&range=7d`, naming 2026-10-23（五） and weekdays

#### Scenario: No day of the other type before the selected day

- **WHEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24 to 2026-10-26, and a visitor requests `?day=2026-10-23&range=7d`
- **THEN** the page covers 2026-10-19 to 2026-10-23, states weekdays and shows no link to holidays

#### Scenario: One day states its type

- **WHEN** route 9001 has the stored weekday 2026-10-23 and the stored holiday 2026-10-26 with the note 補假, and a visitor requests `/routes/9001` without parameters
- **THEN** the page covers 2026-10-26, states that it is a holiday, shows the tag 2026-10-26（一） with the title 補假 and links to `/routes/9001?day=2026-10-23&range=day`

#### Scenario: Tag colour follows the day type

- **WHEN** a visitor requests a day of route 9001 with `range=7d`
- **THEN** the day type tag and every date tag are green when the covered days are holidays and grey when they are weekdays

##### Example: both day types

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24 to 2026-10-26

| Request | Day type tag | Date tags |
| --- | --- | --- |
| `?day=2026-10-26&range=7d` | 假日, green | 2026-10-24（六）, 2026-10-25（日）, 2026-10-26（一）, all green |
| `?day=2026-10-23&range=7d` | 平日, grey | 2026-10-19（一） to 2026-10-23（五）, all grey |

#### Scenario: Day without data

- **WHEN** a visitor requests `?day=2026-10-25` for route 9001 and that day is not stored
- **THEN** the response is 200, the page says the day has no data and lists the stored days
