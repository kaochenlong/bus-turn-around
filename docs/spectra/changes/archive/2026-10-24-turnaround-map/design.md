## Context

路線頁 `/routes/:route_id` 的每一塊是一個查詢物件（`app/models/route_page/`）配一個 ViewComponent，查詢物件拿 `RoutePage::Coverage#route_days` 回的那幾天讀衍生表；圖全部由伺服器輸出成內嵌 SVG（route-page-charts 的決定），前端只有 Turbo 與 Alpine，唯一按需載入的 chunk 是首頁插圖的 three.js（`Alpine.data("homeHero")`，狀態寫在 `data-hero`，`turbo:before-cache` 時還原成伺服器輸出，`turbo:before-render` 時 `Alpine.destroyTree`）。layout 用 Turbo 的 morph refresh；`config/initializers/content_security_policy.rb` 整份是註解，沒有生效的 CSP。

已核對的事實（2026-10-24）：

- turnaround-facilities 2026-10-24 已 apply 到 10/11（剩真資料驗收與 archive），加了三張衍生表：`route_day_ends`（每端每天一列：`go_back`、`end_seq`、`end_stop_name`、`end_latitude`、`end_longitude`、`location_source`、`latitude`、`longitude`、`n_layovers`、`n_located_layovers`、`n_standstill_records`、`end_stop_meters`；兩端不分性質都記 `n_standstill_records`）、`route_day_end_toilets`（500 公尺內逐處，含座標與 `meters`）、`route_day_end_cells`（每端每天的靜止格：`cell_latitude`、`cell_longitude` 是 0.0002 度格子的西南角、`n_records`、`n_buses`、`n_layovers`，少於 3 台車的格子匯出時已丟掉）。它的頁面元件 `TurnaroundFacilitiesComponent` 是 `[data-section=facilities]`，那張卡放在「來回與週期」之後、換休息試算之前，每一端一段 `[data-end="0"]`、`[data-end="1"]`，沒有列時整塊是 `[data-needs-reload]`；查詢物件 `RoutePage::Facilities` 每一端用涵蓋日子裡最近一個有位置的日子（`End#located_day`、`End#public_toilets_day`），並把那一天的公廁按地址併成處（`Facilities::Place`：名稱、類別、地址、公尺、間數）。頁尾顯名多了環境部公廁那一行。以上 2026-10-24 對照 `db/schema.rb`、`app/components/turnaround_facilities_component.html.erb` 與 `app/models/route_page/facilities.rb` 核對過。
- `route_day_stops` 已有兩個方向每站的座標；折返停留分佈圖的「下一趟起站」取另一個方向的起站（route-page-charts 的決定「圖的標題寫『末站 → 下一趟起站』，起站取另一個方向的起站」）。
- 前端沒有任何地圖套件；`package.json` 的相依只有 Turbo、Alpine 的轉接器、Alpine 與 three.js。`vite.config.mjs` 只有一個入口，動態 `import()` 會切出獨立的 chunk，首頁插圖就是這樣載的；`spec/support/vite.rb` 在跑 system spec 前 `yarn build`，system spec 的 headless Chrome 可以用 CDP 擋掉某個請求（`spec/system/home_hero_spec.rb` 的做法）。
- 頁尾顯名 `AttributionComponent` 一行一個來源；`docs/data-sources.md` 的「其他外部資料」表記每個外部來源的用途、來源與授權。
- 測試資料庫由 `RouteDayLoader` 寫入 fixture 日 2026-10-19（`spec/requests/route_page_fixture_spec.rb` 的做法）；turnaround-facilities 的 fixture 在戊站端只留一格靜止格（25.0604, 121.5002：25 筆、3 台車）、位置 25.060422, 121.500300、公廁三間兩處（戊站公園男女廁同一地址併成一處，另一處是戊站加油站）；甲站端沒有格子（E 只有一台車）、位置在 E、公廁兩間兩處。
- 使用者 2026-10-23 的決定：地圖做，但只讀衍生表、不是專案的主角；靜止格在匯出時就套 3 台車的門檻，頁面只加總留下的。

