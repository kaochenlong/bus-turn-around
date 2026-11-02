## Why

這個 change 服務三樣交付物的第一樣路線健檢卡：月卡要有一段班表對照，把公告的班距跟量到的發車擺在一起。需要的資料是每天靜態快照裡的 `GetSemiTimeTable.gz`（機動班次時刻表，data.gov.tw/dataset/129027）與 `GetTimeTable.gz`（預定班表資訊，data.gov.tw/dataset/129028），以及 `bus_event` 重建的趟次。這兩支檔 n-gear 每天都抓，但沒有進衍生表，Rails 只查衍生表（`docs/decisions.md` 第 2 條），所以網站讀不到。`run-time-vs-cycle` 的非目標早就記了這件事要另開 change，當時留了一句「原因未查」。

2026-11-02 查到的（中山幹線，2026-10 的七個平日：10-19 到 22、27 到 29，公告取自 10-28 的快照）：

| 公告時段 | 公告班距 | 換算每小時班數 | 量到每小時發車（去程／返程） | 路上的車 | 週期中位數 182 分鐘 ÷ 班距 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 06:30–08:00 | 4–6 分 | 10–15 | 5.5／2.5 | 10 | 30–46 |
| 08:00–16:00 | 10–15 分 | 4–6 | 4.3／5.1 | 14 | 12–18 |
| 16:00–17:30 | 4–6 分 | 10–15 | 7.4／4.1 | 17 | 30–46 |
| 17:30–20:00 | 10–15 分 | 4–6 | 4.4／5.5 | 16 | 12–18 |

離峰對得上，尖峰差了兩三倍。這不是趟次重建的誤差：2026-10-22 的 GPS 在 07 時只有 10 台車掛這條路線，中途站一小時經過 2 到 5 台；同一套重建用在定時班表的 251，一天 37 班，量到每個方向 37 趟。差距的原因公開資料看不出來，公告有沒有更新、實際核定多少班次，要有公運處的資料才能確認，但這個差距本身就是檢討班表的起點。

每天一份快照也是市府沒有的歷史：公告的班距、站序什麼時候改過，比對快照才看得出來。

為什麼現在：第一份公開的月卡是 2026 年 11 月，要在 12 月初印出來。

## What Changes

- 新的 `analysis/published_schedule.sql` 讀當天快照的兩支檔，只留本頁路線 Id 的列，匯出 `published_headways.csv`（時段與班距）與 `published_departures.csv`（定時班次的發車時刻）；新表 `route_day_published_headways`、`route_day_published_departures`，`route_days` 多 `published_schedule_day`。快照沒有這兩支檔時不擋那一天，跟 `GetProvider.gz` 一樣印一行說明。
- 新查詢物件 `RoutePage::ScheduleComparison`：給一組路線日，報每個公告時段的班距、換算的每小時班數、量到的每小時發車、路上的車、照公告要幾台，以及其餘時段的定時班次與量到的趟次、每小時的發車與路上的車。涵蓋日子裡公告改過就分開算。成員路線另外一列。
- 新查詢物件 `RoutePage::SnapshotChanges`：比對涵蓋日子相鄰兩天的公告、站序與路線軌跡更新時間，報哪一天改了什麼。
- 頁尾與健檢卡的顯名聲明第一行加這兩支 feed，`docs/data-sources.md` 補查證紀錄。
- `docs/spectra/LANGUAGE.md` 新增公告班距、路上的車、照公告要幾台，「日型別」補上 `DateValue` 的查證結果。
- 這個 change 不動任何頁面，第一個讀這些數字的是 `03-monthly-card`。

## Non-Goals

非目標寫在 design。

## Capabilities

### New Capabilities

- `published-schedule`：公告班距與定時班次怎麼從快照讀出來、每一天用哪一列、怎麼跟量到的發車與路上的車比較、涵蓋日子裡改了什麼。

### Modified Capabilities

- `derived-tables`：新增「Published schedule rows stored with the route day」。
- `site-layout`：「Attribution footer on every page」的 feed 對照多兩列。

## Impact

- 新增 `analysis/published_schedule.sql`、`app/models/route_day_published_headway.rb`、`app/models/route_day_published_departure.rb`、`app/models/route_page/schedule_comparison.rb`、`app/models/route_page/snapshot_changes.rb`、一個 migration、對應的 factory 與測試；fixture 多 `spec/fixtures/analysis/static/2026-10-19/` 與 `2026-10-23/` 的兩支檔。
- 修改 `analysis/derived_export.sql`、`analysis/README.md`、`app/models/route_day_loader.rb`、`app/models/route_day.rb`、`app/components/attribution_component.yml`、`bin/health-card`、`docs/data-sources.md`、`docs/spectra/LANGUAGE.md`、`spec/fixtures/analysis/README.md`。
- `bin/push-derived` 靠外鍵找衍生表，兩張新表會自動帶上。
- 正式站：deploy 之後舊的路線日沒有公告，要在 mini 跑一次 `bin/nightly-load --recompute --load`。跟 `01-rest-windows` 同一次 deploy 的話只要跑一次。
- 資料限制與假設：車不等於人，路上的車是車數，不是駕駛人數；10 秒輪詢會漏站，起站漏掉的趟次起點會晚一點，可能落到下一個時段；跨小時檔的重複已以 `(BusID, DataTime)` 去除；這段不用車上人數，刷卡率不影響。公開資料沒有排定的行駛時間、核定班次與配車數，所以比得出發車數，比不出「班表給了幾分鐘」，也判斷不了是否脫班。`GetSemiTimeTable.gz` 的 `DateValue` 是星期幾，API 說明文件 V6.3 的定義跟有班距資料的頁面路線對得上（2026-11-02 查的）；補假日是否跑假日班距還沒確認。
