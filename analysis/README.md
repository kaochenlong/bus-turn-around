# analysis

健檢卡的 DuckDB SQL。`bin/health-card` 把參數設成 DuckDB 變數，先接 `params.sql`，再依檔名順序接上編號的階段檔，整段交給 `duckdb` 子行程執行。只照檔名排的話 `params.sql` 會排在 `60_export.sql` 之後，前面的階段讀常數只會拿到 NULL。執行檔不載入 Rails，只用 Ruby 的預設 gem。

## 用法

```
bin/health-card --data <原始檔根目錄> --route 15373 --day 2026-10-19 --out docs/cards/15373-2026-10-19.md
```

資料根目錄也可以放在環境變數 `TURNAROUND_DATA`，這時省略 `--data`。根目錄只從參數或環境變數傳入，不寫進 repo 裡的任何檔案。跑出來的一天版卡放 `docs/cards/`。

| 參數 | 必要 | 省略時 |
| --- | --- | --- |
| `--data DIR` | 是，或設 `TURNAROUND_DATA` | 讀 `TURNAROUND_DATA` |
| `--route ID` | 是，路線 `Id` | |
| `--day YYYY-MM-DD` | 是，台北日 | |
| `--static-day YYYY-MM-DD` | 否 | 等於 `--day` |
| `--out PATH` | 否 | 卡寫到標準輸出 |
| `--inspect-dir DIR` | 否 | repo 根目錄下的 `tmp/health-card/<路線 Id>-<台北日>` |

`--data` 底下的目錄結構照 n-gear 的輸出：`bus_event/<台北日>/<HH>.jsonl` 或 `.jsonl.gz`、`bus_seat_event/` 同、`static/<台北日>/GetRoute.gz`、`GetStop.gz`、`GetPathDetail.gz`。

卡上只有路線層級的彙總，沒有車牌，也沒有檔案路徑。逐趟、逐折返、逐站的明細寫到 `--inspect-dir` 的五個 CSV：`trips.csv`、`layovers.csv`、`chains.csv`、`profile.csv`、`quality.csv`。只有這五個檔有車牌，留在本機檢查用。預設位置在 `.gitignore` 的 `/tmp/*` 底下，不進版本控制。同樣的輸入連跑兩次，卡只有產出時刻那一行不同，CSV 逐位元組相同。

## 結束碼

| 結束碼 | 情況 | 標準錯誤 |
| --- | --- | --- |
| 0 | 成功 | 沒有輸出 |
| 1 | 缺參數、日期不是 `YYYY-MM-DD` 或沒有那一天、路線 `Id` 不是正整數、不認得的參數 | 原因與用法 |
| 2 | PATH 裡沒有 `duckdb` | 安裝方式 |
| 3 | 那一天沒有任何 `bus_event` 小時檔，或靜態快照日的目錄不存在、缺三支靜態檔之一 | 缺的目錄或檔案，以及現有的快照日 |
| 4 | `duckdb` 回非零 | `duckdb` 自己的標準錯誤，一字不改 |

前三種在執行任何 SQL 之前就擋下。不會自動改用別天的快照。`bus_seat_event` 整個讀檔視窗都沒有檔時，由 DuckDB 報錯，以結束碼 4 透傳。

失敗時不寫任何輸出檔，因為 DuckDB 先把 CSV 寫到暫存目錄，整段成功之後才搬進 `--inspect-dir`，卡也在這之後才寫。

## 讀檔視窗

算台北日 D 時，`bus_event` 與 `bus_seat_event` 都讀 D-1 的 22、23 時、D 的全部小時、D+1 的 00、01 時的小時檔，日期與小時取自檔案路徑。視窗內沒有檔的小時直接略過，所以採集第一天沒有 D-1、最新一天還沒有 D+1 時都照常執行。

切完趟次之後只留起點落在 D 的趟次：前一晚發車、跨過午夜的趟次歸 D-1，D 晚上發車、D+1 凌晨到站的趟次歸 D。往前讀的時數由切趟的中斷門檻算出，往後讀的時數寫在 `params.sql`。

## 執行順序與各階段

依下表由上而下執行。每個階段建立 table 或 view，後面的階段只引用前面的名字。20 以後的階段建的都是 view，測試可以把前一個階段的 table 換成自己的資料，再讀後面的結果。

