## Why

這個 change 服務三樣交付物的第一樣路線健檢卡（每天更新的路線頁是它在網站上的形式）與第二樣「換休息」試算：讓衍生表與健檢卡共用的分析 SQL，在 `GetRoute.gz` 有重複列的路線上算出正確的數字。需要的資料只有既有的靜態快照 `GetRoute.gz`，n-gear 每天 04:30 已經抓，不用新的來源。

現在做，是因為下一條要加的路線 307 正是有重複列的路線。`analysis/10_load.sql` 建 `routes` 時沒有去重，而同檔的 `stop_events`、`unknown_stop_events`、`sequence_check` 與 `analysis/40_load_profile.sql` 的 `seat_stop_events` 都以 `path_attribute_id` join `routes`：一條附屬路線在 `routes` 有幾列，它的每筆事件就被算成幾筆（讀 SQL 推得）。2026-10-24 的快照量到的：`GetRoute.gz` 800 列、731 組 `(Id, pathAttributeId)`，其中 55 組有多列、涉及 24 條路線；多列之間只有 `providerId`、`providerName` 不同（41 組），選到的六個欄位（`Id`、`pathAttributeId`、`nameZh`、`pathAttributeName`、`departureZh`、`destinationZh`）在 55 組裡全部相同。307（`Id` 16111）的 157462、157463 與 307西藏三民（`Id` 19108）的 161407、161408 各 4 列，是臺北客運與首都客運兩個 `providerId` 各兩列。已有路線頁的 15373、10712、11764 都只有一列。`route-251-pages` 的非目標寫明「修 SQL 是另一個 change，修完確認中山幹線的輸出不變，再加 307」，這個 change 就是它。

## What Changes

- `analysis/10_load.sql` 建 `routes` 時對選到的六個欄位去重，每條附屬路線一列；`bin/health-card` 與 `bin/rails derived:load` 共用這段 SQL，兩邊一起修好。
- fixture：`spec/fixtures/analysis/static/2026-10-19/GetRoute.gz` 多一列跟附屬路線 9002（測試幹線去程半）六欄完全相同、只有 `providerId` 與 `providerName` 不同的列，照真資料裡重複列的樣子；`spec/fixtures/analysis/README.md` 記下這一列。
- 測試：`spec/analysis/load_spec.rb` 多一個例子，`routes` 是 9001、9002、9003 各一列，改 SQL 之前這個例子要先失敗；`spec/analysis/fixtures_spec.rb` 描述 `GetRoute.gz` 的例子改成容納那一列。其他讀 `stop_events`、`seat_stop_events` 的例子一個斷言都不改，改 SQL 之後全部回綠。
- 確認已有三條路線的輸出不變：對 15373、10712、11764 的 2026-10-22，用 `analysis/derived_export.sql` 的匯出改前改後各跑一次，八個 CSV 逐檔 byte 相同。

## Non-Goals

- 加 307 或任何路線、改 `config/route_page.yml`、改詞彙表：`02-route-307-page`。
- `GetStop.gz`、`GetPathDetail.gz` 有沒有重複列沒有量過，也不在這裡處理；它們不是以 `path_attribute_id` join `routes` 放大事件的來源。
- 同一個 `(Id, pathAttributeId)` 六欄不同的列怎麼取捨：2026-10-24 的快照一組都沒有，不替它定規則。
- 指標定義、`bin/health-card` 的輸出格式、頁面、衍生表的 schema。
- 重新載入已經在衍生表裡的日子：三條路線沒有重複列，輸出不變，不用重載。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `trip-reconstruction`：「Sub-route to route and direction mapping」補上 `GetRoute.gz` 裡六欄完全相同的重複列只算一條附屬路線，多一個情境。

## Impact

- 修改 `analysis/10_load.sql` 的 `routes`。
- 修改測試與 fixture：`spec/analysis/load_spec.rb`、`spec/analysis/fixtures_spec.rb`、`spec/fixtures/analysis/static/2026-10-19/GetRoute.gz`、`spec/fixtures/analysis/README.md`。
- 不改 `app/`、`lib/`、`db/`，不加 migration，不加依賴。
- 資料限制與假設：指標定義不變，限制照舊：車不等於人，折返停留是駕駛休息的上限；車上人數看下車刷卡率；10 秒輪詢會漏站；跨小時檔的重複在趟次重建前已以 `(BusID, DataTime)` 去除。這次多一條：`routes` 的去重只針對六欄完全相同的列，`providerId` 不在選到的欄位裡，所以聯營路線的兩家業者在 `routes` 看不出來，這跟現在一樣。
