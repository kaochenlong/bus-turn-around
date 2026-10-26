## Why

這個 change 服務三樣交付物的第一樣：路線健檢卡在網站上的路線頁。行駛時間那張卡現在只回答「一趟要跑多久」，看不出時間花在哪兩站之間。使用者 2026-10-26 要在行駛時間卡的表格下面加一張像 GitHub contribution graph 的格子圖，回答「哪一段開最慢」：橫軸是相鄰兩站之間，縱軸是沿線人數圖那四個時段，顏色越深代表車速越慢，不畫在地圖上。討論時使用者選了三件事：顏色代表車速（時速），不是「比平常多花幾秒」；一列一個時段，不是一列一個小時；格子要像 GitHub 那樣分幾級深淺。

需要的資料都已經在收，資料都來自臺北市公共運輸處的開放資料：

- **GPS**：n-gear 收的 `bus_data`（定時車機），現在只有 `analysis/turnaround_facilities.sql` 讀，用來找折返點。
- **路線軌跡**：衍生表 `route_day_shapes` 已經存了每個路線日每個方向的登記路線（取自當天靜態快照的 `GetBusShape.gz`）。
- **趟次**：從 `bus_event` 重建的趟次，用來知道每一筆 GPS 屬於哪一趟、哪個方向。

車速不能用到離站的時刻算。2026-10-26 拿中山幹線 2026-10-22 一整天的紀錄，找出前後 1 秒內有同一台車 GPS 點的到離站紀錄（進站 5,551 筆、離站 5,523 筆），量車在那一刻離站牌多遠（量到的）：

| 紀錄 | 車離站牌 p25／p50／p75／p90 | 當下 GPS 時速 p50 |
| --- | --- | --- |
| 進站 | 83／93／99／111 公尺 | 28 公里 |
| 離站 | 25／36／52／65 公尺 | 20 公里 |

進站紀錄出現時，車還在站前約 90 公尺、還在開；離站紀錄出現時，車已經開出去三十幾公尺。所以「這站離站到下一站進站」只涵蓋站距扣掉一百多公尺，段越短，拿站距去除算出來的車速越誇大。同一天去程士林電機到德行（沿線 225 公尺），白天 10 到 15 時用到離站時刻算是時速 43.7 公里，用 GPS 算是 10.6 公里。

GPS 的密度與路線軌跡都夠用：

- 同一台車相鄰兩個 GPS 點，相隔 p50 與 p90 都是 20 秒、p99 是 28 到 30 秒（2026-10-22 的 08 與 17 時，每小時約 2,400 台車，量到的）。
- 中山幹線每個站牌對到路線軌跡上，最遠偏 26 公尺（去程）與 13 公尺（返程）；兩個方向的軌跡長 16,320 與 16,821 公尺，合計跟 `GetRoute.gz` 登記的 `distance` 33.2 公里差不到 0.1 公里（2026-10-22 的快照，量到的）。

拿 GPS 試算 2026-10-22 的去程（一天、一個方向，量到的）：早尖峰最慢的是天母一帶，三玉宮到天母廣場、台北美國／日僑學校到賴厝都是時速 5.1 公里，白天也只有 6.9 公里；士林電機到德行白天 10.6、早尖峰 6.5，聯合醫院和平院區到大埔街是 13.1 與 7.6。整欄都深的是本來就慢的兩站之間，只有尖峰那一列深的是尖峰才變慢的，格子圖看得出這兩種差別。

## What Changes

