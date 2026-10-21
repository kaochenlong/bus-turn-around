<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
-->

## 1. 共用的 DuckDB 執行程式

- [x] 1.1 實作 design「bin/health-card 與 rake task 共用同一段組 SQL 與執行 DuckDB 的程式」：把「變數設定、`analysis/params.sql`、依檔名排序的編號階段檔、再接呼叫端指定的檔」的組法與呼叫 `duckdb` 子行程、失敗時原樣帶出標準錯誤的程式，抽到 `lib/` 下一個只用 Ruby 預設 gem 的模組；`bin/health-card` 改用 `require_relative` 載入它，輸出不變。這是 Derived export 的 Scenario「Stage order shared with the health card」的前半。驗證：新增的單元測試斷言組出的 SQL 依序是變數、`params.sql`、編號階段、呼叫端指定的檔；`spec/analysis/cli_spec.rb` 與 `spec/analysis/card_spec.rb` 不改任何斷言仍全綠；`bin/rubocop` 對改動的檔案無 offense。

## 2. 匯出逐趟資料

- [x] 2.1 新增 `analysis/derived_export.sql` 實作 Derived export：讀編號階段建立的路線、站序、趟次與時段、折返停留、每趟逐站車上人數，寫出 `route_day.csv`、`stops.csv`、`trips.csv`、`layovers.csv`、`trip_stop_counts.csv` 到變數 `derived_dir`，時刻帶 `+08:00`，欄位順序固定、依車牌與時刻排序；檔名不以數字開頭，`bin/health-card` 不會執行它。驗證：新增的 spec 對 `spec/fixtures/analysis/` 跑一次，斷言五個檔的欄位名、`trips.csv` 27 列、`layovers.csv` 16 列、`trip_stop_counts.csv` 96 列（筆數取自 `spec/fixtures/analysis/README.md` 的趟次與折返停留表，以及 `spec/analysis/profile_spec.rb` 涵蓋率 example 的 96 個有人數的站）、時刻字串以 `+08:00` 結尾、連跑兩次位元組相同；`spec/analysis/card_spec.rb` 仍全綠。 [after: 1.1]

## 3. 衍生表與寫入

- [x] 3.1 實作 design「衍生表存逐趟資料，彙總在讀頁面時用 SQL 算」的五張表：migration 建 `route_days`、`route_day_stops`、`trips`、`layovers`、`trip_stop_counts`，欄位與唯一鍵照 design 的 Implementation Contract，時刻欄位照 design「時刻存成 timestamptz，以台北時間寫入」用 `timestamptz`，外鍵 `ON DELETE CASCADE`；對應的 ActiveRecord model 與關聯；`config/` 下新增路線清單設定，只有 15373（測試環境另有 9001）。這是 repo 第一批 migration，跑完要 `bin/rails parallel:setup` 重新準備平行測試的資料庫。驗證：model spec 斷言刪掉一列 `route_days` 時其餘四張表的那一天都被刪掉、同一路線同一天不能有兩列 `route_days`；`db/schema.rb` 產生；`make test` 全綠。 [after: 2.1]
- [x] 3.2 實作 Replace one route day atomically 與 design「DuckDB 寫 CSV，rake task 在一個交易裡替換一路線一天」的寫入部分：一個類別接路線、台北日與資料根目錄，用 1.1 的模組跑 DuckDB 到暫存目錄，再在一個交易裡刪掉該路線該日、以 `COPY` 寫入暫存表、`INSERT ... SELECT` 進正式表，`trip_stop_counts` 以車牌加起點對回 `trips`。驗證：spec 對 fixture 2026-10-19 寫入兩次，斷言趟次 27、折返停留 16、趟次站 96 筆且第二次後不變（Scenario「Reload is idempotent」）；先寫入一次、再讓第二次在寫入途中失敗，斷言資料庫裡仍是第一次的趟次（Scenario「Failure keeps the old day」）。 [after: 3.1]
- [x] 3.3 實作 Load task invocation、Day eligibility、Range loading stops at the first failure 與 design「回補從 2026-10-19 起，讀檔視窗沒結束的日子不算」：rake task `derived:load` 讀 `ROUTE`、`DAY` 或 `FROM` 加 `TO`、`TURNAROUND_DATA`，每天檢查可算條件後呼叫 3.2 的類別，每天印一行結果，範圍回補停在第一個失敗的日子並印出已寫入的日子。驗證：rake task spec 斷言 Scenario「Usage error」的五種情況、「DuckDB missing」、「Read window not over」（fixture 的 2026-10-20 沒有 2026-10-21 的 01 時檔）、「Middle day fails」，每種都斷言結束狀態、訊息與資料庫沒有多出那一天。 [after: 3.2]

## 4. 頁面的查詢