| 檔案 | 讀 | 建立 |
| --- | --- | --- |
| `params.sql` | | 定義用的常數，全部是變數，另外還有 `minutes_between` macro |
| `10_load.sql` | 變數 `data_root`、`route_id`、`day`、`static_day`、選用的 `member_route_ids`（一頁的路線 Id 清單，頁面路線在前；沒給就只有 `route_id`），以及原始檔 | `input_files`、`routes`、`bus_events`、`seat_events`、`other_route_events`、`load_counts`、`stops`、`path_stops`、`stop_events`、`unknown_stop_events`、`sequence_check` |
| `20_trips.sql` | `stop_events`、`stops`、`routes` | `trip_events`、`segmented_trips`、`trips`、`path_trip_counts` |
| `30_layovers.sql` | `trips`、`stops`、`other_route_events` | `layover_pairs`、`layovers`、`layover_exclusions`、`layover_distribution`、`rest_runs`、`rest_windows`、`chains`、`chain_report`、`chain_summary` |
| `40_load_profile.sql` | `seat_events`、`routes`、`stops`、`trips`、`trip_events` | `seat_stop_events`、`trip_seat_records`、`trip_stop_counts`、`net_boarding`、`count_coverage`、`trip_bands`、`load_profile`、`reset_counts`、`reset_check`、`count_anomalies` |
| `50_quality.sql` | `load_counts`、`unknown_stop_events`、`sequence_check`、`routes`、`stops`、`trips`、`trip_events`、`path_trip_counts` | `completeness_counts`、`path_trip_shares`、`vehicle_day_ends`、`last_stop_departures`、`missing_stop_rate`、`duty_status_counts`、`duty_status_trip_ends`、`quality` |
| `60_export.sql` | 前面各階段的名字、變數 `inspect_dir` | 檢查目錄的五個 CSV，最後印出一列 `card`，是卡上所有數字的 JSON，也是整段唯一會印東西的敘述 |

`layover_pairs` 把每台車相鄰兩趟配成一組。本趟有到末站（`complete` 或 `missing_start`）、下一趟從起站出發（`complete` 或 `missing_end`）、兩趟之間沒有去跑別的路線、差值不為負，才進 `layovers`。另一端漏站不影響，因為折返停留只用本趟的末站到站與下一趟的起站離站。不成立的配對在 `layover_exclusions` 分四類計數，一組只算在第一個符合的類別：`no_last_stop`（本趟沒有到末站）、`no_first_stop`（下一趟不是從起站出發）、`other_route`（兩趟之間跑了別的路線）、`negative`。量不到的配對只計數，因為前兩類的時間差是拿中途某一站代替端點量的，`other_route` 的時間差包含別條路線上的行駛，都不代表停留。

兩趟之間跑了別的路線，看的是 `other_route_events`。它是第 10 階段從同一批 `bus_event` 小時檔另外讀出來的，內容是這條路線的車、`RouteID` 不是 0 也不是這條路線附屬路線的記錄，照 `(BusID, DataTime)` 去重。這台車在本趟終點之後、下一趟起點之前（兩端都不含）的這些記錄，經過至少 `params.sql` 的 `other_route_min_stops` 個不同的站牌，`layover_pairs` 的 `ran_other_route` 就是 true。`RouteID` 0 是末站勤務結束這類非營運記錄，不算別條路線。不到門檻的是在末站切了路線碼，車沒有離開。

班次串的 `rest_runs` 只用相鄰完整趟次接成的序列，遇到不完整趟次、或兩趟之間跑了別的路線（同一組配對的 `ran_other_route`），就開始新的序列。

歸零檢查不用剖面的人數。`reset_counts` 對每個完整趟次取兩筆落在趟次起訖之外的記錄：起點前 `reset_record_minutes` 分鐘內、在起站的最後一筆到站記錄（上客前），以及終點後同樣分鐘內、在末站的第一筆離站記錄（下客後）。`reset_check` 每個方向（`go_back`）的每一端一列，帶那一端的站名 `stop_name`，給有記錄的趟數 `n_trips`、該方向完整趟次中沒有記錄的趟數 `n_missing`、等於 0 與不超過 `reset_near_zero` 的比例、最大值，比例只算有記錄的趟次。路線兩端的性質可能不同，所以不合併。

`vehicle_day_ends` 給每條附屬路線有幾趟是那台車當天在這條路線的第一趟（`n_first`）與最後一趟（`n_last`），寫進 `quality.csv` 的 metric 是 `first_trips` 與 `last_trips`，subject 是 `pathAttributeId`。

