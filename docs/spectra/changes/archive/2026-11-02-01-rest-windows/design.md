## Context

`analysis/30_layovers.sql` 已經有第 19 條之 2 的四小時視窗：`rest_runs` 把一台車相鄰的完整趟次接成序列，遇到不完整趟次或兩趟之間跑了別的路線就切斷（`layover-other-routes` 的決定「班次串遇到兩趟之間跑了別的路線也切斷」）；`rest_windows` 算每個視窗的休息額度；`chains` 把被標的視窗併成班次串（`zhongshan-first-health-card` 的決定「班次串用第 19 條之 2 的四小時視窗算，重疊的視窗併成一串」）。這些 view 只有 `bin/health-card` 讀，衍生表裡沒有，所以網站與跨日子的彙總都讀不到。

2026-11-02 量到的（`analysis/30_layovers.sql` 的 `rest_runs` 加上下面決定裡的 view，跑原始檔，2026-10 的七個平日：10-19 到 22、27 到 29）：

| 路線 | 完整趟次 | 車至少一條班次串 | 能判斷的四小時視窗 | 其中累計不到三十分鐘 | 六小時視窗 | 其中沒有一次停滿四十五分鐘 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 中山幹線 | 77% | 36% | 281 | 50.5% | 149 | 31.5% |
| 251區 | 98% | 64% | 386 | 37.6% | 278 | 33.5% |
| 復興幹線 | 79% | 39% | 329 | 34.3% | 188 | 35.6% |
| 307 | 91% | 69% | 1,971 | 34.3% | 1,687 | 25.7% |
| 251 | 98% | 71% | 352 | 25.6% | 293 | 4.4% |
| 235 | 81% | 31% | 758 | 21.4% | 594 | 28.1% |
| 22 | 93% | 47% | 648 | 17.6% | 486 | 21.6% |

同一批資料，串數把 251 排在中山幹線前面，比例則相反。251 停車端的折返停留不到 15 分鐘只有 4%，中山幹線 43%，比例的排序才合理。

法條（全國法規資料庫，汽車運輸業管理規則第 19 條之 2，2026-11-02 查的）：每日駕車不得超過 10 小時；連續駕車 4 小時至少休息 30 分鐘，分次休息每次不少於 15 分鐘；工作具連續性或遇交通壅塞可以另行調配，但連續駕車不得超過 6 小時，且要一次休滿 45 分鐘。

寫月卡試印時曾經在 Rails 裡用 `trips` 與 `layovers` 重算一次視窗，七天的串數合計相同（88 串），但有兩天各差 1 串（10-19 的 12 與 13、10-20 的 13 與 12）。這就是在 Rails 再算一次會出現的第二套定義。

列數（量到的，同七個平日）：一個路線日 4 小時加 6 小時的視窗，中山幹線約 61 列、307 約 523 列；連續行駛段中山幹線約 66 列、307 約 301 列。比 `trip_stop_counts` 一個路線日約 12k 列少得多。

## Goals / Non-Goals

**Goals:**

- 一組路線日（一天、七天或一個月）能讀到連續 4／6 小時能判斷的視窗數、符合條件的視窗數與比例、逐日範圍，以及連續行駛段的分佈。
- 定義只有一份：DuckDB 算、衍生表存、PostgreSQL 只彙總。
- 涵蓋日子裡取「最新一天」的四個查詢物件，接在已排序的 relation 後面也取到最新一天。

**Non-Goals:**

- 任何頁面與月卡：第一個讀這些數字的是 `03-monthly-card`。
- 把量到的視窗或班次串放上路線頁：`zhongshan-route-page` 的非目標「班次串、歸零檢查、資料品質數字搬上頁面」照舊，它們留在健檢卡。
- 合規標示與顏色：`timetable-draft` 的非目標「把四小時休息的數字標成合規或不合規、用顏色標好壞」照舊，資料看得到車、看不到人。
- 改四小時視窗或班次串的定義、改健檢卡除了「不合規」那句以外的內容。
- 每日駕車 10 小時與兩工作日間隔的完整對照：要有駕駛的班表才算得出來。這裡的 10 小時只是一個標記，用來說明哪些車一定換過人。
- 跨路線累計行駛：兩趟之間跑了別的路線就切斷，別條路線上有沒有休息看不到。

