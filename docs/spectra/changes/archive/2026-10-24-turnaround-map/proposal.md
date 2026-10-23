## Why

這個 change 服務三樣交付物的第一樣：路線健檢卡在網站上的路線頁。turnaround-facilities 之後，路線頁的「折返點設施」那張卡能用數字說出折返點在哪裡、離末站幾公尺、300 與 500 公尺內有幾處公廁，但「車實際停在哪一塊、廁所在車的哪一邊、要過幾個路口」是空間問題，數字講不清楚，站長與司機要的是看一眼就懂。地圖從 zhongshan-first-health-card 起一路是非目標，turnaround-facilities 的 proposal 把它點名為「另開 change，讀這次存進衍生表的位置、公廁與靜止格」；使用者 2026-10-23 決定做，條件是它只讀衍生表、不碰原始檔、不變成專案的主角。

需要的資料，全部已經在衍生表裡或由 turnaround-facilities 寫進去，這個 change 不新增任何 DuckDB 階段、不讀原始檔：

- `route_day_ends`：每端每天的位置（停車端由靜止點算出、開過去就走那一端以末站計）、來源、三個查核數字、`n_standstill_records`、末站座標。
- `route_day_end_cells`：每端每天約 20 公尺的靜止格，只有 3 台車以上停過的格子，每格有靜止回報筆數、車數、折返停留筆數。
- `route_day_end_toilets`：有位置那一端 500 公尺內的公廁，含座標與公尺。
- `route_day_stops`：兩個方向的站牌座標，拿來畫末站與下一趟的起站（起站取另一個方向的起站，跟折返停留分佈圖的標題同一個取法）。
- 底圖：唯一的新外部來源。首選內政部國土測繪中心的臺灣通用電子地圖 WMTS 服務，不用金鑰；它的授權條款要在第一個任務查證，查到不是政府資料開放授權條款或只要求顯名的條款時，改用 OpenStreetMap 標準圖磚並照它的使用政策顯名。底圖只在瀏覽器裡載，伺服器不抓、不存。

## What Changes

- 「折返點設施」那張卡裡，每一端的那一段多一張地圖，放在文字之後：底圖上畫出那一端的靜止格（方塊，顏色深淺依這幾天合計的靜止回報筆數分四級）、位置（停車端）、末站與下一趟起站、500 公尺內的公廁，同一地址的廁所併成一處畫一個標記（名稱、類別、公尺、間數，跟設施那一段的清單同一套併法）。範圍以末站為中心、半徑 1 公里為上限，框住末站、下一趟起站、位置與格子；圖下方一行字寫「畫出來的格子涵蓋這幾天 N% 的靜止回報」，分母是 `route_day_ends.n_standstill_records` 在涵蓋日子的加總，所以被門檻丟掉的格子與框外的格子都算在沒涵蓋的那一份裡。
- 地圖的資料由伺服器算好、寫進回應：新的查詢物件 `RoutePage::EndMap` 讀涵蓋的日子，位置與公廁的處直接取 `RoutePage::Facilities` 的那一端（同一個「最近一個有位置的日子」與同一套併處），靜止格把涵蓋日子的筆數加總、記出現幾天，座標都是衍生表裡的值；回應裡沒有任何車牌欄位。每一端的資料是一段 `application/json`，元件測試讀得到數字。
- 地圖本身是第一個客戶端畫的區塊：新的 Alpine 元件 `endMap` 在那一端的容器至少四分之一進到畫面時，才按需載入一個含 Leaflet 的 chunk 畫圖，跟首頁插圖同一套做法；載入前、載不到、沒有 JavaScript 時，容器裡是一句話說地圖要等腳本或載不到，設施那一段的文字與數字一個都不少，頁面照舊是完整的。Turbo 快取前還原成伺服器輸出。設定減少動態效果時關掉縮放與淡入動畫。
- 新的 npm 相依 Leaflet（1.9 系列）。它用點陣圖磚、不需要 WebGL，沒有 WebGL 的瀏覽器也畫得出來；chunk 的預算是 brotli 壓縮後不超過 100 KB（估計：Leaflet 1.9.4 的 JS 壓縮後約 42 KB、CSS 約 4 KB，驗收時量），只有路線頁、而且只有地圖進到畫面時才載。
- 圖磚來源與顯名文字集中在一份設定 `config/map.yml`：正式與開發環境是查證後選定的服務，測試環境是一張內嵌的空白圖磚（data URI），測試不連網路。地圖右下角的顯名控制項、頁尾的顯名聲明（在環境部公廁那一行之後多一行，文字讀同一份設定）與 `docs/data-sources.md` 都加上底圖來源。
- 資料限制補一句：地圖上的格子是約 20 公尺一格、只畫 3 台車以上停過的格子、合計的是 GPS 每 10 秒一筆的靜止回報，不是停了多久，更不是休息；底圖是另一個機關的資料。

資料限制與假設，頁面上與 spec 裡都要寫明：