詞彙依 `docs/spectra/LANGUAGE.md`：折返點、末站、起站、折返停留、去返程、路線頁、衍生表、資料限制、顯名聲明；turnaround-facilities 會補「折返點位置」「靜止點」「靜止格」「折返點設施」。這個 change 不新增詞，只在「折返點設施」與「靜止格」兩條補「地圖畫的是什麼」。

## Goals / Non-Goals

**Goals:**

- 折返點設施那張卡裡，每一端有一張看一眼就懂的圖：車停在哪一塊、末站與下一趟起站在哪、位置在哪、500 公尺內的公廁在車的哪一邊。
- 圖上每個方塊與標記都對得回衍生表的一列，數字在伺服器回應裡，元件測試讀得到；沒有腳本時頁面照舊完整。
- 地圖套件只在路線頁、而且只在圖進到畫面時載，有預算、有量法。
- 底圖是外部服務，來源、授權與顯名寫在一處，測試不連網路。

**Non-Goals:**

- 全路網或首頁的地圖；單一車牌的軌跡或時間軸；熱圖的平滑渲染；路線形狀、沿線站牌、捷運出入口上圖。
- 改變 turnaround-facilities 的任何定義或衍生表；在地圖上判定夠不夠或上色標示合規。
- 圖表套件換掉既有的 SVG 圖；向量圖磚與 MapLibre GL；健檢卡與月報的地圖。

## Decisions

### 地圖放在折返點設施那張卡裡，每一端一張，接在那一端的文字之後

`TurnaroundFacilitiesComponent` 每一端那一段（`[data-end="0"]`、`[data-end="1"]`）的尾巴 render `EndMapComponent`：先是文字與數字（facilities 既有的），再是地圖容器，最後一行涵蓋比例。不另開區塊、不加區塊導覽的連結；整塊 `[data-needs-reload]` 時沒有任何地圖容器。

理由：02-route-page-mobile-first 的決定「區塊依指標分組：同一個指標的圖與表放進同一張卡」；地圖講的正是設施那一段講的那一端，拆開讀的人要上下對照。沒有列就沒有圖，跟捷運重疊「要重新載入」的提示同一種狀態。

替代方案：自己一張卡「折返點地圖」（同一個主題兩張卡，否決）；一張圖畫兩端（兩端相距整條路線，縮到看不出停車位，否決）。

### 資料由伺服器算好寫進回應，前端只畫；route-page-charts 的三個理由各有交代

新的查詢物件 `RoutePage::EndMap.new(route_days, ends:)` 讀涵蓋日子裡有 `route_day_ends` 列的那幾天，每一端算出一份資料：

- 位置與公廁：直接取 `RoutePage::Facilities` 的那一端：位置是它最近一個有位置的日子那一列，公廁是它併好的處（每處帶最近那一間的名稱、類別、公尺、經緯度與間數；`Facilities::Place` 為此多帶經緯度，turnaround-facilities 的 spec 本來就說一處的座標取最近那一間）；沒有位置的停車端 `location` 是空的、處也空。
- 末站：那一端最新一列的 `end_stop_name`、`end_latitude`、`end_longitude`。下一趟起站：最新一天 `route_day_stops` 裡另一個方向 `seq` 最小的站牌。
- 靜止格：涵蓋日子裡這一端所有 `route_day_end_cells` 依 `(cell_latitude, cell_longitude)` 合計 `n_records` 成 `records`，並數出現的天數 `days`；不加總 `n_buses`（不同天的車數不能相加），也不輸出它。
- 涵蓋比例：分子是畫出來的格子（範圍內的，見下一條）的 `records` 和，分母是這一端在這幾天 `n_standstill_records` 的和；分母 0 時比例是空的，頁面那一行寫沒有靜止回報。
- 回應裡沒有任何車牌欄位；資料是每一端一段 `<script type="application/json" data-end-map-data>`，形狀寫在 Implementation Contract。