## Decisions

### 視窗與連續行駛段照舊在 DuckDB 算，匯出進衍生表，Rails 不再算一次

`rest_windows`、`long_rest_windows`、`driving_stretches` 都是 `analysis/30_layovers.sql` 的 view，`analysis/derived_export.sql` 把每一列寫成 CSV，`RouteDayLoader` 存進 PostgreSQL。`RoutePage::RestWindows` 只做彙總。

理由：序列要知道兩趟之間有沒有跑別的路線、差值是不是負的，這些配對只有 DuckDB 那邊有；衍生表的 `layovers` 只存成立的折返停留。試印用 Rails 重算就差了兩天各 1 串。

替代方案：從 `trips` 與 `layovers` 在 PostgreSQL 重算（`RoutePage::Cycles` 的做法）。否決：來回一趟與週期健檢卡沒有，所以沒有兩套定義的問題；視窗健檢卡有，會出現第二套。

### 連續 6 小時視窗：一次停滿 45 分鐘才算數，常數放 params.sql

`analysis/params.sql` 加 `long_rest_window_minutes = 360` 與 `long_rest_min_minutes = 45`。新 view `long_rest_windows` 用同一批 `rest_runs`：每一趟 i 找同一序列裡最早的 j，使第 j 趟到站減第 i 趟發車達 360 分鐘；第 i 到第 j−1 趟之後的折返停留裡，沒有一次達 45 分鐘就標出來。6 小時視窗不併成串，也不進 `chains`。

`rest_windows` 多一欄 `longest_layover_minutes`，算法同 6 小時；既有欄位不變，健檢卡讀的 `chains`、`chain_report` 不受影響。

理由：法條的例外是連續不得超過 6 小時且一次休滿 45 分鐘。只報 4 小時，業者一句「交通壅塞、屬於例外」就帶過了；兩條一起報，例外也對照到了。

### 兩條規則存同一張表 route_day_rest_windows，一個視窗一列

欄位：`route_day_id`、`bus_id`、`rule`（`four_hours` 或 `six_hours`）、`start_time`、`end_time`、`n_trips`、`credit_minutes`、`longest_layover_minutes`、`flagged`、`over_daily_driving`。唯一鍵是 `route_day_id`、`rule`、`bus_id`、`start_time`。外鍵到 `route_days`，刪路線日時一起刪。

理由：衍生表存逐列、不存彙總（`LANGUAGE.md` 的「衍生表」），逐日範圍與任意一組日子都在讀取時算。一張表兩條規則，讀的 SQL 只要一個 `GROUP BY rule`。`bus_id` 留著是為了唯一鍵與之後按車分析，跟 `trips` 一樣畫面上不顯示。

替代方案：每個路線日存一列彙總。否決：比例與百分位數不能再合併，而且違反衍生表的做法。

### 連續行駛段：中間沒有 15 分鐘以上停留的完整趟次接成一段

新 view `driving_stretches`：在 `rest_runs` 的序列裡，序列的第一趟開新的一段，前一次折返停留達 `rest_min_minutes`（15）的那一趟也開新的一段。一段記第一趟發車、最後一趟到站與趟數。新表 `route_day_driving_stretches`：`route_day_id`、`bus_id`、`start_time`、`end_time`、`n_trips`，唯一鍵 `route_day_id`、`bus_id`、`start_time`。

理由：比例回答「多常不夠」，連續行駛段回答「車連續跑多久才停超過 15 分鐘」，讀的人比較有感覺，也不受視窗起點影響。

### 當天行駛超過 10 小時只存成一個標記，門檻只放 params.sql

`analysis/params.sql` 加 `daily_driving_limit_minutes = 600`。`rest_windows.csv` 的 `over_daily_driving`：這台車當天所有趟次（不分完整性，本頁的所有路線 Id）行駛時間加總超過 600 分鐘。剛好 600 不算。