- [x] 4.1 實作 Stored trips match the health card 與 design「一致性用 fixture 鎖住：同一份輸入，頁面的數字等於卡的數字」：路線頁用的查詢物件，對一組已寫入的日子算摘要（趟數、完整趟數）、各方向的折返停留（筆數、p10、p50、p90、不到 15 分鐘的比例，分鐘數由兩個時刻相減，`percentile_cont` 一位小數）與載客剖面（方向、時段、站序、站名、趟數、中位數、p90），都不選車牌欄位。驗證：一致性 spec 對 fixture 2026-10-19 同時跑 `bin/health-card` 與 3.2 的寫入，逐項斷言查詢物件的值等於卡的 JSON（Scenario「Fixture day agrees with the card」）；另以兩天灌入的資料斷言 Page content 的 Scenario「Seven-day percentile pools trips」；request spec 下 Bullet 不報 N+1。 [after: 3.2]
- [x] 4.2 實作 Run time of a trip、Run time summary 與 design「行駛時間只算完整趟次，排除起訖用替代時刻的趟次」：行駛時間的查詢物件，依方向與台北時間的發車小時分組，給趟數、p50、p85、p95 與 design「樣本少的格子用趟數門檻標出來」的標記（少於 5 趟，常數），並給各方向排除的趟數。驗證：spec 以灌入的趟次斷言 Scenario「Excluded trips」、「Percentiles of one hour」（50、52、55、60、70 分鐘得 p50 55.0、p85 64.0、p95 68.0）、「Small sample」、「Hour from Taipei time」（23:40 發、隔天 00:50 到屬 23 時、70.0 分鐘）。 [after: 4.1]

## 5. 路線頁

- [x] 5.1 實作 Route page address and parameters 與 Day coverage，套用 design「路線頁的網址、日期與範圍」：`config/routes.rb` 加 `GET /routes/:route_id`，controller 依路線清單回 404、`day` 格式錯或 `range` 不是 `day`、`7d` 回 400、預設最新一天與當天範圍、`7d` 只取已寫入的日子並列出日期與星期、沒有資料的日子回 200 並列出已有資料的日子。驗證：request spec 斷言 Scenario「Route not configured」、「Defaults」、「Bad parameter」、「Seven days with gaps」、「Day without data」。 [after: 4.2]
- [x] 5.2 實作 Page content 的摘要與行駛時間兩塊：各一個 ViewComponent（`bin/rails g view_component:component` 產生、文案放同層 `.yml`），摘要顯示路線名稱、起迄、涵蓋日期、趟數與完整趟數；行駛時間去程、返程各一張表，列是發車小時，欄是趟數、p50、p85、p95，樣本少的格子標出來，表下寫排除的趟數。驗證：component spec 以查詢物件的回傳值渲染，斷言表格的列與數字、樣本少的標記出現在趟數少於 5 的列；request spec 斷言頁面依序出現這兩塊。 [after: 5.1]
- [x] 5.3 實作 Page content 的折返停留與載客剖面兩塊、No vehicle identifiers on the page、Data limitations on the page：折返停留按結束那趟的方向各一列、標出那一端的末站站名；載客剖面照方向、時段、站序；資料限制一節列四點。驗證：component spec 斷言兩張表的列與數字；request spec 斷言頁面依 Page content 的順序出現四塊、Scenario「Fixture plates absent」（`TEST-0001` 到 `TEST-0004` 都不在回應裡）、Scenario「Limitations present」；`bin/rubocop` 對新增檔案無 offense。 [after: 5.2]

## 6. 文件與真資料

- [x] 6.1 更新 `docs/spectra/LANGUAGE.md` 的「衍生表」與「行駛時間」兩條：「在資料或程式碼裡」改寫成實際的表名、欄位與 `derived:load`，「行駛時間」的邊界寫入這個 change 決定的完整趟次與替代時刻排除；`analysis/README.md` 加上 `derived_export.sql` 的輸入、輸出與執行方式。驗證：內容審查對照 design 的 Implementation Contract 與 `run-time` spec。 [after: 5.3]
- [x] 6.2 以真資料回補並在瀏覽器確認：`TURNAROUND_DATA` 指到資料根目錄（不寫進任何檔案），執行 `bin/rails derived:load ROUTE=15373 FROM=2026-10-19 TO=2026-10-21`，三天都寫入；`/routes/15373?day=2026-10-19` 的趟數 163、完整趟數 124，與 `docs/cards/15373-2026-10-19.md` 相同；`?day=2026-10-21&range=7d` 列出 10-19 到 10-21 三天。驗證：rake 輸出與頁面數字對照卡；用 `bin/dev` 開頁面做人工內容審查，確認四塊與資料限制都在、沒有車牌。 [after: 6.1]