route-page-charts 的決定「圖由伺服器輸出成內嵌 SVG，不用圖表套件」對分佈圖、沿線人數圖、行駛時間橫條照舊生效，這裡不推翻它；它的三個理由在這張圖上各有交代：新增 npm 相依只有 Leaflet 一個，而且只在路線頁按需載；數字不是只在 JS 裡，而是在伺服器回應的 JSON 與涵蓋比例那一行，元件測試用 Nokogiri 讀；頁面不用等 JS 才有東西，設施那一段的文字就是沒有腳本時的內容，地圖是加在上面的。

理由：zhongshan-route-page 的決定「衍生表存逐趟資料，彙總在讀頁面時用 SQL 算」，格子跨天的合計與涵蓋比例是讀頁面時算的彙總；JSON 放在回應裡，是讓同一份數字同時餵給測試與前端。

替代方案：前端打一個 JSON 端點（多一條路由、多一次請求，數字離開 HTML 之後元件測試看不到，否決）；伺服器畫成靜態圖片（沒有底圖的靜態圖看不出「哪裡」，要底圖就得伺服器抓圖磚，否決）。

### 用 Leaflet 的點陣底圖，Alpine 元件按需載入，三種狀態

npm 加 `leaflet`（1.9 系列，apply 時取 1.9 最新版並記在 design 的 Risks）。`app/frontend/end_map/runtime.js` 匯出 `draw(container)`：讀容器裡的 JSON 與 `data-tile-url`、`data-tile-attribution`、`data-max-zoom`，建地圖、畫格子與標記、回傳 `{ dispose() }`。`app/frontend/entrypoints/application.js` 註冊 `Alpine.data("endMap", …)`，容器帶 `x-data="endMap"` 與 `data-map="pending"`：

1. `init()` 掛 `turbo:before-cache`（還原 `data-map="pending"`、`dispose()`），用 `IntersectionObserver`（`threshold: 0.25`）等容器至少四分之一進到畫面。
2. 進到畫面：`data-map="loading"`，`await import("../end_map/runtime.js")`，成功且容器仍在文件裡就 `draw()`、`data-map="ready"`；失敗就 `data-map="static"` 並 `reportError`。
3. `destroy()` 斷開 observer、`dispose()`。

CSS：`[data-map]` 不是 `ready` 時顯示容器裡那一句 `[data-map-note]`（地圖要等網頁腳本載入，或載不到；數字都在上面），畫布 `[data-map-canvas]` 的盒子一直保留高度（手機 240 px、640 px 以上 288 px），避免載入時跳版。設定減少動態效果（`prefers-reduced-motion: reduce`）時 Leaflet 的 `zoomAnimation`、`fadeAnimation`、`markerZoomAnimation` 都關掉，容器加 `data-animations="off"`。容器 `aria-hidden="true"`：那一端的每個數字都已經在上面的文字裡，地圖對輔助科技是重複的圖像，不另給 aria-label。

理由：Leaflet 用點陣圖磚、不需要 WebGL，沒有 WebGL 的瀏覽器（首頁插圖退回靜態圖的那種）也畫得出來；體積約 42 KB（brotli，估計，驗收時量）；畫方塊與標記的 API 直接，沒有自己的狀態管理。按需載入照 home-page 的決定「插圖動畫用 Alpine 元件按需載入，Turbo 快取前還原成伺服器輸出」，三種狀態照 home-hero-turnaround-loop 的 `pending`、`loading`、`static`，少了 `playing` 與 `paused`，多了 `ready`。

