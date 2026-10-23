<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
開始 apply 之前先確認 day-types 已經 archive（proposal 的排程）：兩個 change 改到同一批 fixture 說明、詞彙表與載入的 spec。
每個任務做完時 spec/analysis 與 make test 都要是綠的；第 2、3 組只用灌入的資料測新規則，fixture 的數字到第 4 組才變。
-->

## 1. 讀進別條路線的記錄

- [x] 1.1 實作 Runs on other routes between trips 的讀檔部分，套用 design「別條路線的記錄在第 10 階段讀進 other_route_events，只讀這條路線的車」，以及「至少經過 3 個不同站牌才算跑了別的路線，RouteID 0 一律不算」裡 RouteID 0 的部分：`analysis/10_load.sql` 新增 table `other_route_events(bus_id, path_attribute_id, stop_id, data_time)`，從 `bus_event_files` 讀 `BusID` 在 `bus_events` 裡、`RouteID` 不是 0 也不是這條路線附屬路線的記錄，照 `(bus_id, data_time)` 留最早抓到的一筆；檔頭的建立清單加上它。`raw_bus_events` 與 `bus_events` 照舊只有這條路線。驗證：`spec/analysis/load_spec.rb` 新增三例，用現在的 fixture 斷言：`other_route_events` 是 TEST-0004 的 20 筆、全部是 9100；Scenario「Records with RouteID 0」（TEST-0004 15:00 那筆不在裡面）；Scenario「Records of the route's own sub-routes」（沒有 9001、9002、9003）。既有的「路線過濾」與 load_counts 的例子不改斷言仍綠，`bundle exec rspec spec/analysis` 全綠。

## 2. 折返停留與班次串的規則

- [x] 2.1 實作 Layover definition 的修改與 Runs on other routes between trips 的判斷，套用 design「至少經過 3 個不同站牌才算跑了別的路線，RouteID 0 一律不算」與「other_route 改成「兩趟之間跑了別的路線」，排除的順序不變」。內容：
  - `analysis/params.sql` 加 `other_route_min_stops`，值 3，註解照 design 的 Interface。
  - `layover_pairs` 加 `ran_other_route`：這台車 `other_route_events` 裡時刻晚於本趟終點、早於下一趟起點的記錄，不同 `stop_id` 數不少於門檻；`other_route` 的條件換成它，分類順序不變。
  - `spec/support/duckdb.rb` 加把 `other_route_events` 換成指定記錄的 SQL 產生器（空陣列給出空表）；`spec/analysis/layovers_spec.rb` 灌入趟次的 helper 同時換掉 `other_route_events`，預設是空的。`replace_trips_sql` 不改，`profile_spec`、`quality_spec` 不受影響。

  驗證：`spec/analysis/layovers_spec.rb` 用灌入的趟次與記錄斷言下列 Scenario：
  - 「Another route between the trips」：3 個站，`other_route` 1、沒有折返停留。
  - 「Route code set between the trips」：1 個站，12.0 分鐘、`other_route` 0。
  - Example「Threshold boundary」：2 個站算折返停留、3 個站算 `other_route`。
  - 「Another route on a pair that misses its last stop」：只算 `no_last_stop`。
  - 原本「下一趟是別的路線時不算」那一例刪掉，由上面的「Another route between the trips」取代。

  用現在的 fixture 斷言 Scenario「Records outside the gap」：TEST-0004 兩組配對的 `ran_other_route` 都是 false，折返停留仍是 17.0、12.0。fixture 的 19 筆與四類計數 3、1、0、0 不改斷言仍綠；`bundle exec rspec spec/analysis` 全綠。
  [after: 1.1]
- [x] 2.2 實作 Rest-rule windows and chains 的修改，套用 design「班次串遇到兩趟之間跑了別的路線也切斷」：`rest_runs` 由每台車的第一趟開始一個序列，遇到不完整的趟次、或這一趟與前一趟那組配對的 `ran_other_route` 是 true，就開始新的序列；四小時視窗、額度、併串不動，註解改成實際的切斷條件。`spec/analysis/chains_spec.rb` 灌入趟次的 helper 同時換掉 `other_route_events`，預設是空的。驗證：`spec/analysis/chains_spec.rb` 用灌入的趟次（10:20–11:08、11:20–12:08、17:10–17:58）與同一台車 14:10 到 14:30 經過 3 個站的記錄，斷言 Scenario「Another route cuts the run」：`rest_runs` 把 17:10 那趟放進跟前兩趟不同的序列、`rest_windows` 沒有任何一列、`chain_report` 是空的。對照：同一組趟次不灌記錄時，三趟在同一個序列，`rest_windows` 有 10:20 與 11:20 起的兩列、都不被標（302 分鐘那段是折返停留、給了額度），證明序列是被這條規則切開的。fixture 的班次串與被標視窗的例子不改斷言仍綠；`bundle exec rspec spec/analysis` 全綠。 [after: 2.1]

## 3. 卡與路線頁的說明

- [x] 3.1 實作卡的說明，套用 design「卡與路線頁的說明寫出別條路線的規則」的卡那一部分：`analysis/60_export.sql` 的 `layovers` 加 `other_route_min_stops`；`bin/health-card` 折返停留一節的說明、排除一行（「兩趟之間跑了別的路線 N 組」）、班次串的切斷說明照 design 的文字，門檻讀 JSON。驗證：
  - `spec/analysis/card_spec.rb` 的排除一行改成「本趟沒有到末站 3 組、下一趟不是從起站出發 1 組、兩趟之間跑了別的路線 0 組、差值為負 0 組」（fixture 這時還沒有夾在兩趟之間的記錄）。
  - 同一個 spec 加一例：折返停留一節的說明含「經過至少 3 個站」，數字來自 JSON 的門檻。
  - 其餘說明文字是固定文案，做內容審查對照 design。
  - `bundle exec rspec spec/analysis` 全綠。

  [after: 2.2]