- **站間車速**（新指標）：每一趟取那台車在趟次起點到終點之間的 GPS 回報，對到那個方向的路線軌跡上，離軌跡超過 50 公尺的不算。同一台車相鄰兩筆回報相隔 40 秒以內、往前走、每秒不超過 25 公尺，就算一組；一組的中點落在哪兩站之間就歸那裡，中點離這兩站任一站不到 40 公尺的不算。每趟在每個兩站之間加總公尺與秒數，時段看車開進這兩站之間的時刻。起點只有到站時刻的趟次不算，有成員路線的頁面只算頁面路線的趟次。門檻都寫在 `analysis/params.sql`。
- **站牌在路線軌跡上的位置**：每個方向的站牌照站序對到路線軌跡上，不會排在前一站後面；離軌跡超過 50 公尺的站牌沒有位置，兩站之間只在相鄰兩個有位置的站牌之間算。
- **GPS 改由共用的 `analysis/gps_reports.sql` 讀**：把 `gps_reports` 從 `analysis/turnaround_facilities.sql` 拆出來，留的車從「當天有折返停留的車」改成「當天有趟次的車」。折返點設施與 `bin/rails survey:end_natures` 的數字不變，兩邊都在 `turnaround_facilities.sql` 前面多跑它。
- **衍生表**：多一張 `trip_stop_speeds`，每趟每個兩站之間一列（第一站的站序、時段、公尺、秒數）；`route_day_stops` 多一欄 `shape_meters`。`derived:load` 在 `analysis/depots.sql` 之後、`analysis/derived_export.sql` 之前多跑 `analysis/stop_speeds.sql`；`derived_export.sql` 多寫 `stop_speeds.csv`，`stops.csv` 多一欄。
- **路線頁**：行駛時間卡的表格下面多一塊「哪一段開最慢？」。每個方向一張格子圖：一列一個時段（早尖峰、日間、晚尖峰、其餘），一格是兩站之間，深淺分四級、越深越慢，格子之間留縫；格子下面一條路線、每一站一個點，站名直書在點的下面（2026-10-26 看過第一版斜寫的畫面後，在 Design 畫布選的方案 B）；圖例是「快 ▪▪▪▪ 慢」加上每一級的時速範圍；樣本少於 5 趟或量不到的格子只畫外框。數字放在預設收起的表裡。640 px 以下一次看一個方向、一段一列、後面四個小方塊。圖由伺服器輸出成內嵌 SVG，不用圖表套件、不加提示框。
- **資料限制**多一條講站間車速；有成員路線的那一條補一句：站間車速只算頁面路線的車。
- **詞彙表**新增「站間車速」；`docs/decisions.md` 第 13 條補一筆：GPS 也拿來算站間車速，理由是上面那張到離站位置的表。

## Non-Goals

- 改行駛時間、折返停留、來回一趟、週期的定義。上面那張表也說明現在的行駛時間結束在末站前約 90 公尺、折返停留從那裡開始算，對這幾個數字有多少影響另開 change 量；`docs/decisions.md` 第 13 條「行駛時間與折返停留從到離站事件算」照舊。
- 畫在地圖上，或畫任何單一車牌的 GPS：03-route-shape-map 的非目標「畫任何 GPS」與 turnaround-map 的非目標「單一車牌的軌跡」照舊，這裡只出路線層級的彙總。
- 滑鼠移上去跳出數字：route-page-charts 的非目標「互動提示框、縮放、動畫，或任何 JS 圖表套件」照舊，數字在收起來的表裡。
- 用顏色或門檻判斷好壞，例如紅色、「低於幾公里算塞」的線：route-page-charts 起的非目標照舊，深淺只表示快慢的相對大小。
- 「比平常多花幾秒」、倍數、一小時一列：使用者 2026-10-26 選了車速與四個時段。
- 成員路線的趟次、站上停靠（上下客）的時間、跨路線或全路網的比較、健檢卡（`bin/health-card` 不讀 GPS）、月報。
- TDX 的站間旅行時間：02-route-307-page 的決定「TDX 站間旅行時間只做內部對照」照舊，頁面不用它的值。

## Capabilities

### New Capabilities

- `stop-to-stop-speed`: 站牌在路線軌跡上的位置、站間車速的算法（GPS 怎麼對到軌跡、哪些組不算、怎麼歸到兩站之間與時段）、路線頁的格子圖（深淺分級、圖例、樣本少、量不到、數字表、窄螢幕、沒有資料時的說明）。

### Modified Capabilities