替代方案：MapLibre GL（要 WebGL 與向量圖磚來源，chunk 是 Leaflet 的五六倍，否決）；不用套件、自己用 `<img>` 拼圖磚加 SVG 疊層（重造套件的投影、拖曳與縮放，否決）；一進頁面就載（兩張圖的圖磚在使用者還沒捲到之前就下載，否決）。

### 底圖來源、顯名與縮放上限集中在 config/map.yml，測試用內嵌的空白圖磚

`config/map.yml` 的 `shared.tiles` 有 `url`（圖磚網址樣板，含 `{z}`、`{x}`、`{y}`）、`attribution`（顯名文字）、`max_zoom`；`test.tiles.url` 是一張 1×1 透明 PNG 的 data URI，`attribution` 寫「測試用空白底圖」，所以測試不連網路、Leaflet 照樣建圖層。`MapTiles.url`、`.attribution`、`.max_zoom` 讀它（做法照 `RoutePage::Ends.from_config` 讀 `config/route_page.yml`），缺鍵時丟出指出鍵名的錯誤。`EndMapComponent` 把三個值寫成容器的 `data-tile-url`、`data-tile-attribution`、`data-max-zoom`，runtime 不寫死任何網址。

正式與開發環境的來源在任務 1.1 查證後定：首選內政部國土測繪中心「臺灣通用電子地圖」WMTS（EMAP，GoogleMapsCompatible 的 `{z}/{y}/{x}`），因為是政府開放資料、不用金鑰、台北市區路名完整；查到它的條款是政府資料開放授權條款或只要求顯名，就用它，顯名文字照條款；查到不是，改用 OpenStreetMap 標準圖磚，顯名「© OpenStreetMap contributors」並遵守它的圖磚使用政策。查證結果與條款連結寫進 `docs/data-sources.md` 與這份 design 的 Risks。頁尾 `AttributionComponent` 在 turnaround-facilities 加的環境部公廁那一行之後，多一行底圖顯名，文字就是 `MapTiles.attribution`，跟地圖右下角的顯名控制項同一段；`site-layout` 的「Attribution footer on every page」跟著改。測試環境的頁尾因此寫「測試用空白底圖」。

理由：來源可能換（條款變、服務停），換時只改一份 yml；測試用 data URI 是最無聊的離線做法，不用假伺服器。

替代方案：商業圖磚服務（要金鑰，金鑰得進部署設定，否決）；自己架圖磚（維運成本，否決）；條款在 apply 時才查（變成 design 的假設沒人驗，否決，所以是第一個任務）。

### 畫法：0.0002 度的方塊、四級深淺照佔最大格的比例、範圍以末站為中心 1 公里為上限、涵蓋比例一行

- 格子：每格畫成以 `(cell_latitude, cell_longitude)` 為西南角、邊長 `cellDegrees`（0.0002 度，`RoutePage::EndMap::CELL_DEGREES`，跟 `analysis/params.sql` 的 `standstill_cell_degrees` 同一個值，有測試鎖住）的矩形。深淺分四級，依該格 `records` 佔這一端畫出來的格子裡最大 `records` 的比例：不超過 0.25 是第 1 級，不超過 0.5 第 2 級，不超過 0.75 第 3 級，其餘第 4 級；每個矩形帶 class `end-map-cell end-map-cell-<級>`。圖角落一個四格的圖例寫「少 → 多」。
- 標記：末站（`end-map-stop end-map-stop-last`）、下一趟起站（`end-map-stop end-map-stop-next`）、位置（`end-map-location`，只在 `source` 是 `standstill` 時畫，開過去就走那一端的位置就是末站）、公廁（`end-map-toilet`，一處一個，放在那一處最近那一間的座標，滑鼠或點按顯示名稱、類別、公尺與間數）。都是 Leaflet 的 `divIcon`，樣式在 `application.css`。
- 範圍：取末站、下一趟起站、位置與格子的外框，但只收離末站 1 公里內的東西（`extentMeters: 1000`，由伺服器算好只送範圍內的格子，`cellsBeyondExtent` 記被排除的格數），外框加一點邊距，縮放不超過 `max_zoom`、不低於 15。
- 涵蓋比例那一行在容器下方、不在 `aria-hidden` 裡：「畫出來的格子涵蓋這幾天 N% 的靜止回報」，`[data-value=coverage-share]`，N 四捨五入到整數；分母 0 時寫「這幾天沒有靜止回報」；有被範圍排除的格子時補一句「另有 M 格在 1 公里外」。

