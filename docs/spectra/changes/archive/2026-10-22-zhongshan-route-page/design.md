## Context

上一個 change `zhongshan-first-health-card` 已封存，它的定義成了正式 spec：`trip-reconstruction`、`layover-metrics`、`load-profile`、`health-card`。`analysis/` 有 `params.sql` 與編號階段檔 `10_load.sql` 到 `60_export.sql`，`bin/health-card` 把變數設成 DuckDB 變數，先接 `params.sql`、再接以 `[0-9]*.sql` 挑出、依檔名排序的階段檔，整段交給 `duckdb` 子行程，產出 Markdown 卡與檢查用 CSV。

Rails 端目前只有範本：`app/` 下沒有任何 model、`db/` 沒有 migration 也沒有 `db/schema.rb`，`config/routes.rb` 只有 `pages#home`。`config/application.rb` 已設 `config.time_zone = "Taipei"`、`config.autoload_lib(ignore: %w[assets tasks])`、預設語系 `tw`。測試用 `use_transactional_fixtures`；test 環境的 Bullet 發現 N+1 會讓 request spec 失敗。

已核對的資料狀況（筆電上的鏡射，2026-10-22）：`bus_event` 有 2026-10-18 到 2026-10-22，`static` 有 2026-10-18 到 2026-10-21。2026-10-18 的採集從 15:11 才開始，那一天不完整。

`docs/decisions.md` 第 2 條：原始檔是唯一真相，衍生結果才進 PostgreSQL；第 3 條：分析用 DuckDB，排程就是起一個 process 跑 SQL 然後結束，不用 Ruby 的 `duckdb` gem，網頁一定查預先算好的表。

詞彙依 `docs/spectra/LANGUAGE.md`：衍生表、路線頁、趟次、折返停留、行駛時間、載客剖面、車上人數、台北日、百分位數。

## Goals / Non-Goals

**Goals:**

- 從原始檔算出中山幹線每個台北日的逐趟結果，寫進 PostgreSQL，可以重跑、可以回補。
- 一個看得到的路線頁 `/routes/15373`，顯示趟次數、行駛時間、折返停留、載客剖面，可以選日期、切換當天與最近 7 天。
- 新增行駛時間的定義，並讓路線頁上的既有指標跟健檢卡在同一份輸入上一致。

**Non-Goals:**

- 排程、部署、每晚自動執行。
- 車牌查詢與任何顯示車牌的畫面。
- 中山幹線以外的路線。
- 平日與假日分開算、最近一個月、月卡。
- 班次串、歸零檢查、資料品質數字上頁面。
- 換休息試算。
- 修改已驗過的趟次、折返停留、載客剖面定義。

## Decisions

### 衍生表存逐趟資料，彙總在讀頁面時用 SQL 算

存五張表：`route_days`（一條路線一個台北日一列：路線名稱、起迄、靜態快照日、寫入時刻）、`route_day_stops`（那一天的站序與站名）、`trips`（逐趟，含車牌、附屬路線、方向、起訖、完整性、兩個替代時刻旗標、時段）、`layovers`（逐筆折返停留：車牌、結束那趟的方向、本趟終點、下一趟起點）、`trip_stop_counts`（每趟每個有人數的站一列：站序、車上人數）。其他四張都屬於某一列 `route_days`，外鍵設 `ON DELETE CASCADE`。`trip_stop_counts` 屬於某一列 `trips`。

理由：路線頁要看最近 7 天、之後一個月的百分位數，百分位數不能拿每天的值合起來算；司機要能查每趟的時刻（`docs/use-cases.md` 第 11 項）。逐趟資料量估計：中山幹線一天 163 趟、約 7,100 個有人數的趟次站（2026-10-19 量到的），一個月二十萬列上下，PostgreSQL 直接彙總沒有壓力。

折返停留不存分鐘數，存兩個時刻，分鐘數在查詢時用兩者相減：`layovers.csv` 的分鐘數四捨五入到一位，拿它算百分位數會跟卡上的值差一點。時段（早尖峰、日間、晚尖峰、其餘）在 DuckDB 端照 `params.sql` 算好存進 `trips.band`，資料庫端不再寫一次邊界。