理由：第 19 條之 2 每日駕車上限 10 小時，所以行駛超過 10 小時的車，若守這條規定就一定換過人。量到的比例差很多：七個平日裡，連續 4 小時視窗落在這種車上的，307 是 93%（1,840／1,971），中山幹線 16%（44／281）。把它印出來，讀的人才知道比例能推到人多遠。只算這條路線的趟次，是下限。門檻放 SQL，Ruby 只讀標記，不會有第二份常數。

### route_days.rest_windows_loaded 分得出沒重算的日子

`route_days` 多 boolean 欄 `rest_windows_loaded`，預設 false、不可空；`RouteDayLoader` 寫入路線日時設成 true。`RoutePage::RestWindows#needs_reload?` 在涵蓋日子有任何一天是 false 時為 true。

理由：一條短程路線一天可能真的一個視窗都沒有，看列數分不出「沒有視窗」與「還沒重算」。沿用 `stop_districts_day` 的思路（還沒用新資料載入的路線日看得出來），但這裡沒有快照日可以記，所以用 boolean。

### RoutePage::RestWindows 只給數字，比例的分母是能判斷的視窗

`RoutePage::RestWindows.new(route_days)` 不要求 relation 有沒有排序。公開方法：

- `rule(:four_hours)`、`rule(:six_hours)` 回傳 `Data`：`n_windows`、`n_flagged`、`flagged_share`（沒有視窗時是 nil）、`day_low`、`day_high`（有視窗的日子裡每日比例的最小與最大，沒有時 nil）、`n_over_daily`、`n_flagged_over_daily`。
- `stretches` 回傳 `Data`：`n_stretches`、`p50`、`p90`（`percentile_cont`，分鐘，一位小數，沒有時 nil）、`longest`、`n_over_four_hours`（超過 240 分鐘）、`n_over_six_hours`（超過 360 分鐘）。
- `needs_reload?`。

不回傳車牌，也沒有任何合規或好壞的欄位。

### 取「最新一天」一律用 reorder，測試傳排序過的 relation

`RoutePage::LayoverStats`、`LayoverDistribution`、`LoadProfile`、`MrtOverlap` 把 `order(day: :desc)` 改成 `reorder(day: :desc)`，跟 `Cycles`、`Depots`、`StopSequence` 同一種寫法。`RoutePage::Coverage#route_days` 帶著 `order(:day)`，再接 `order` 只是附加第二個排序，所以取到最早那天。四個物件的測試都加一個例子，傳 `RouteDay.order(:day)`，斷言站名或出入口快照日來自最新一天。

理由：路線頁的最近 7 天現在就取到最早那天的站名與出入口快照日；`03-monthly-card` 傳一整個月時差距會更明顯。修呼叫端比改 `Coverage` 好：`Coverage` 的排序有別的地方在用。

### 班次串的文字拿掉「不合規」

`bin/health-card` 班次串的說明、`docs/spectra/LANGUAGE.md`「班次串」的定義，都把「就標為不合規」「就是一條不合規的串」改成描述條件（「就標出來」「就算一條班次串」）。`docs/cards/` 已經產生的卡不動（`01-pass-through-wording` 的非目標：那些是當時的紀錄）。

理由：資料看得到車、看不到人，「不合規」這個結論下不了；`timetable-draft` 的非目標也已經不做合規標示。

### 詞彙表新增連續 4／6 小時視窗與連續行駛段，班次串不改名

`docs/spectra/LANGUAGE.md`「指標」底下新增「連續 4 小時視窗與連續 6 小時視窗」「連續行駛段」，定義、資料裡的名字、邊界、不要用的說法照這份檔案的四行格式。邊界要寫：這是車的數字；不完整趟次與別的路線會切斷，所以分母是能判斷的視窗；比例不能換算成違規件數；當天行駛超過 10 小時是下限。

班次串改不改名成趟次串仍然留給之後，這裡不動。

### 用真資料驗收：中山幹線 2026-10-22 的視窗數與試算相同