`last_stop_departures` 給每個方向的末站站名、完整趟次數 `complete_trips`，以及其中末站在終點後 `reset_record_minutes` 分鐘內有 `bus_event` 離站事件的趟數 `with_departure`。沒有離站事件的趟次，歸零檢查的「末站下客後」就量不到。寫進 `quality.csv` 的 metric 是 `complete_trips` 與 `last_stop_departures`，subject 是方向 0 或 1。

每個檔案開頭的註解列出它建立的每個名字。改定義只改 `params.sql`，其他檔案不寫那些常數的字面數字。

要在 `duckdb` 互動 shell 裡探索，先用 `SET VARIABLE` 設好 `data_root`、`route_id`、`day`、`static_day`、`inspect_dir` 五個變數，再依上表的順序 `.read` 各檔。

「先 `params.sql`、再依檔名排序的編號階段檔」這個組法寫在 `lib/analysis_run.rb`，`bin/health-card`、`bin/rails derived:load` 與 `bin/rails survey:end_natures` 共用。給 `stages: false` 時只接 `params.sql` 與呼叫端指定的檔，不接編號階段檔。

## 衍生表的匯出

`mrt_overlap.sql`、`turnaround_facilities.sql`、`route_shape.sql`、`depots.sql` 與 `derived_export.sql` 都不以數字開頭，`bin/health-card` 不會執行它們。`bin/rails derived:load ROUTE=15373 DAY=2026-10-19`（或 `FROM=… TO=…`，資料根目錄給環境變數 `TURNAROUND_DATA`）對每一天先跑 `params.sql`、全部編號階段檔，再依序接 `mrt_overlap.sql`、`turnaround_facilities.sql`、`route_shape.sql`、`depots.sql`、`derived_export.sql`，多了變數 `mrt_exits_path`、`mrt_exits_day`、`public_toilets_path`、`public_toilets_day`、`end_nature_0`、`end_nature_1`、`bus_shape_path`、`provider_path`、`derived_dir`，接著把寫出的 CSV 在一個交易裡替換進 PostgreSQL 的衍生表。一天要等讀檔視窗結束（隔天的 01 時檔出現）才能算，當天的 `bus_data/<D>/` 要至少有一個小時檔，資料根目錄的 `external/taipei-mrt-exits/` 要至少有一份捷運出入口快照，`external/public-toilets/` 要至少有一份公廁快照。

| 檔案 | 讀 | 建立或寫出 |
| --- | --- | --- |
| `mrt_overlap.sql` | `stops`（含經緯度），變數 `mrt_exits_path` | `mrt_exits`、`stop_mrt_distances`：每站最近的捷運出入口與直線距離（haversine，地球半徑 6,371,000 公尺，一位小數） |
| `turnaround_facilities.sql` | `stops`、`layovers`、讀檔視窗內的 `bus_data` 小時檔（用第 10 階段的 `day_files`、`window_start`、`window_end` 列出），變數 `public_toilets_path`、`end_nature_0`、`end_nature_1` | `public_toilets`、`gps_reports`（當天有折返停留的車的 GPS，照 `(BusID, DataTime)` 去重），以及 view `standstill_records`、`turnaround_ends`（每一端的位置、來源與三個查核數字）、`end_toilets`（位置 500 公尺內的每一間公廁）、`standstill_cells`（3 台車以上停過的靜止格） |
| `route_shape.sql` | 變數 `bus_shape_path`（那一天靜態快照的 `GetBusShape.gz`，快照沒有這個檔時是內容為 `[]` 的暫存檔）、`route_id` | `route_shape_rows`（這條路線 `SubRouteID` 為 -1 的列，各帶點與不能用的原因）、`route_shapes`（方向 0 與 1 各一列：留下那一列的更新時間與點，以及 `issue`） |
| `depots.sql` | `trip_events`、`trips`，變數 `provider_path`（那一天靜態快照的 `GetProvider.gz`，快照沒有這個檔時是 `BusInfo` 為空陣列的暫存檔） | `providers`（檔裡每個營業站一列：`stationId`、業者與營業站名稱），以及 view `trip_depots`（當天每趟的調度站）、`route_day_depots`（每個調度站一列：業者與營業站名稱、車數、趟次數） |
| `derived_export.sql` | `routes`、`stops`、`stop_mrt_distances`、`trips`、`trip_bands`、`layovers`、`trip_stop_counts`、`turnaround_ends`、`end_toilets`、`standstill_cells`、`route_shapes`、`route_day_depots`，變數 `route_id`、`day`、`static_day`、`mrt_exits_day`、`public_toilets_day` | 寫到 `derived_dir`：`route_day.csv`（含 `mrt_exits_day` 與 `public_toilets_day`）、`stops.csv`（含經緯度、最近出入口與距離）、`trips.csv`（含時段 `band`）、`layovers.csv`（本趟終點與下一趟起點，不寫分鐘數）、`trip_stop_counts.csv`（以 `bus_id` 加 `start_time` 指回趟次）、`ends.csv`（兩端各一列）、`end_toilets.csv`（以 `go_back` 指回那一端）、`end_cells.csv`（以 `go_back` 指回那一端）、`shapes.csv`（兩個方向各一列，點是緯度、經度的 JSON 陣列，沒有路線軌跡的方向點是空的、`issue` 寫原因）、`depots.csv`（每個調度站一列，車數多的在前、同車數照 `station_id`，名稱對不到是空字串） |

