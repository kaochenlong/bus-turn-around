## Why

這個 change 服務三樣交付物的第一樣路線健檢卡（每天更新的路線頁是它在網站上的形式）與第二樣「換休息」試算：把有路線頁的路線從中山幹線、251、251區 三條加到第四條 307，而且照 2026-10-23 的決定，307（路線 `Id` 16111，板橋－撫遠街）與 307西藏三民（`Id` 19108，同樣板橋－撫遠街）在網站上算一條路線、一頁。需要的資料是 n-gear 從 2026-10-18 起收的全路網原始檔（兩條都在裡面）、每天的靜態快照，與資料根目錄既有的捷運出入口、辦公日曆、公廁快照；另外用一次 TDX 的站間旅行時間做內部驗證，不進衍生表、不發布。

為什麼是 307：`docs/background.md` 點名先跑通的五條線裡，307 排在中山幹線與 251 區間之後；2026-10-22 一天版量到它 569 趟、85 台車，起站離站事件全路網第二多，而且是第一條兩家業者聯營（臺北客運、首都客運）、第一條兩端都停車的路線，現有的定義會在它身上被逼出新問題。

為什麼兩個 `Id` 算一條：2026-10-24 的靜態快照裡，兩條的起迄站都是臺北客運板橋前站(藝文) 與莊敬里，去程 66 站對 65 站、站位相同的 59 站，返程 62 站對 61 站、站位相同的 55 站，差的是中段兩處各繞不同的街（307 走萬大路、莒光派出所與南京三民一帶 7 站，307西藏三民 走西藏路、廈安里與三民路一帶 6 站），共同站在兩邊的順序一致。2026-10-22 一天版（含去重前 4 倍的事件重複，幾何與配對不受影響）量到 85 台車裡 55 台當天兩條都跑、一天切換 140 次；分開算時 307 有 60 組折返配對被判成「跑了別的路線」，60 組全部是中間去跑 307西藏三民，307西藏三民 自己只剩 1 筆折返停留。分開算會把同一台車在同一個折返點的休息算丟。

為什麼現在：`01-routes-dedupe` 修掉 `GetRoute.gz` 重複列造成的事件放大之後，307 才量得準；這個 change 排在它之後。先前把 307 留到之後的決定都是當時的範圍限制：`zhongshan-route-page` 與 `zhongshan-first-health-card` 的非目標（其他路線各自驗過定義再加）、`route-251-pages` 的非目標（307 要先修 SQL）、`02-route-stop-sequence` 的非目標（307 合成一頁之後 Id 那一行怎麼寫兩個 Id，由 307 的 change 決定）、`03-route-shape-map` 的非目標（307 一頁兩個路線 Id 怎麼畫，等加那些路線的 change）。這個 change 回答前兩個，路線圖那一個留給 `03-route-shape-map` 之後。

## What Changes

- `config/route_page.yml` 的路線清單在 11764 之後加 16111，兩端的性質寫查證日期與證據；新的鍵 `member_routes` 列出掛在同一頁的附屬路線的路線 `Id`，16111 是 `[19108]`。`/routes/16111` 有路線頁，`/routes/19108` 回 404。
- 分析 SQL 接受一組路線 `Id`：`routes` 與 `stops` 讀全部成員，事件各自對回自己的 `Id` 與站序切趟次，折返停留照舊以同一車牌相鄰兩趟配對，所以跨兩個 `Id` 的配對成立，成員的附屬路線不算「別的路線」。沿線的數字以 16111 的站序為準：成員趟次的車上人數在兩條都停的站（同一個 `stopLocationId`、同一個方向）併進 16111 那一站，只有成員才停的站不進沿線載客圖、捷運重疊與站序。
- 衍生表：`route_day_stops` 存每個成員的站序並記 `route_id` 與 `stop_location_id`，`trips` 記每趟的 `route_id`，`trip_stop_counts` 的 `seq` 是 16111 的站序；`bin/rails derived:load ROUTE=16111` 一次載入兩個 `Id`，`ROUTE=19108` 是用法錯誤。`bin/health-card` 多 `--also-route`，同一組 `Id` 算出同一組數字。
- 路線頁：頁首與首頁卡的 Id 那一行寫「路線 Id 16111・19108」；站序區塊列 16111 的站序，每個方向後面一句話說 307西藏三民 不停哪幾站、改停哪幾站；資料限制多一段說明兩個 `Id` 怎麼合算，並列出涵蓋日子裡每個 `Id` 的趟次數。趟次、行駛時間、折返停留、來回一趟、週期、換休息試算不分 `Id`。
- `docs/spectra/LANGUAGE.md`：「路線」「附屬路線」「路線頁」「站序」四條補上 307 的情形。
- 用真資料驗收：GPS 查證兩端的性質，`derived:load` 載入 2026-10-19 到 10-22，記下趟次、折返停留、跨 `Id` 配對的數字；用 TDX 站間旅行時間對照 307 分時段的行駛時間，結果只記在 design，頁面不放。