理由：格子本身就是衍生表的一列，畫方塊才對得回數字；分級用佔最大格的比例，是讓每一端自己可讀，不同路線的筆數差好幾倍，固定門檻會讓少車的路線整張圖都是淺色。1 公里是回場 3 公里外那團不會把圖拉到看不見停車位的上限，排除的格數寫出來，不悄悄消失。涵蓋比例的分母用 `n_standstill_records`，被門檻丟掉的與框外的格子都算進沒涵蓋的那一份，讀的人知道圖畫出了幾成。

替代方案：熱圖外掛的模糊渲染（數字對不回表，否決）；固定筆數門檻分級（跨路線不可讀，否決）；範圍固定縮放等級（停車位離末站 300 公尺與 30 公尺的路線不能用同一個縮放，否決）。

### 公廁標記一處一個

地圖上的公廁標記跟設施那一段的清單同一套併法：同一地址的廁所是一處，畫一個標記，放在那一處最近那一間的座標，提示寫最近那一間的名稱、類別、公尺與這一處有幾間。資料直接取 `RoutePage::Facilities` 併好的處，JSON 的鍵是 `places`。

Supersedes：原本的「`toilets` 照公尺排，每一間一個標記」（Implementation Contract 的 `toilets` 與 JSON 的 `toilets`），2026-10-24 由這條取代。

理由：全國公廁建檔資料一列是一間，同一棟樓的男廁、女廁、無障礙廁所座標幾乎相同；職能發展學院二 300 公尺內是 2 處 33 間（2026-10-24 用末站座標量到的），一間一個標記會疊成兩團。fixture 的戊站端存三間、兩處，原本 scenario 寫的「兩個公廁標記」也是處。

替代方案：一間一個標記（標記疊在一起，提示只看得到最上面那一間，使用者 2026-10-24 否決）。

### 效能預算：地圖 chunk brotli 後不超過 100 KB，圖磚只在進到畫面後載，兩張圖各量一次

- chunk：`yarn build` 之後對 `public/vite/assets/` 裡 runtime 那個 chunk（含 Leaflet 與它的 CSS）跑 `brotli -q 11` 與 `gzip -9`，brotli 後不超過 100 KB（估計值，依據是 Leaflet 1.9.4 發行檔 JS 約 42 KB、CSS 約 4 KB 的壓縮後大小；驗收量到的數字寫回 Risks）。
- 圖磚：每張圖初次畫出時的圖磚張數與 KB，用 headless Chrome 的 performance entries 量（做法照 `spec/system/home_hero_spec.rb` 的 `requested?`），寫回 Risks；沒有門檻，但超過 30 張就要看範圍是不是算錯。
- 首頁與其他頁面不請求這個 chunk；路線頁在地圖容器進到畫面之前不請求。

理由：跟 home-page「執行期效能預算」同一套量法與寫法，預算是估計、由任務實測確認。

替代方案：不設預算（第一個客戶端畫的區塊沒有基準，否決）。

### 只讀 turnaround-facilities 的表，archive 順序是 facilities → map