- [x] 3.2 實作路線頁的說明，套用 design「卡與路線頁的說明寫出別條路線的規則」的路線頁那一部分：`app/components/layover_table_component.yml` 的 tw 與 en `note` 換成 design 的文字，不寫門檻數字。驗證：固定文案，做內容審查對照 design；`bundle exec rspec spec/components/layover_table_component_spec.rb` 不改斷言仍綠；`bin/rubocop` 不涉及（只改 yml）。

## 4. fixture 加上夾在兩趟之間的記錄

- [x] 4.1 套用 design「fixture 2026-10-19 的手算值」。內容：
  - fixture 的 `bus_event/2026-10-19/14.jsonl` 加 TEST-0002 的三筆、`15.jsonl` 加 TEST-0001 的三筆，格式與位置照 design 的表，依 `_fetched_at` 排在對的位置，16 時檔照舊是空的。
  - `spec/fixtures/analysis/README.md`：「到離站的案例」加這兩例、改寫 9100 那一列，「折返停留與班次串」改成 18 筆、四類計數與班次串切斷的說明。
  - 所有斷言 fixture 數字的 spec 改成 design 的值。

  驗證：
  - `spec/analysis/fixtures_spec.rb` 加兩例：兩段記錄的時刻、站牌與檔案；既有例子（16 時空檔、`RouteID` 的集合、DutyStatus 2 的清單）不改斷言仍綠。
  - `spec/analysis/load_spec.rb` 的 `other_route_events` 改成 26 筆（TEST-0004 20、TEST-0002 3、TEST-0001 3）。
  - `spec/analysis/layovers_spec.rb`：
    - 斷言 Example「Fixture day 2026-10-19」，值照 design 的手算：每台車依序的折返停留共 18 筆；`no_last_stop` 3、`no_first_stop` 1、`other_route` 1、`negative` 0；去程結束的筆數 10、中位數 13.5；返程結束的筆數 8、中位數 19.0。
    - 斷言 Scenario「Run on another route between two trips」（TEST-0002 12:08 那組的 `ran_other_route` 是 true）。
    - 斷言 Scenario「Route code set at a terminal」（TEST-0001 15:40 那組是 false，仍是 85.0）。
  - `spec/analysis/chains_spec.rb` 不改斷言仍綠，即 Example「Fixture day keeps one chain」。
  - `spec/analysis/card_spec.rb` 的分佈列與分箱照 design，排除一行是「⋯兩趟之間跑了別的路線 1 組⋯」。
  - 其餘四個 spec 改成 18 筆：`spec/analysis/cli_spec.rb` 的 `layovers.csv`（TEST-0002 沒有 302.0）、`spec/analysis/derived_export_spec.rb`（27、18、96、10、1）、`spec/models/route_day_loader_spec.rb`、`spec/models/derived_load_command_spec.rb`（「趟次 27、折返停留 18、趟次站 96」）。
  - `spec/models/route_page/card_consistency_spec.rb` 不改斷言仍綠。
  - `make test` 全綠。

  [after: 3.1]

## 5. 文件與真資料

- [x] 5.1 文件：`docs/spectra/LANGUAGE.md` 的「折返停留」把成立條件的「同一路線 `Id`」換成「兩趟之間沒有去跑別的路線」，邊界補上門檻、`RouteID` 0 不算、只經過 1、2 個站不算與 2026-10-22 中山幹線那台車去開 206 的例子；「班次串」補上遇到不完整趟次或兩趟之間跑了別的路線就切斷。`analysis/README.md` 的階段表加 `other_route_events`，`layover_pairs` 與班次串的說明改成新規則。驗證：內容審查對照 `layover-metrics` 的 delta spec 與 design。 [after: 4.1]
- [x] 5.2 以真資料驗收，`TURNAROUND_DATA` 指到資料根目錄（不寫進任何檔案）。步驟：
  1. `bin/health-card --route 15373 --day 2026-10-22`：折返停留 105 筆、排除一行的別的路線 1 組。
  2. `bin/health-card --route 16111 --day 2026-10-22`：折返停留 312 筆、別的路線 60 組。這是 307 第一次跑完整張卡；如果卡因為 `GetRoute.gz` 同一個附屬路線有好幾列而出錯或印出重複的附屬路線，記下來交給處理重複列的那個 change，不在這裡修、也不擋這個 change。
  3. `bin/rails derived:load ROUTE=15373 FROM=2026-10-19 TO=<讀檔視窗已經結束的最新一天>`。`day-types` archive 之後，資料根目錄要有 `external/office-calendar/2026/` 的快照才載得進去；沒有的話先跑 `bin/rails external:office_calendar YEAR=2026`。
  4. 用 `bin/rails runner` 印出 15373 在 10-19 到 10-21 的 `Layover` 筆數：應是 332（現在 333）；10-22 有載入時是 105。

  數字跟 proposal 不同時記下新數字與原因，不硬套。驗證：上述指令的輸出對照 proposal；`/routes/15373?day=2026-10-21&range=7d` 的換休息試算涵蓋率跟著變（人工確認）；`make test`、`bin/rubocop`（改到的 Ruby 檔）、`bin/brakeman` 全綠。
  [after: 3.2, 5.1]