替代方案：存每天的彙總表（查詢快，但多天的百分位數算不出來，否決）；存原始事件進資料庫（違反決定第 2 條）。

### DuckDB 寫 CSV，rake task 在一個交易裡替換一路線一天

`bin/rails derived:load` 對每個台北日做兩步：先用 DuckDB 跑 `params.sql`、全部編號階段檔，最後接 `analysis/derived_export.sql`，把五張表的資料寫成 CSV 到暫存目錄；再開一個資料庫交易，刪掉該路線該日的 `route_days`（連帶刪掉其餘四張表的那一天），用 PostgreSQL 的 `COPY` 把 CSV 寫進暫存表，再 `INSERT ... SELECT` 進正式表（`trip_stop_counts` 用車牌加起點對回 `trips` 的主鍵）。交易成功才算寫入。

`analysis/derived_export.sql` 的檔名不以數字開頭，所以 `bin/health-card` 不會執行它；匯出照常會經過 `60_export.sql`，它寫的卡用 CSV 留在暫存目錄、跟著刪掉，不影響。

理由：符合決定第 3 條（起一個 process 跑 SQL 然後結束，不用 gem）；同一天重跑結果相同；一天失敗不會留下半套資料。

替代方案：DuckDB 的 postgres 擴充直接寫進資料庫（步驟少，但擴充要在執行時下載，版本跟 DuckDB 綁在一起）；Ruby 逐列 INSERT（慢，也沒有比 COPY 簡單）。

### bin/health-card 與 rake task 共用同一段組 SQL 與執行 DuckDB 的程式

「先 `params.sql`、再依檔名排序的編號階段檔、再接呼叫端指定的檔」這條順序，以及把變數組成 `SET VARIABLE`、呼叫 `duckdb` 子行程、`duckdb` 失敗時原樣帶出標準錯誤，抽到 `lib/` 下一個只用 Ruby 預設 gem 的模組。`bin/health-card` 用 `require_relative` 載入它，Rails 經 `autoload_lib` 載入它。

理由：順序錯了前面的階段讀常數只會拿到 NULL，這條規則只該寫一次。`bin/health-card` 的既有測試（`spec/analysis/cli_spec.rb`、`spec/analysis/card_spec.rb`）在抽出前後都要全綠。

### 時刻存成 timestamptz，以台北時間寫入

原始的 `DataTime` 是沒有時區標記的台北時間。DuckDB 匯出時帶 `+08:00` 寫出，資料庫欄位用 `timestamptz`；讀出後 Rails 依 `config.time_zone = "Taipei"` 顯示。發車小時在 SQL 端用 `AT TIME ZONE 'Asia/Taipei'` 取小時。`route_days.day` 是台北日的 `date`。

### 行駛時間只算完整趟次，排除起訖用替代時刻的趟次

行駛時間是趟次的終點減起點，單位分鐘。只算 `completeness` 為 `complete` 的趟次；`start_from_arrival` 或 `end_from_departure` 為真的趟次排除，排除的趟數在頁面上寫出來。按方向與發車小時（起點在台北時間的小時）分組，每組給趟數、p50、p85、p95，百分位數在順序統計量之間線性內插（PostgreSQL 的 `percentile_cont`），一位小數。

理由：不完整的趟次缺起站或末站，行駛時間一定偏短。起點改用到站時刻的趟次，會把在起站等發車的時間算進去：天母那端的折返停留中位數是 16.2 分鐘（2026-10-19 量到的），這種趟次會把 p85 往上拉，而 p85 正是司機拿去跟站長講的數字。2026-10-19 起點用到站時刻的有 26 趟、終點用離站時刻的有 13 趟（量到的，含不完整趟次，兩組可能重疊），排除後完整趟次剩多少，實作後由頁面上的排除趟數量出來。

