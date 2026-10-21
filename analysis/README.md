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

卡上只有路線層級的彙總，沒有車牌，也沒有檔案路徑。逐趟、逐折返、逐站的明細寫到 `--inspect-dir` 的五個 CSV：`trips.csv`、`layovers.csv`、`chains.csv`、`profile.csv`、`quality.csv`。只有這五個檔有車牌，留在本機檢查用；預設位置在 `.gitignore` 的 `/tmp/*` 底下，不進版本控制。同樣的輸入連跑兩次，卡只有產出時刻那一行不同，CSV 逐位元組相同。

## 結束碼

| 結束碼 | 情況 | 標準錯誤 |
| --- | --- | --- |
| 0 | 成功 | 沒有輸出 |
| 1 | 缺參數、日期不是 `YYYY-MM-DD` 或沒有那一天、路線 `Id` 不是正整數、不認得的參數 | 原因與用法 |
| 2 | PATH 裡沒有 `duckdb` | 安裝方式 |
| 3 | 那一天沒有任何 `bus_event` 小時檔，或靜態快照日的目錄不存在、缺三支靜態檔之一 | 缺的目錄或檔案，以及現有的快照日 |
| 4 | `duckdb` 回非零 | `duckdb` 自己的標準錯誤，一字不改 |

前三種在執行任何 SQL 之前就擋下。不會自動改用別天的快照。`bus_seat_event` 整個讀檔視窗都沒有檔時，由 DuckDB 報錯，以結束碼 4 透傳。

失敗時不寫任何輸出檔：DuckDB 先把 CSV 寫到暫存目錄，整段成功之後才搬進 `--inspect-dir`，卡也在這之後才寫。

## 讀檔視窗

算台北日 D 時，`bus_event` 與 `bus_seat_event` 都讀 D-1 的 22、23 時、D 的全部小時、D+1 的 00、01 時的小時檔，日期與小時取自檔案路徑。視窗內沒有檔的小時直接略過，所以採集第一天沒有 D-1、最新一天還沒有 D+1 時都照常執行。

切完趟次之後只留起點落在 D 的趟次：前一晚發車、跨過午夜的趟次歸 D-1，D 晚上發車、D+1 凌晨到站的趟次歸 D。往前讀的時數由切趟的中斷門檻算出，往後讀的時數寫在 `params.sql`。

## 執行順序與各階段

依下表由上而下執行。每個階段建立 table 或 view，後面的階段只引用前面的名字。20 以後的階段建的都是 view，測試可以把前一個階段的 table 換成自己的資料，再讀後面的結果。

| 檔案 | 讀 | 建立 |
| --- | --- | --- |
| `params.sql` | | 定義用的常數，全部是變數；`minutes_between` macro |
| `10_load.sql` | 變數 `data_root`、`route_id`、`day`、`static_day`；原始檔 | `input_files`、`routes`、`bus_events`、`seat_events`、`load_counts`、`stops`、`path_stops`、`stop_events`、`unknown_stop_events`、`sequence_check` |
| `20_trips.sql` | `stop_events`、`stops`、`routes` | `trip_events`、`segmented_trips`、`trips`、`path_trip_counts` |
| `30_layovers.sql` | `trips`、`stops` | `layover_pairs`、`layovers`、`layover_exclusions`、`layover_distribution`、`rest_runs`、`rest_windows`、`chains`、`chain_report`、`chain_summary` |
| `40_load_profile.sql` | `seat_events`、`routes`、`stops`、`trips`、`trip_events` | `seat_stop_events`、`trip_seat_records`、`trip_stop_counts`、`net_boarding`、`count_coverage`、`trip_bands`、`load_profile`、`reset_counts`、`reset_check`、`count_anomalies` |
| `50_quality.sql` | `load_counts`、`unknown_stop_events`、`sequence_check`、`routes`、`stops`、`trips`、`trip_events`、`path_trip_counts` | `completeness_counts`、`path_trip_shares`、`vehicle_day_ends`、`last_stop_departures`、`missing_stop_rate`、`duty_status_counts`、`duty_status_trip_ends`、`quality` |
| `60_export.sql` | 前面各階段的名字、變數 `inspect_dir` | 檢查目錄的五個 CSV；最後印出一列 `card`，是卡上所有數字的 JSON，也是整段唯一會印東西的敘述 |

歸零檢查不用剖面的人數。`reset_counts` 對每個完整趟次取兩筆落在趟次起訖之外的記錄：起點前 `reset_record_minutes` 分鐘內、在起站的最後一筆到站記錄（上客前），以及終點後同樣分鐘內、在末站的第一筆離站記錄（下客後）。`reset_check` 每個方向（`go_back`）的每一端一列，帶那一端的站名 `stop_name`，給有記錄的趟數 `n_trips`、該方向完整趟次中沒有記錄的趟數 `n_missing`、等於 0 與不超過 `reset_near_zero` 的比例、最大值，比例只算有記錄的趟次。路線兩端的性質可能不同，所以不合併。

