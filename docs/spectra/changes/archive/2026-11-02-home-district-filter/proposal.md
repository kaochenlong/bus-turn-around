## Why

這個 change 服務三樣交付物的第一樣路線健檢卡（路線頁與首頁的路線清單是它在網站上的形式）：首頁「有頁面的路線」加一個行政區下拉選單，站長、公運處或某一區的民代可以只看自己那一區的路線。需要的資料是靜態快照 `GetStop.gz` 裡每個站位（`stopLocationId`）的座標，與內政部國土測繪中心的「鄉鎮市區界線(TWD97經緯度)」（data.gov.tw/dataset/7441，政府資料開放授權條款第 1 版，跟現有資料同一種授權，下載檔是 TGOS 的 SHP 壓縮檔）；兩者對起來就知道每個站位在哪一區。衍生表與原始檔裡目前沒有任何行政區欄位（`GetStop.gz` 的 `address` 只有路名），所以要新增一份外部快照、每晚載入時算進衍生表。

為什麼現在：有頁面的路線從四條變七條（`daan-top-three-routes`），使用者 2026-11-02 要求加篩選；之後往全路網走，清單只會更長。2026-11-02 用 2026-10-22 快照算過七條路線的站位分佈（量到的）：中正區每一條都有站位（1% 到 27%），大安區有五條（5% 到 46%），所以「經過任一站位」篩不出東西，要用站位占比的門檻。

## What Changes

- 新的 rake task `bin/rails external:stop_districts`：下載區界檔、讀資料根目錄最新一份靜態快照的 `GetStop.gz`，用 DuckDB 的 spatial 延伸把每個站位判到哪一縣市、哪一鄉鎮市區，寫成快照 `external/stop-districts/<台北日>.csv`（`stop_location_id,county,town`）。spatial 延伸只有跑這個 task 的機器要裝；每晚載入、測試與 CI 都只讀 CSV。
- 每晚載入多一個必要的快照：資料根目錄要有至少一份站位行政區快照，缺了那一天失敗並指名這個 task（跟捷運出入口、公廁快照同一種規則）。新的 `analysis/stop_districts.sql` 用站位 Id 對快照：`route_day_stops` 多一欄 `district`（縣市加鄉鎮市區，對不到是空的）；新表 `route_day_districts` 存頁面路線每個路線日每一區的站位數、占比與是否達門檻；`route_days` 記下用了哪一天的快照。門檻 `district_min_share_percent`（10）寫在 `analysis/params.sql`。
- 首頁「有頁面的路線」標題那一列右側多一個「行政區」下拉選單，預設「全部」，只列至少有一條路線站位一成以上在那一區的區；臺北市的區不帶市名、其他縣市帶（新北市新莊區）。選了之後卡片照設定順序只留達門檻的路線，底下一行寫「士林區：1 條」；篩選在瀏覽器做，網址帶 `?district=士林區`，沒有 JavaScript 時七張全部顯示。卡片內容不變。涵蓋的最新一天還沒有行政區時（這個 change 之前載入的路線日），整頁都沒有就一句話取代選單，只有部分沒有就在那一行註明幾條。
- 頁尾顯名聲明多一行內政部國土測繪中心的資料集；`docs/data-sources.md`、`analysis/README.md` 補這份資料與這支 SQL；`docs/spectra/LANGUAGE.md` 新增「行政區」。
- 用真資料驗收：筆電跑一次 task 寫出快照，載入七條 2026-10-22，首頁選單列出的區與每一區的路線跟 2026-11-02 算出的分佈相同，數字記進 design。

## Non-Goals

非目標寫在 design。

## Capabilities

### New Capabilities

- `stop-districts`：站位行政區快照的 task、每個站位的行政區、每個路線日每一區的站位占比與門檻。

### Modified Capabilities

- `derived-tables`：「Day eligibility」多一個必要的快照；新增「Stop district rows stored with the route day」（`stops.csv` 多 `district`、新檔 `districts.csv`、新表 `route_day_districts`、`route_days` 記快照日）。
- `home-page`：「Home page content and order」的頁面專用 script 多一個路線清單的篩選；新增「Route list district filter」。
- `site-layout`：「Attribution footer on every page」多一行區界資料集的顯名。

## Impact

- 新增 `app/models/stop_districts_snapshot.rb`、`lib/tasks/external.rake` 的 task、`analysis/stop_district_snapshot.sql`（spatial，只有 task 跑）、`analysis/stop_districts.sql`（載入時的對照）、`app/models/route_day_district.rb`、`app/models/home_page/route_districts.rb`、`app/frontend/route_list/district_filter.js`，以及一個 migration（`route_day_stops.district`、`route_day_districts`、`route_days.stop_districts_day`）。
- 修改 `analysis/params.sql`、`analysis/derived_export.sql`、`app/models/route_day_loader.rb`、`app/models/home_page/route_list.rb`、`app/components/route_list_component.*`、`app/components/attribution_component.yml`、`app/frontend/entrypoints/application.js`、`Gemfile`（`rubyzip` 從間接相依改成明寫，解壓縮用）、`docs/data-sources.md`、`analysis/README.md`、`docs/spectra/LANGUAGE.md`。
- 測試與 fixture：`spec/fixtures/analysis/external/stop-districts/2026-10-19.csv`（fixture 路線 9001 的站位對到假的區）、一組小的 shapefile fixture 給 task 的測試、`spec/analysis/stop_districts_spec.rb`、`spec/models/stop_districts_snapshot_spec.rb`、`spec/models/route_day_loader_spec.rb`、`spec/analysis/derived_export_spec.rb`、`spec/components/route_list_component_spec.rb`、`spec/requests/pages_spec.rb`、`spec/system/home_district_filter_spec.rb`、Vitest 的 `app/frontend/route_list/district_filter.test.js`。spatial 延伸的 SQL 只在裝了延伸的機器上測，沒裝的機器那幾個例子標 pending 並印原因。
- `bin/push-derived` 靠外鍵找衍生表，`route_day_districts` 參照 `route_days` 就會自動帶上，不用改。
- 正式站：mini 的資料根目錄要先有這份快照（筆電跑 task 後複製，或在 mini 裝 spatial 延伸自己跑），否則合併後 `bin/nightly-load` 每個路線日都會失敗；既有的路線日要在 mini `--recompute` 一次才有行政區（七條十天約十分鐘，估的，照 2026-10-26 每個路線日 8.5 秒算）。
- 資料限制與假設：指標定義不變，限制照舊：車不等於人，折返停留是駕駛休息的上限；車上人數看下車刷卡率；10 秒輪詢會漏站；跨小時檔的重複已以 `(BusID, DataTime)` 去除。這次多的：站位屬於哪一區是用站牌座標對區界判的，站在區界上的站位只算一邊；占比用站位數算，不是里程；區界檔不定期更新，快照是下載那一天的版本；站位不在快照裡（新站）那一站沒有行政區，不算進占比的分子也不算分母以外的任何東西。