替代方案：算進替代時刻的趟次（樣本多，但 p85 偏高，否決）；連不完整趟次一起算（偏短，否決）。

### 路線頁的網址、日期與範圍

`GET /routes/:route_id`，參數 `day`（`YYYY-MM-DD`，台北日）與 `range`（`day` 或 `7d`）。沒給 `day` 時用這條路線已寫入的最新一天；沒給 `range` 時是 `day`。`7d` 是 `day` 與它之前的 6 個台北日中已寫入的那幾天，頁面列出實際涵蓋的日期與星期。路線不在設定的路線清單裡回 404；在清單裡但那一天沒有資料時回 200，顯示「這一天還沒有資料」與已有資料的日期。

頁面四塊，依序：摘要（路線名稱、起迄、範圍、趟數與完整趟數）、行駛時間（去程、返程各一張表，列是發車小時，欄是趟數、p50、p85、p95，加上排除的趟數）、折返停留（按結束那趟的方向各一列，標出那一端的末站站名，給筆數、p10、p50、p90、不到 15 分鐘的比例）、載客剖面（方向、時段、站序、站名，每格中位數 / p90 與趟數）。路線清單放在 `config/` 下的設定檔，只有 15373。

每一塊是一個 ViewComponent，查詢放在不回傳車牌的查詢物件裡；頁面上不出現任何車牌。

### 樣本少的格子用趟數門檻標出來

百分位數所在的格子，趟數少於 5 時標成「樣本少」，數字照樣顯示。5 是估計值，沒有量測依據：它只決定哪些格子要提醒讀者，不影響任何數字；門檻寫成常數，之後有資料再調。

### 一致性用 fixture 鎖住：同一份輸入，頁面的數字等於卡的數字

對 `spec/fixtures/analysis/` 的合成資料，一邊跑 `bin/health-card` 取卡的 JSON，一邊跑 `derived:load` 寫進測試資料庫，再用路線頁的查詢物件算同一天：趟數與完整趟數、各方向折返停留的筆數與 p10、p50、p90、不到 15 分鐘的比例、載客剖面每格的趟數、中位數、p90，逐項相等。比較的是查詢物件的回傳值，不是 HTML。

理由：資料庫端重算彙總，定義只要有一處走樣（例如時段邊界、百分位數的內插方式、分鐘數的進位），這個測試就會失敗。

### 回補從 2026-10-19 起，讀檔視窗沒結束的日子不算

`derived:load` 接受單一日 `DAY` 或一段 `FROM`、`TO`。一天能算的條件是：`bus_event/<D>/` 有檔、`static/<D>/` 有三支靜態檔、而且 D 的讀檔視窗已經結束（`bus_event/<D+1>/01.jsonl` 或 `.jsonl.gz` 存在）。不符合時那一天失敗並說明原因，不寫任何東西。2026-10-18 只從 15:11 開始採集，不回補。

理由：讀檔視窗到 D+1 的 02:00，視窗沒結束就算，跨午夜的趟次會被截斷，數字會跟之後重算的不一樣。

## Implementation Contract

**行為**：

- 操作者在 repo 執行 `bin/rails derived:load ROUTE=15373 DAY=2026-10-19`（或 `FROM=2026-10-19 TO=2026-10-21`），資料根目錄只從環境變數 `TURNAROUND_DATA` 取，不寫進任何檔案。每一天印一行結果：寫入的趟數、折返停留筆數、趟次站數，或失敗原因。
- 開 `bin/dev` 後瀏覽 `/routes/15373`，看到最新一天的路線頁；`?day=2026-10-19&range=7d` 看到 10-19 與之前已寫入的日子。

**介面與資料形狀**：