這個 change 不改 `analysis/`、不改衍生表、不改 `RoutePage::Facilities` 的規則，只新增讀表的查詢物件與元件；`Facilities::Place` 多帶最近那一間的經緯度，是把它本來就該有的座標交出來。`route-page` 的 delta spec 以 turnaround-facilities 的 delta 版本為底修改（Page content 與 Data limitations on the page 兩條，2026-10-24 改以那天 ingest 後、含來回與週期的版本為底），`site-layout` 的 delta 以 turnaround-facilities 加了公廁那一行的版本為底，所以 archive 的順序必須是 turnaround-facilities 先、turnaround-map 後；apply 之前先跑 `/spectra-drift turnaround-map`，核對落地的表名、欄位、元件標記與這裡一致。

理由：兩個 change 都改同一條 requirement，後 archive 的版本是最後的版本；寫在前一個版本上才不會把它的字吃掉。

替代方案：把地圖併進 turnaround-facilities（那個 change 已經九個大任務，而且地圖的相依與測試方式完全不同，否決）。

## Implementation Contract

**行為**：

- 開 `/routes/15373?day=2026-10-22` 捲到「折返點設施」：每一端的文字之後有一個地圖容器，捲到它至少四分之一在畫面裡時載入地圖 chunk、畫出底圖、格子、末站、下一趟起站、停車端的位置與公廁；圖下方一行寫畫出來的格子涵蓋這幾天幾成的靜止回報。沒有腳本或 chunk 載不到時，容器裡是一句話，設施那一段的文字與數字照舊。
- 整塊是 `[data-needs-reload]` 時沒有地圖容器；一端沒有格子時仍畫底圖、末站、下一趟起站、位置與公廁，涵蓋比例那一行寫 0%（分母大於 0 時）或「這幾天沒有靜止回報」。
- 首頁與路線頁以外的頁面不請求地圖的 chunk；路線頁在容器進到畫面之前不請求。
- 頁尾顯名多一行底圖來源；地圖右下角顯示同一段顯名。

**介面與資料形狀**：

- `RoutePage::EndMap.new(route_days, ends:)`：`CELL_DEGREES = 0.0002`、`EXTENT_METERS = 1000`、`MIN_ZOOM = 15`、`LEVELS = 4`；`#available?`（涵蓋的日子有任何 `route_day_ends` 列）；`#ends` 回每個方向一個值物件 `End`：`go_back`、`nature`、`last_stop`（`name`、`lat`、`lon`）、`next_first_stop`（同形，取不到時 nil）、`location`（`lat`、`lon`、`source`、`day`，或 nil）、`places`（取自 `RoutePage::Facilities` 那一端：`name`、`category`、`meters`、`toilets`、`lat`、`lon`，照公尺再名稱排）、`cells`（範圍內的，每格 `lat`、`lon`、`records`、`days`、`level`，照 `lat`、`lon` 排）、`cells_beyond_extent`、`records_shown`、`records_total`、`coverage_share`（0 到 1 的小數，分母 0 時 nil）。不選任何車牌欄位。
- `EndMapComponent.new(end:, tiles: MapTiles)`：輸出
  - `div[data-end-map][data-map="pending"][x-data="endMap"][aria-hidden="true"][data-tile-url][data-tile-attribution][data-max-zoom][data-end="<go_back>"]`，裡面依序是 `script[type="application/json"][data-end-map-data]`、`p[data-map-note]`、`div[data-map-canvas]`；
  - 容器之後 `p[data-map-coverage]`，內含 `span[data-value=coverage-share]`（百分比整數或空）與有排除格子時的 `span[data-value=cells-beyond-extent]`。
  - JSON 的鍵：`goBack`、`nature`、`lastStop`、`nextFirstStop`、`location`、`places`（每處 `name`、`category`、`meters`、`toilets`、`lat`、`lon`）、`cells`、`cellsBeyondExtent`、`cellDegrees`、`extentMeters`、`minZoom`、`coverage`（`recordsShown`、`recordsTotal`、`share`）；鍵名 camelCase，座標是數字、不是字串。