## Non-Goals

非目標寫在 design。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `turnaround-ends`：「Verified end nature per route」多 307 兩端的情境，路線清單的情境加上 16111。
- `trip-reconstruction`：「Sub-route to route and direction mapping」改成對一組路線 `Id` 映射，每個事件對回自己的 `Id` 與站序；「Sub-route stop sequence check」的比對以附屬路線所屬的那個 `Id` 的站序為準。
- `layover-metrics`：「Runs on other routes between trips」把每個成員的 `pathAttributeId` 都當成這條路線自己的。
- `load-profile`：新增成員趟次的車上人數怎麼併進頁面路線的站。
- `mrt-overlap`：新增重疊度與重疊路段只算頁面路線的站。
- `derived-tables`：「Load task invocation」的 `ROUTE` 要是路線清單裡的頁面路線或沒設定的路線，成員是用法錯誤；「Stored trips match the health card」用同一組 `Id` 比對；新增衍生表的列記 `route_id` 與 `stop_location_id`。
- `health-card`：「Invocation and parameters」多 `--also-route`。
- `route-page`：新增頁首 Id 那一行寫全部 `Id`、站序區塊的成員一句話、資料限制的合算說明。
- `home-page`：新增首頁卡的 Id 那一行寫全部 `Id`。

## Impact

- 修改 `analysis/10_load.sql`、`analysis/20_trips.sql`、`analysis/40_load_profile.sql`、`analysis/mrt_overlap.sql`、`analysis/turnaround_facilities.sql`、`analysis/derived_export.sql`、`analysis/60_export.sql`，與 `lib/analysis_run.rb`（陣列變數）。
- 修改 `bin/health-card`（`--also-route`）、`app/models/derived_load_command.rb`、`app/models/route_day_loader.rb`、`app/models/route_page.rb`、`app/models/route_page/stop_sequence.rb`、`load_profile.rb`、`mrt_overlap.rb`、`layover_stats.rb`、`summary.rb`、`app/components/route_coverage_component.*`、`route_list_component.*`、`stop_sequence_component.*`、`data_limitations_component.*`、`config/route_page.yml`、`config/locales`。
- 新增 migration：`route_day_stops` 加 `route_id`（回填成 `route_days.route_id` 後設為必填）與 `stop_location_id`、唯一索引改成 `(route_day_id, route_id, go_back, seq)`；`trips` 加 `route_id`（回填後必填）。已載入的日子不用重載，`stop_location_id` 在重載之前是空的。
- 測試與 fixture：`spec/fixtures/analysis/` 多一條掛在 9001 底下的附屬路線 9050（自己的路線 `Id`，中段一站不同）、2026-10-23 的事件與靜態快照、`static/2026-10-19` 加 9050 的列；`spec/analysis/*`、`spec/models/route_page/*`、`spec/components/*`、`spec/requests/routes_spec.rb` 對應的例子；`spec/analysis/fixtures_spec.rb` 與數 `route_day_stops` 的例子跟著 9050 的站序改。
- 衍生表：開發資料庫多 16111 的四個台北日，底下是兩個 `Id` 的趟次。
- 依賴 `01-routes-dedupe`（去重）；跟進行中的 `03-route-shape-map` 都動 `derived-tables` 與 `route-page`，這裡對那兩份只用新增的 requirement，不改它們正在改的那幾條。
- 資料限制與假設：指標定義不變，限制照舊：車不等於人，折返停留是駕駛休息的上限；車上人數看下車刷卡率；10 秒輪詢會漏站，漏了起站或末站的趟次不算行駛時間；跨小時檔的重複已以 `(BusID, DataTime)` 去除。這次多的：兩個 `Id` 的行駛時間合在一起報，307西藏三民 少一站、走不同的街，合併後的分佈是兩者的混合；只有 307西藏三民 才停的 6 站沒有沿線數字；兩端的性質是查證那一天的事實，業者改折返方式時設定會過期；TDX 的站間時間是它用近幾個月資料推估的值，依 TDX 資料使用條款只在內部對照。
