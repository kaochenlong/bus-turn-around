## ADDED Requirements

### Requirement: Data limitation of depot inspection scores

The data limitations block of every route page SHALL include one item stating that the depot inspection scores are what 臺北市公共運輸處 recorded when inspecting the operators' stations for the evaluation, not the facilities of the turnaround point; that whether a vehicle returns to its depot during a layover is not measured; that the scores are copied from the report's appendix with both printed columns kept apart, neither averaged nor interpreted; and that the list covers only the stations inspected that term, so a station absent from it is not known to lack rest facilities.

#### Scenario: Item present on a route page

- **WHEN** `/routes/9001` is requested and 9001 has stored days
- **THEN** the data limitations block contains an item mentioning 調度站查核分數, 不是折返點 and 兩欄