- `app/frontend/end_map/runtime.js` 匯出 `draw(container)` 回 `{ dispose() }`；畫出的元素帶 class `end-map-cell end-map-cell-1..4`、`end-map-stop-last`、`end-map-stop-next`、`end-map-location`、`end-map-toilet`、圖例 `end-map-legend`；減少動態效果時容器加 `data-animations="off"`。
- `Alpine.data("endMap")`：狀態 `pending → loading → ready | static`，`turbo:before-cache` 還原成 `pending`，`destroy()` 釋放。
- `config/map.yml`：`shared.tiles.url`、`shared.tiles.attribution`、`shared.tiles.max_zoom`；`test.tiles.url` 是 data URI；`MapTiles.url`、`.attribution`、`.max_zoom`。
- `AttributionComponent` 在環境部公廁那一行之後多一行底圖顯名，文字讀 `MapTiles.attribution`；`DataLimitationsComponent` 的 `items` 多一句。

**失敗模式**：

- chunk 載不到、Leaflet 丟例外：`data-map="static"`，那一句話顯示，`reportError`；頁面其他部分不受影響。
- 圖磚服務不通：Leaflet 的圖層空白，格子與標記照畫；不另外偵測。
- `config/map.yml` 缺鍵：`MapTiles` 在讀的時候丟出指出鍵名的錯誤，路線頁 500，測試會抓到。
- 涵蓋的日子沒有 end rows：不 render 任何地圖容器（facilities 已顯示要重新載入）。

**驗收**：

- `bundle exec rspec` 全綠，含：`spec/models/route_page/end_map_spec.rb`（格子跨天合計、天數、涵蓋比例、1 公里排除、位置取最近有位置的日子、下一趟起站取另一方向的起站、分級邊界）、`spec/models/map_tiles_spec.rb`（test 環境是 data URI、缺鍵丟錯）、`spec/models/route_page/end_map_consistency_spec.rb`（`CELL_DEGREES` 等於 `analysis/params.sql` 的 `standstill_cell_degrees`）、`spec/components/end_map_component_spec.rb`（JSON 形狀、data 屬性、沒有車牌、涵蓋比例的文字）、`spec/requests/routes_spec.rb` 與 `spec/requests/route_page_fixture_spec.rb`（每一端有容器與 JSON、沒有腳本時 `data-map="pending"` 且那一句在、沒有車牌、整塊要重新載入時沒有容器、Bullet 不報 N+1）、`spec/system/end_map_spec.rb`（:js：兩個容器捲到之後變 `ready`、戊站端一個 `.end-map-cell-4`、甲站端 0 個格子但有末站與公廁標記、顯名文字、擋掉 chunk 時 `static`、首頁不請求 chunk、減少動態效果時 `data-animations="off"`）。
- 預算：chunk brotli 後不超過 100 KB；兩張圖的圖磚張數與 KB 寫回 Risks。
- 真資料：三條路線 `?day=2026-10-22` 的頁面在 1280 px 與 390 px 寬各看一次，停車端的格子落在人工查證過的停車處、開過去就走那一端的格子少或沒有、公廁標記對得上清單；每條路線每一端的涵蓋比例寫回 Risks。
- `bin/rubocop` 與 `bin/brakeman` 對新增與修改的檔案沒有 offense 與警告。

**範圍邊界**：在範圍內的是查詢物件、JSON 與元件、Alpine 元件與 runtime chunk、Leaflet 相依、`config/map.yml` 與 `MapTiles`、顯名與資料限制的文字、文件、測試、預算量測。不在範圍內：任何 `analysis/` 或衍生表的改動、`RoutePage::Facilities` 的規則、區塊導覽、首頁、全路網地圖、路線形狀、健檢卡、其他路線、排程與部署。

## Risks / Trade-offs