捷運出入口快照由 `bin/rails external:mrt_exits` 下載，北捷的檔是 Big5，存檔前轉成 UTF-8，表頭、資料列與經緯度不對就不寫檔。`derived:load` 用檔名日期最新的那一份，日期存進 `route_days.mrt_exits_day`。哪些站算「靠近捷運」不在這裡決定，300、500、800 公尺三種門檻是在路線頁的 `RoutePage::MrtOverlap` 套用的。

`turnaround_facilities.sql` 是唯一讀 `bus_data` 的檔，編號階段檔與健檢卡都不讀。靜止回報是一筆折返停留期間（本趟終點到下一趟起點，含兩端）同一台車速度為 0 的 GPS 回報，不看 `RouteID`；兩端的折返停留都收。停車那一端的位置是靜止點（同一座標的靜止回報）裡 `standstill_radius_meters` 鄰域筆數最多的那一點為種子，取種子鄰域內的靜止點以筆數加權的平均，存六位小數，之後的距離都從這個值量；直接折返那一端以末站計。查核數字是結束在這一端的折返停留筆數、其中至少一筆靜止回報落在位置 `located_radius_meters` 內的筆數，以及位置到末站的距離。公廁存位置 `toilet_radius_meters` 內的每一間，一間一列。靜止格是每筆靜止回報的經緯度各除以 `standstill_cell_degrees`、商四捨五入到小數六位後取整數再乘回去的西南角，一天裡少於 `cell_min_buses` 台車的格子不匯出。五個常數都在 `params.sql`：50 公尺、150 公尺、500 公尺、0.0002 度、3 台。兩端的性質由 `derived:load` 從 `config/route_page.yml` 讀出傳進來（`stop` 或 `pass_through`）；路線還沒寫進設定時兩個都是 `unknown`，三張結果都是空的；其他值會讓整段 SQL 失敗。

公廁快照由 `bin/rails external:public_toilets` 下載。環境部的全國公廁建檔資料沒有整份檔案，只有一頁最多 1,000 列的 API，所以照 `number` 由小到大翻頁，每一頁檢查表頭與每一列，整份收齊、`number` 嚴格遞增才一次寫成 `external/public-toilets/<台北日>.csv`，有一頁不對就不寫檔。`derived:load` 用檔名日期最新的那一份，日期存進 `route_days.public_toilets_day`。300 公尺的門檻與「同一地址的廁所併成一處」都在路線頁的 `RoutePage::Facilities` 套用，衍生表存的是 500 公尺內的每一間。

`route_shape.sql` 是唯一讀 `GetBusShape.gz`（公運處的公車路線軌跡）的檔，編號階段檔與健檢卡都不讀。它只留路線 `Id` 等於 `route_id`、`SubRouteID` 為 -1 的列；`wkt` 的每一點是經度在前、緯度在後，轉成 `[緯度, 經度]`、各取到小數 6 位，照原本順序存。能用的列要 `utime` 讀得出來（當成台北時間）、是 `LINESTRING`、至少 `route_shape_min_points` 點，每一點的緯度在 `route_shape_min_latitude` 到 `route_shape_max_latitude`、經度在 `route_shape_min_longitude` 到 `route_shape_max_longitude` 之間，五個常數在 `params.sql`：2 點、20 到 27、118 到 123。同一個方向有好幾列時，取能用的列裡 `utime` 最新的那一列。`issue` 是 `no_row`、`not_linestring`、`too_few_points`、`out_of_range`、`no_update_time`（這個方向沒有路線軌跡）或 `duplicate_rows`（有，但不只一列）；`derived:load` 只把有點的列寫進 `route_day_shapes`，對每一個有 `issue` 的方向印一行，快照沒有這個檔時只印缺檔那一行。