- `analysis/derived_export.sql`：讀編號階段建立的 `routes`、`stops`、`trips`、`trip_bands`、`layovers`、`trip_stop_counts`，寫出 `route_day.csv`、`stops.csv`、`trips.csv`、`layovers.csv`、`trip_stop_counts.csv` 到變數 `derived_dir`。時刻帶 `+08:00`；`trip_stop_counts.csv` 以 `bus_id`、`start_time` 指回趟次；欄位順序固定、依車牌與時刻排序。
- 資料表：`route_days`（`route_id`、`day`、`route_name`、`departure`、`destination`、`static_day`、`loaded_at`，`route_id` 加 `day` 唯一）、`route_day_stops`（`route_day_id`、`go_back`、`seq`、`stop_name`）、`trips`（`route_day_id`、`bus_id`、`path_attribute_id`、`go_back`、`band`、`start_time`、`end_time`、`first_seq`、`last_seq`、`n_events`、`n_stops_observed`、`completeness`、`start_from_arrival`、`end_from_departure`，`route_day_id`、`bus_id`、`start_time` 唯一）、`layovers`（`route_day_id`、`bus_id`、`go_back`、`end_time`、`next_start_time`）、`trip_stop_counts`（`trip_id`、`seq`、`on_board`，`trip_id` 加 `seq` 唯一）。
- 路線清單設定：`config/` 下的 YAML，列出可以顯示的路線 `Id`。

**失敗模式**：

- 沒有 `TURNAROUND_DATA`、沒有 `ROUTE`、日期格式錯、只給 `FROM` 或 `TO` 其中一個：印用法，結束碼非零，不寫任何東西。
- `duckdb` 不在 PATH：印「需要 DuckDB CLI，`brew install duckdb`」，不寫任何東西。
- 某一天不符合可算條件或 `duckdb` 失敗：那一天印原因（`duckdb` 的標準錯誤原樣帶出），那一天不寫入；範圍回補時停在那一天，之前已寫入的日子保留，最後印出寫入了哪些日子。
- 路線頁：路線不在清單回 404；`day` 格式錯回 400；`range` 不是 `day` 或 `7d` 回 400；那一天沒有資料顯示提示。

**驗收**：

- `bundle exec rspec`（或 `make test`）全綠，含：一致性測試、rake task 的替換與失敗測試、行駛時間的定義測試、路線頁的 request 與 component 測試、頁面不含 fixture 的任何車牌。
- `bin/health-card` 的既有測試在抽出共用模組前後都全綠。
- 對真資料執行 `bin/rails derived:load ROUTE=15373 FROM=2026-10-19 TO=2026-10-21`，三天都寫入；`/routes/15373?day=2026-10-19` 的趟數 163、完整趟數 124，跟 `docs/cards/15373-2026-10-19.md` 相同。
- `bin/rubocop` 對新增與修改的檔案無 offense。

**範圍邊界**：在範圍內的是上面的指令、資料表、路線頁、行駛時間定義與 `docs/spectra/LANGUAGE.md` 兩條的更新。不在範圍內：排程、部署、車牌查詢、其他路線、日型別、月卡、班次串與歸零檢查上頁面、換休息試算、修改既有指標定義、修改 `bin/health-card` 的輸出。

## Risks / Trade-offs

- [資料庫端重算的彙總跟 DuckDB 端走樣] → 一致性測試逐項比對；時段存成欄位，不在兩邊各寫一次。
- [百分位數層級寫在兩個地方：`params.sql` 給卡用，Ruby 常數給頁面用] → 一致性測試會在兩邊不同時失敗；這個 change 不把它們合成一處，因為頁面要的 p85、p95 卡上沒有。
- [最近 7 天混了平日與假日] → 頁面寫明沒有分日型別，列出涵蓋的日期與星期；`docs/spectra/LANGUAGE.md` 的日型別一條要求所有指標平假日分開算，這個 change 先不做，日型別另開 change。
- [車牌存進資料庫] → 只在逐趟資料表；查詢物件不選車牌欄位，request spec 斷言頁面不含任何 fixture 車牌。
- [筆電上的資料最多比 Mac mini 晚一小時] → 可算條件看 D+1 的 01 時檔是否存在，鏡射還沒到就不算。
- [第一批 migration] → `bin/rails parallel:setup` 會在 `db/schema.rb` 出現後開始載入 schema；平行測試的資料庫要重新準備一次，任務裡寫明。