- [底圖條款查證結果不是預期] → 任務 1.1 有決定規則（國土測繪中心不行就 OpenStreetMap），兩個來源都只要改 `config/map.yml` 與顯名文字。
- [底圖條款查證，2026-10-24 做的] → 國土測繪中心臺灣通用電子地圖的開放資料版（data.gov.tw/dataset/25108，圖層 EMAP6，`https://wmts.nlsc.gov.tw/wmts/EMAP6/default/GoogleMapsCompatible/{z}/{y}/{x}`）是政府資料開放授權條款第 1 版，但資料集頁寫明只到圖磚第 15 等級；同一個網址 16 到 18 級也回圖磚（量到的），那部分適用國土測繪圖資服務雲的使用條款（maps.nlsc.gov.tw/pro/use_clause.jsp：附上來源、不得大量下載、不可移轉、只能用在宣傳或表示使用該系統的服務、可隨時限量或改收費），不是只要求顯名；zoom 15 的圖磚放大到 17 看不清街道與店名（同一點比對過）。使用者 2026-10-24 選 OpenStreetMap 標準圖磚 `https://tile.openstreetmap.org/{z}/{x}/{y}.png`，顯名「© OpenStreetMap contributors」，照 OSMF 圖磚使用政策（只載看得到的圖磚、不大量下載、不離線、用量大時可能被擋），`max_zoom` 18；網址、顯名與最大縮放寫在 `config/map.yml`，來源與條款連結寫在 `docs/data-sources.md`。
- [Leaflet 的 chunk 超過 100 KB brotli] → 預算是估計，超過就停下回報，不自己放寬；先查 CSS 與圖示是不是被打進去兩次。2026-10-24 任務 4.2 量到的（Leaflet 1.9.4，`yarn build` 之後）：地圖的 JS chunk（`public/vite/assets/runtime-*.js`，manifest 裡 `app/frontend/end_map/runtime.js` 那一個）原始 151,464 bytes，`brotli -q 11` 後 38,288 bytes，`gzip -9` 後 43,813 bytes；跟著它載入的 CSS（Leaflet 的 CSS，含它內嵌成 data URI 的三張小圖，這張圖用不到）原始 15,095 bytes，brotli 後 5,667 bytes，gzip 後 6,391 bytes；兩個加起來 brotli 後 43,955 bytes，在 100 KB 以內。Leaflet 只出現在這個 chunk，application 的 chunk 與首頁插圖的 chunk 裡都沒有。
- [同一個停車位被 0.0002 度的格線切成兩格，顏色各自變淺] → 格子是衍生表的事實，圖例寫「少 → 多」不寫數字；真資料驗收時對照人工查證的停車處，太碎再回 turnaround-facilities 談格子大小。
- [兩張圖的圖磚流量在手機上可觀] → 只在捲到時載，驗收量張數與 KB 寫在這裡；太多就先降 `max_zoom`。
- [turnaround-facilities 落地時表名、欄位或元件標記跟這裡寫的不同] → apply 前跑 `/spectra-drift turnaround-map`，不一致先 ingest 再開工。2026-10-24 核對出三處不一致，同一天 ingest 修正：route-page delta 改以 facilities 的現行 delta 為底、頁尾底圖顯名補 site-layout delta、公廁標記改成一處一個。
- [`aria-hidden` 的地圖對只用鍵盤的人不可操作] → 數字都在上面的文字裡；地圖是輔助，不是唯一的入口。
- [減少動態效果的使用者仍會看到圖磚淡入以外的位移] → 三個動畫選項都關，剩下的是瀏覽器自己的行為。

## Migration Plan

- 沒有 migration。`yarn install` 之後 `yarn build`；部署時照常。
- 回退：拿掉 `EndMapComponent` 的 render 與 Alpine 元件，頁面回到 turnaround-facilities 的樣子；相依移除即可。

## Open Questions

- 國土測繪中心 WMTS 的使用條款與顯名文字，任務 1.1 查；查完寫進 `docs/data-sources.md` 與這裡。2026-10-24 在任務 1.2 查完，結論見 Risks 的「底圖條款查證」：改用 OpenStreetMap。