`depots.sql` 是唯一讀 `GetProvider.gz`（公運處的業者營運基本資料）的檔，編號階段檔與健檢卡都不讀；第 10 階段只多讀到離站事件的 `StationID`（車輛所屬的營業站），放進 `bus_events` 與 `stop_events`。每趟的調度站是這趟事件裡出現最多的 `StationID`，同票取小的，沒有 `StationID` 的事件不投票；每個調度站算當天趟次的不同車牌數與趟次數。名稱照 `stationId` 對到 `nameZn`（業者）與 `stationNameZn`（營業站），對不到是空字串；同一個 `stationId` 有兩列時整段 SQL 失敗。`derived:load` 把每一列寫進 `route_day_depots`；快照沒有這個檔時印一行、照樣寫入，名稱都是空字串。

時刻帶 `+08:00` 寫出。每個檔的欄位順序與列的排序都固定，同樣的輸入連跑兩次，位元組會完全相同。

## 全路網兩端性質的試跑

`end_nature_evidence.sql`、`end_nature_export.sql` 與 `end_nature_survey.sql` 都不以數字開頭，只由 `bin/rails survey:end_natures FROM=2026-10-19 TO=2026-10-22`（可以另外給 `ROUTES=<路線 Id,…>` 與 `OUT=<目錄>`，資料根目錄給環境變數 `TURNAROUND_DATA`）執行，`bin/health-card` 與 `derived:load` 都不跑它們。這個指令只寫 `OUT`（預設 `tmp/end-natures/`）底下的檔，不寫資料庫，也不改 `config/route_page.yml` 與路線頁。

每個路線日（那一天 `GetRoute.gz` 的每一條路線，或 `ROUTES` 給的；掛在別條路線 `member_routes` 底下的成員路線跟它的頁面路線一起跑）照 `derived:load` 的分析跑一次：`params.sql`、全部編號階段檔、`mrt_overlap.sql`、`turnaround_facilities.sql`，再接 `end_nature_evidence.sql` 與 `end_nature_export.sql`。變數是 `data_root`、`route_id`、`member_route_ids`、`day`、`static_day`、`inspect_dir` 與 `derived_dir`（跑完就丟的暫存目錄）、`mrt_exits_path`、`mrt_exits_day`、`public_toilets_path`、`public_toilets_day`、都給 `unknown` 的 `end_nature_0` 與 `end_nature_1`，以及 `survey_dir`。一天能不能算、用哪一份捷運出入口與公廁快照，規則跟 `derived:load` 相同（`RawDayCheck`、`NewestSnapshot`），而且每一天都在第一個路線日之前檢查。路線日都跑完，再用 `AnalysisRun` 的 `stages: false` 跑 `end_nature_survey.sql`，只接 `params.sql`，讀這次每個路線日的證據寫報告。

| 檔案 | 讀 | 建立或寫出 |
| --- | --- | --- |
| `end_nature_evidence.sql` | `stops`、`trips`、`layover_pairs`、`layovers`、`gps_reports`，變數 `route_id` | view `layover_evidence`（每一筆折返停留一列：結束在哪一端、下一趟的路線 Id 與方向、兩站距離、GPS 回報筆數、最長靜止、最遠離站）、`end_pair_counts`（頁面路線每個方向一列：末站，以及結束在那一端的配對照 `category` 分五類的筆數） |
| `end_nature_export.sql` | `routes`、`layover_evidence`、`end_pair_counts`，變數 `route_id`、`route_ids`、`day`、`survey_dir` | 寫到 `survey_dir`：`layovers.csv`（每筆折返停留與它的證據，依方向、本趟終點、車牌排序，時刻寫台北時間、不帶時差）、`ends.csv`（每個方向一列，這次的路線 Id 用「・」接） |
| `end_nature_survey.sql` | 變數 `layovers_files`、`ends_files`（這次每個路線日的兩個檔）、`configured_path`（指令寫的 `configured.csv`）、`report_path` | `survey_layovers`、`survey_ends`、`configured_ends`、view `inferred_ends`，寫出報告：一端一列，合併所有日子的證據、判斷與理由、設定的性質與是否相符 |