- `derived-tables`: Derived export 改成由 `analysis/gps_reports.sql` 讀 GPS、多跑 `analysis/stop_speeds.sql`、照程式補上 `analysis/depots.sql` 與 `depots.csv`、多寫 `stop_speeds.csv`、`stops.csv` 多一欄；新增 Stop speed rows stored with the route day。
- `route-page`: Page content 在行駛時間之後多站間車速；Data limitations on the page 多一條；Data limitation of a page with member routes 補站間車速只算頁面路線的車。
- `end-nature-survey`: Routes surveyed 在 `analysis/turnaround_facilities.sql` 前面多跑 `analysis/gps_reports.sql`。

## Impact

- **前置與順序**：`spectra list` 沒有其他進行中的 change，不用等誰 archive。
- **新增**：analysis/gps_reports.sql、analysis/stop_speeds.sql、db/migrate 底下建 `trip_stop_speeds` 與加 `route_day_stops.shape_meters` 的 migration、app/models/trip_stop_speed.rb、app/models/route_page/stop_speeds.rb、app/components/stop_speed_grid_component.rb 與同層的 .html.erb、.yml、spec/analysis/stop_speeds_spec.rb、spec/models/route_page/stop_speeds_spec.rb、spec/components/stop_speed_grid_component_spec.rb。
- **修改**：analysis/turnaround_facilities.sql、analysis/params.sql、analysis/40_load_profile.sql（時段的判斷改用 params.sql 的 macro，健檢卡輸出不變）、analysis/derived_export.sql、analysis/README.md、app/models/route_day_loader.rb、app/models/end_nature_survey_command.rb、app/models/raw_day_check.rb（註解）、app/models/trip.rb、app/models/route_day_stop.rb、app/views/routes/show.html.erb、app/components/data_limitations_component.yml、db/schema.rb、spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl、spec/fixtures/analysis/README.md、spec/analysis/fixtures_spec.rb（GPS 點的對照多四個點）、spec/analysis/turnaround_facilities_spec.rb、spec/analysis/end_nature_evidence_spec.rb、spec/analysis/end_nature_export_spec.rb、spec/analysis/derived_export_spec.rb、spec/analysis/params_spec.rb、spec/models/route_day_loader_spec.rb、spec/models/end_nature_survey_command_spec.rb、spec/models/derived_push_command_spec.rb（衍生表清單多 `trip_stop_speeds`）、spec/requests/route_page_fixture_spec.rb、spec/requests/routes_spec.rb、spec/components/data_limitations_component_spec.rb、spec/system/route_page_mobile_spec.rb、docs/spectra/LANGUAGE.md、docs/decisions.md、docs/data-sources.md。
- **資料**：已經載入的路線日沒有站間車速，要重跑才有：開發資料庫重跑 `bin/rails derived:load`；正式站部署後，在 Mac mini 上跑 `bin/nightly-load --recompute`（使用者自己跑）。中山幹線一個路線日約 7,600 列（估計：每天每個方向約 85 趟 × 約 45 個兩站之間，驗收時量）；2026-10-26 量到平日 5,318 到 5,721 列，見 design 的 Risks。
- **執行期**：`derived:load` 多一次「GPS 對到路線軌跡」的計算，讀檔量不變（`bus_data` 本來就整個讀檔視窗讀進來）；每個路線日多花多久驗收時量；2026-10-26 量到中山幹線一天的分析多 0.4 秒以內，見 design 的 Risks。
- **回應大小**：路線頁多兩張 SVG、窄螢幕的列與數字表，估計 30 到 60 KB（未壓縮，驗收時量）；2026-10-26 量到中山幹線最近 7 天這一塊 235 KB 未壓縮、gzip 後 16 KB，估計低了四到六倍，見 design 的 Risks。
- **資料限制與假設**：車不等於人，站間車速是車開多快，不是駕駛開得好不好，也不拿來比車牌。不用車上人數，不牽涉刷卡率。到離站紀錄只用來切趟次與決定 GPS 屬於哪一趟，漏站不影響車速，但漏了起站離站、只剩到站的趟次整趟不算（中山幹線 2026-10-19 到 10-22 四個平日去程約三成，詞彙表「週期」量到的），所以去程的樣本比較少。跨小時檔的重複由 `gps_reports` 照 `(BusID, DataTime)` 去重。路線軌跡是登記的，臨時改道時離線超過 50 公尺的點不算。