`vehicle_day_ends` 給每條附屬路線有幾趟是那台車當天在這條路線的第一趟（`n_first`）與最後一趟（`n_last`），寫進 `quality.csv` 的 metric 是 `first_trips` 與 `last_trips`，subject 是 `pathAttributeId`。

`last_stop_departures` 給每個方向的末站站名、完整趟次數 `complete_trips`，以及其中末站在終點後 `reset_record_minutes` 分鐘內有 `bus_event` 離站事件的趟數 `with_departure`；沒有離站事件的趟次，歸零檢查的末站下客後量不到。寫進 `quality.csv` 的 metric 是 `complete_trips` 與 `last_stop_departures`，subject 是方向 0 或 1。

每個檔案開頭的註解列出它建立的每個名字。改定義只改 `params.sql`，其他檔案不寫那些常數的字面數字。

要在 `duckdb` 互動 shell 裡探索，先用 `SET VARIABLE` 設好 `data_root`、`route_id`、`day`、`static_day`、`inspect_dir` 五個變數，再依上表的順序 `.read` 各檔。

「先 `params.sql`、再依檔名排序的編號階段檔」這個組法寫在 `lib/analysis_run.rb`，`bin/health-card` 與 `bin/rails derived:load` 共用。

## 衍生表的匯出

`mrt_overlap.sql` 與 `derived_export.sql` 都不以數字開頭，`bin/health-card` 不會執行它們。`bin/rails derived:load ROUTE=15373 DAY=2026-10-19`（或 `FROM=… TO=…`，資料根目錄給環境變數 `TURNAROUND_DATA`）對每一天先跑 `params.sql`、全部編號階段檔，再接 `mrt_overlap.sql`、最後 `derived_export.sql`，多三個變數 `mrt_exits_path`、`mrt_exits_day`、`derived_dir`；再把寫出的 CSV 在一個交易裡替換進 PostgreSQL 的衍生表。一天要等讀檔視窗結束（隔天的 01 時檔出現）才能算，資料根目錄的 `external/taipei-mrt-exits/` 也要至少有一份捷運出入口快照。

| 檔案 | 讀 | 建立或寫出 |
| --- | --- | --- |
| `mrt_overlap.sql` | `stops`（含經緯度），變數 `mrt_exits_path` | `mrt_exits`、`stop_mrt_distances`：每站最近的捷運出入口與直線距離（haversine，地球半徑 6,371,000 公尺，一位小數） |
| `derived_export.sql` | `routes`、`stops`、`stop_mrt_distances`、`trips`、`trip_bands`、`layovers`、`trip_stop_counts`，變數 `route_id`、`day`、`static_day`、`mrt_exits_day` | 寫到 `derived_dir`：`route_day.csv`（含 `mrt_exits_day`）、`stops.csv`（含經緯度、最近出入口與距離）、`trips.csv`（含時段 `band`）、`layovers.csv`（本趟終點與下一趟起點，不寫分鐘數）、`trip_stop_counts.csv`（以 `bus_id` 加 `start_time` 指回趟次） |

捷運出入口快照由 `bin/rails external:mrt_exits` 下載：北捷的檔是 Big5，存檔前轉成 UTF-8，表頭、資料列與經緯度不對就不寫檔。`derived:load` 用檔名日期最新的那一份，日期存進 `route_days.mrt_exits_day`。哪些站算「靠近捷運」不在這裡決定：300、500、800 公尺三種門檻在路線頁的 `RoutePage::MrtOverlap` 套用。

時刻帶 `+08:00` 寫出；每個檔的欄位順序與列的排序固定，同樣的輸入連跑兩次位元組相同。

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
- glob 沒有命中任何檔案時，`list()` 得到 NULL，`read_json` 回 `read_json cannot take NULL list as parameter`。空清單則回 `read_json needs at least one file to read`。所以執行檔在執行前先確認當天有 `bus_event` 的小時檔；`bus_seat_event` 整個視窗都沒有檔時，就是這個錯誤以結束碼 4 透傳。
- 靜態快照是單一 JSON 物件，外層是 `EssentialInfo` 與 `BusInfo`，資料列在 `BusInfo` 陣列裡，要先 `read_json` 整個檔再 `unnest(BusInfo)`。2026-10-19 的 `GetStop.gz` 解壓後約 9.4 MB，低於 `read_json` 預設的單一物件上限 16 MB。上限仍要明確設大，不靠預設值。
- `COPY ... TO` 的目標可以是用 `getvariable()` 組出來的運算式，檢查目錄因此也用變數傳。
- `-json` 模式下，`SET`、`CREATE`、`COPY` 不印任何東西，只有查詢會印出一個 JSON 陣列。JSON 與 STRUCT 欄位以巢狀物件輸出，不是字串。
- SQL 出錯時，沒加 `-bail` 會繼續執行後面的敘述，最後結束碼是 1。加了 `-bail` 會停在第一個錯誤。執行檔用 `duckdb -no-init -bail -batch -json`，`-no-init` 讓使用者自己的 `~/.duckdbrc` 不影響輸出。