一筆折返停留的兩站，是本趟路線 Id 與方向的末站、下一趟路線 Id 與方向的起站；回報是那台車在本趟終點到下一趟起點之間（含兩端）的 `gps_reports`，不看 `RouteID`，沒有數字座標的不算。最遠離站是每筆回報離兩站裡較近那一站的距離取最大。最長靜止的量法：回報依時間排序，速度 0 的回報在前一筆也是速度 0、而且相距 `standstill_radius_meters` 內時接在同一段，否則開新的一段，一段從第一筆量到最後一筆，取最長的一段；回報之間的空檔不切斷一段。有回報但沒有速度 0 的是 0.0，沒有回報的兩個數都是空的。距離與最長靜止取一位小數，折返停留的分鐘數保留秒數。

判斷規則的四個常數都在 `params.sql`：最長靜止超過 `nature_still_minutes`（2 分鐘）的折返停留算停下來過。一端把調查的日子合起來算，有 GPS 回報的折返停留少於 `nature_min_layovers`（20 筆）是 `undetermined`、理由 `few_layovers`；停下來過的比例不超過 `nature_pass_through_max_share`（0.05）是 `pass_through`，至少 `nature_stop_min_share`（0.5）是 `stop`，介於兩者之間是 `undetermined`、理由 `between`。比例用筆數比較，剛好在門檻上的不會因為浮點數落到另一邊。規則不讀設定的性質，設定只拿來填報告的 `configured_nature` 與 `agrees`。

`OUT` 底下：

- `evidence/<台北日>/<路線 Id>/`：`layovers.csv`、`ends.csv` 與 `fingerprint`（這次分析的 SQL 全文加上路線 Id 清單的 SHA-256，一行 64 個十六進位字元）。DuckDB 先寫到同一層的暫存目錄，整個路線日成功才換成這個名字。再跑時指紋相同就沿用、不跑 DuckDB，不同就重跑並換掉；跑失敗的路線日不留目錄。
- `configured.csv`：設定裡每條路線每個方向一列，`route_id`、`go_back`、`nature`。
- `report-<FROM>_<TO>.csv`：每次都從這次所有日子的證據重算，先寫暫存檔，成功才改成這個名字。

## 測試

```
bundle exec rspec spec/analysis
```

測試讀 `spec/fixtures/analysis/` 的合成原始檔，案例清單與照 spec 手算的預期結果在 `spec/fixtures/analysis/README.md`。`duckdb` 不在 PATH 時整組略過，略過訊息寫著安裝方式。

## DuckDB 版本需求

需要 DuckDB CLI 1.1 以上，`SET VARIABLE` 與 `getvariable()` 從 1.1 開始提供。安裝：

```
brew install duckdb
```

寫這份說明時用的版本，`duckdb --version` 的輸出：

```
v1.5.6 (Variegata) 069cc9f9b5
```

## 在這個版本上確認過的行為

2026-10-20 用真資料的一個小時檔與一份靜態快照確認。SQL 與執行檔照下面的結果寫：

- 參數用變數傳。`read_json(getvariable('p'), ...)` 可以直接把變數當路徑，所以採用變數方案，不用 design 寫的字串模板退路。
- 檔案清單也用變數傳。`SET VARIABLE files = (SELECT list(file) FROM glob(...))` 再交給 `read_json`。同一份清單混著 `.jsonl` 與 `.jsonl.gz` 時兩種都讀得到，壓縮格式依副檔名逐檔判斷。
- glob 沒有命中任何檔案時，`list()` 得到 NULL，`read_json` 回 `read_json cannot take NULL list as parameter`。空清單則回 `read_json needs at least one file to read`。所以執行檔在執行前先確認當天有 `bus_event` 的小時檔。`bus_seat_event` 整個視窗都沒有檔時，就是這個錯誤以結束碼 4 透傳。
- 靜態快照是單一 JSON 物件，外層是 `EssentialInfo` 與 `BusInfo`，資料列在 `BusInfo` 陣列裡，要先 `read_json` 整個檔再 `unnest(BusInfo)`。2026-10-19 的 `GetStop.gz` 解壓後約 9.4 MB，低於 `read_json` 預設的單一物件上限 16 MB。上限仍要明確設大，不靠預設值。
- `COPY ... TO` 的目標可以是用 `getvariable()` 組出來的運算式，檢查目錄因此也用變數傳。
- `-json` 模式下，`SET`、`CREATE`、`COPY` 不印任何東西，只有查詢會印出一個 JSON 陣列。JSON 與 STRUCT 欄位以巢狀物件輸出，不是字串。
- SQL 出錯時，沒加 `-bail` 會繼續執行後面的敘述，最後結束碼是 1。加了 `-bail` 會停在第一個錯誤。執行檔用 `duckdb -no-init -bail -batch -json`，`-no-init` 讓使用者自己的 `~/.duckdbrc` 不影響輸出。
