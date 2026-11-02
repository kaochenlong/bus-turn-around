## Why

這個 change 服務三樣交付物的第一樣路線健檢卡：每條路線每月一份的月卡要報連續行駛。需要的資料是 `bus_event` 重建的趟次與折返停留，`analysis/30_layovers.sql` 已經算得出第 19 條之 2 的四小時視窗，但只有一天版的健檢卡讀得到，衍生表裡沒有，所以跨日子、跨月彙總不了。

班次串的串數也不能直接拿來比。2026-10 的七個平日（10-19 到 22、27 到 29，跑原始檔量到的）：

| 路線 | 停車端不到 15 分鐘 | 車當天至少一條班次串 | 能判斷的 4 小時視窗裡停留累計不到 30 分鐘 | 完整趟次 |
| --- | ---: | ---: | ---: | ---: |
| 中山幹線 | 43% | 36% | 50% | 77% |
| 251 | 4% | 71% | 26% | 98% |

串數的排序跟停車端的數字相反：不完整的趟次會切斷序列，完整趟次少的路線湊不滿四小時，能判斷的視窗變少，串也跟著少。分母改成能判斷的視窗，排序才對得上。第 19 條之 2 還有例外：工作具連續性或交通壅塞時可以另行調配，但連續駕車不得超過 6 小時，且要一次休滿 45 分鐘（全國法規資料庫，汽車運輸業管理規則）。只報 4 小時，一句「屬於例外」就帶過了，所以 6 小時要一起算。

為什麼現在：第一份公開的月卡是 2026 年 11 月，要在 12 月初印出來；連續 4／6 小時要先進衍生表，舊的日子重算一次才有。

## What Changes

- `analysis/params.sql` 加 6 小時規則與每日駕車 10 小時的常數；`analysis/30_layovers.sql` 新增 `long_rest_windows`（連續 6 小時的視窗）與 `driving_stretches`（一台車中間沒有 15 分鐘以上停留的連續行駛段），`rest_windows` 多一欄視窗裡最長的一次停留。健檢卡的輸出不變，只有第 5 點改的那一句。
- 衍生匯出多兩個檔：`rest_windows.csv`（4 小時與 6 小時兩條規則的每一個視窗）與 `driving_stretches.csv`；新表 `route_day_rest_windows`、`route_day_driving_stretches`，`route_days` 多 `rest_windows_loaded`，分得出「這天沒有視窗」與「這天還沒重算」。
- 新查詢物件 `RoutePage::RestWindows`：給任意一組路線日，報每條規則能判斷的視窗數、符合條件的視窗數與比例、逐日範圍、落在當天行駛超過 10 小時的車上的視窗數，以及連續行駛段的分佈。只給數字，不帶車牌，不判定合不合規。這個 change 不動任何頁面，第一個讀它的是 `03-monthly-card`。
- 修 `RoutePage::LayoverStats`、`LayoverDistribution`、`LoadProfile`、`MrtOverlap` 取「涵蓋日子裡最新一天」的寫法：接在已排序的 relation 後面會取到最早那天。路線頁的最近 7 天現在就受影響，月卡跨一整個月會更明顯。
- 班次串的文字拿掉「不合規」：`bin/health-card` 的說明與詞彙表都改成描述條件。資料看得到車、看不到人，這個字下不了結論，`timetable-draft` 的非目標也已經不做合規標示。
- `docs/spectra/LANGUAGE.md` 新增連續 4／6 小時視窗與連續行駛段；`analysis/README.md` 補新的 view 與檔案。

## Non-Goals

非目標寫在 design。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `layover-metrics`：新增「Six-hour rest windows」「Continuous driving stretches」「Rest window figures over route days」；「Rest-rule windows and chains」不變。
- `derived-tables`：新增「Rest window rows stored with the route day」。

## Impact

- 新增 `app/models/route_day_rest_window.rb`、`app/models/route_day_driving_stretch.rb`、`app/models/route_page/rest_windows.rb`、一個 migration、對應的 factory 與測試。
- 修改 `analysis/params.sql`、`analysis/30_layovers.sql`、`analysis/derived_export.sql`、`analysis/README.md`、`app/models/route_day_loader.rb`、`app/models/route_day.rb`、`app/models/route_page/layover_stats.rb`、`layover_distribution.rb`、`load_profile.rb`、`mrt_overlap.rb`、`bin/health-card`、`docs/spectra/LANGUAGE.md`。
- `bin/push-derived` 靠外鍵找衍生表，兩張新表參照 `route_days` 就會帶上，不用改。
- 正式站：deploy 之後舊的路線日沒有視窗，要在 mini 跑一次 `bin/nightly-load --recompute --load`，所有路線日才有。七條路線 80 個路線日約 12 分鐘（估的，照 2026-10-26 量到每個路線日 8.5 秒算；用下一次 recompute 的 log 確認）。
- 資料限制與假設：車不等於人，雙班制下一台車兩個人開，這些視窗是車的數字，不是駕駛的工時；折返停留是駕駛休息的上限；10 秒輪詢會漏站，不完整的趟次會切斷序列，所以分母只算能判斷的視窗；跨小時檔的重複已以 `(BusID, DataTime)` 去除；兩趟之間跑了別的路線也切斷，別條路線上有沒有休息看不到。這些數字不用車上人數，刷卡率不影響。「當天行駛超過 10 小時」只算這條路線的趟次，是下限：若守每日駕車 10 小時的規定，這種車一定換過人；沒超過的車可能一人開完，也可能兩人開。