本機用原始檔鏡射把 15373 的 2026-10-22 載入開發庫，`RoutePage::RestWindows` 要讀到：4 小時 32 個視窗、19 個符合條件；6 小時 15 個視窗、5 個符合條件；連續行駛段 66 段。這些數字是 2026-11-02 在 DuckDB 上試算這幾個 view 量到的。

2026-11-02 驗收結果：`bin/rails derived:load ROUTE=15373 DAY=2026-10-22` 寫進開發庫之後，`RoutePage::RestWindows` 讀到 4 小時 32 個視窗、19 個標出（逐日比例 59.4%）；6 小時 15 個視窗、5 個標出；連續行駛段 66 段，p50 139.6 分鐘、p90 270.7 分鐘、最長 429.6 分鐘，超過 4 小時 10 段、超過 6 小時 1 段。跟試算相同。4 小時的視窗有 6 個落在當天行駛超過 10 小時的車上，其中 5 個標出，所以 `over_daily_driving` 為 true 的路徑在真資料上也走過。`rest_windows_loaded` 是 true。

## Implementation Contract

**行為**：`derived:load` 與 `bin/nightly-load` 寫入路線日時，多存兩個 CSV 的列，`rest_windows_loaded` 設成 true。任何頁面都不多顯示東西。路線頁的最近 7 天，站名、捷運重疊的快照日取涵蓋日子裡最新的一天。`bin/health-card` 的輸出只有班次串說明那一句不同，CSV 檔不變。

**資料形狀**：

- `rest_windows.csv`：`bus_id, rule, start_time, end_time, n_trips, credit_minutes, longest_layover_minutes, flagged, over_daily_driving`，照 `rule`、`bus_id`、`start_time` 排序。分鐘數一位小數。
- `driving_stretches.csv`：`bus_id, start_time, end_time, n_trips`，照 `bus_id`、`start_time` 排序。
- 時間帶 `+08:00`，兩次匯出位元組相同，跟其他檔一樣。

**失敗模式**：匯出或寫入任何一步失敗，那一天維持原樣（既有的「Replace one route day atomically」）。沒有新的必要快照，所以 `Day eligibility` 不變。

**驗收**：fixture 2026-10-19 路線 9001：4 小時 9 個視窗、2 個標出（TEST-0001 的 06:00 與 07:00）；6 小時 7 個視窗、0 個標出，第一個是 06:00 到 13:14、6 趟、最長一次 56.0 分鐘；連續行駛段 15 段，最長是 06:00 到 11:30、5 趟；每台車當天行駛最多 483.0 分鐘，所以 `over_daily_driving` 全是 false。班次串照舊只有 06:00 到 11:30 那一條。

**範圍**：只動分析、衍生表、查詢物件、四個物件的排序與文字。頁面、PDF、排程都不在這裡。

## Risks / Trade-offs

- [視窗不等於法條的「連續駕車」：視窗從某一趟發車算起，折返停留短於 15 分鐘也算在視窗裡，雙班制下換手之後是另一個人] → 文件與頁面都寫「符合條件的視窗」，不寫違規；`over_daily_driving` 讓讀的人看得出多少比例一定換過人。
- [完整趟次少的路線，能判斷的視窗也少，比例的樣本比較小] → 視窗數跟比例一起報，分母看得到。
- [舊的路線日沒有視窗] → `rest_windows_loaded` 讓讀的一方看得出來；deploy 後跑一次 `--recompute`。
- [`bus_id` 多存一張表] → 跟 `trips`、`layovers` 同一種資料，畫面上不顯示；`RestWindows` 不回傳車牌，測試斷言回傳的值裡沒有 `TEST-`。

## Migration Plan

1. 合併後 deploy（有 migration）。mini 的 checkout 要跟上 origin/main，否則「Migration versions agree before loading」會讓每晚載入停下來，這是既有的保護。
2. 在 mini 跑 `bin/nightly-load --recompute --load`，所有路線日才有視窗。由使用者用 `!` 跑。
3. 退回：migration 只加表與一欄，rollback 刪掉即可，其他資料不受影響。

## Open Questions

沒有。