- 車不等於人：格子是車停的地方，不是駕駛去的地方；一格深不代表那裡有人休息。
- 車上人數與刷卡率跟這一塊無關，地圖不用任何票證推算的值。
- 漏站與漏 GPS：格子只來自成立的折返停留（本趟有到末站、下一趟從起站出發）的時間窗，GPS 每 10 秒一筆也可能整段沒有回報；涵蓋比例那一行就是為了讓人看到畫出來的佔多少。
- 跨小時重複：衍生表裡的靜止格在 turnaround-facilities 算的時候已經照 `(BusID, DataTime)` 去重，這裡只加總。
- 隱私：格子在匯出時已經丟掉少於 3 台車的，回應裡沒有車牌；地圖只畫路線層級的合計，不畫任何一台車的軌跡（`docs/use-cases.md` 第 11 項）。
- 底圖是外部服務：它的更新頻率、路名與建物不是本專案的資料，顯名照它的條款；服務不通時格子與標記仍然畫在空底上。

## Non-Goals

非目標，這個 change 不做：

- 全路網的地圖、首頁的地圖、調度站盤點的全市圖：那是場站清冊與設施 change 之後的事，資料也還不在衍生表裡。
- 單一車牌的軌跡、單一折返停留的 GPS 點、任何時間軸播放：`docs/use-cases.md` 第 11 項與路線頁「車牌只能從搜尋進入」的邊界照舊。
- 熱圖的平滑或模糊渲染：畫的是衍生表裡的格子本身，一格一個方塊，數字對得回 `route_day_end_cells`。
- 路線形狀（`GetBusShape`）、沿線站牌、捷運出入口上圖：這張圖只回答折返點附近的問題，沿線的事在載客那張卡。
- 改變折返點位置、靜止格、公廁距離的定義或衍生表：turnaround-facilities 的決定照舊，這裡只讀。
- 把地圖塞進健檢卡（Markdown）或月報。
- 在地圖上判定「夠不夠」或上色標示合規：跟捷運重疊與折返點設施的決定一致，只畫事實。
- 圖表套件：route-page-charts 的決定「圖由伺服器輸出成內嵌 SVG，不用圖表套件」對分佈圖、沿線人數圖、行駛時間橫條照舊，不因為加了地圖套件而改。
- 向量圖磚與 MapLibre GL：要 WebGL 與向量圖磚來源，體積與相依都大，點陣底圖就夠。
- 其他路線、排程與部署。

## Capabilities

### New Capabilities

- `turnaround-map`：每一端的地圖畫什麼、資料從哪幾天來、範圍與涵蓋比例的算法、伺服器回應裡的地圖資料形狀與不含車牌、按需載入與三種退路、底圖設定與顯名、效能預算與減少動態效果。

### Modified Capabilities

- `route-page`：頁面內容裡折返點設施的每一端多一張地圖與涵蓋比例那一行；沒有 JavaScript 時地圖的容器是一句話、其餘不變；資料限制多一句。以 turnaround-facilities 的 delta 為底（含來回與週期與折返點設施的現行文字）。
- `site-layout`：每一頁頁尾的顯名聲明在環境部公廁那一行之後，多一行底圖顯名，文字讀 `config/map.yml`。

## Impact

- 前置條件：turnaround-facilities 2026-10-24 已 apply 到 10/11，`route_day_ends`、`route_day_end_cells`、`route_day_end_toilets` 的 migration、model、查詢物件與元件都在；它的真資料驗收（三條路線重新 `derived:load`）與 archive 還沒做，所以這個 change 的 1.2 到 4.2 先用 fixture 做，三條路線的真資料核對都在 5.1。archive 的順序仍是 turnaround-facilities 先、這個 change 後。
- 新增 app/models/route_page/end_map.rb（查詢物件）、app/components/end_map_component.rb 與同層的 .html.erb、.yml；修改 app/components/turnaround_facilities_component.html.erb（每一端那一段的尾巴 render 地圖元件）、app/components/data_limitations_component.yml（加一句）、app/components/attribution_component.rb 與 .html.erb（底圖顯名一行，讀 `MapTiles.attribution`）、app/models/route_page/facilities.rb（`Place` 多帶最近那一間的經緯度，規則不動）。
- 新增 app/frontend/end_map/runtime.js（Leaflet 與畫圖，按需載入的 chunk）；修改 app/frontend/entrypoints/application.js（註冊 Alpine 元件 `endMap`）與 app/frontend/stylesheets/application.css（容器的三種狀態、方塊與標記的樣式）；package.json 與 yarn.lock 加 leaflet。
- 新增 config/map.yml（圖磚網址樣板、顯名文字、最大縮放；test 環境是 data URI 的空白圖磚）與讀它的 app/models/map_tiles.rb。
- 新增 spec/models/route_page/end_map_spec.rb、spec/components/end_map_component_spec.rb、spec/system/end_map_spec.rb（:js）；修改 spec/requests/routes_spec.rb 與 spec/requests/route_page_fixture_spec.rb（每一端有地圖容器與 JSON、沒有車牌、沒有 JavaScript 時容器是一句話）；新增 route_day_end_cell 的 factory。
- 修改 docs/data-sources.md（底圖來源、授權與顯名）、docs/spectra/LANGUAGE.md（「折返點設施」一條補地圖；「靜止格」補「地圖上畫的就是它」）。
- 執行期多兩張地圖的圖磚流量，只在捲到那一段時才載；每張圖約 12 到 20 張 256 px 的圖磚（估計，驗收時以瀏覽器的網路面板量一張圖的張數與 KB）。
