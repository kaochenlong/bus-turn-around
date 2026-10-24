## Context

路線頁 `/routes/:route_id` 由查詢物件（`app/models/route_page/`）配 ViewComponent 組成，查詢物件拿 `RoutePage::Coverage#route_days` 回的那幾天讀衍生表；Rails 只讀衍生表，不碰原始檔。衍生表由 `bin/rails derived:load`（`RouteDayLoader`）寫入：DuckDB 先跑 `analysis/params.sql` 與編號的階段檔，再接 `mrt_overlap.sql`、`turnaround_facilities.sql`、`derived_export.sql`，寫出 CSV，然後在一個交易裡替換一條路線一天。

這個 change 建在四個 change 上：

- **turnaround-facilities**（2026-10-24 已 archive）：`derived-tables` 的 Derived export 與 Replace one route day atomically 以它的版本為底（八個檔、`route_day_ends` 等三張表）。
- **turnaround-map**（2026-10-24 已 archive）：Leaflet 1.9、`config/map.yml` 與 `MapTiles`、`Alpine.data("endMap")`、`app/frontend/end_map/runtime.js`、`[data-map]` 的四種狀態與它的 CSS、Map budget。`route-page` 的 Data limitations on the page 以它的版本為底。
- **01-bus-feeds-attribution**（2026-10-24 apply 到 2/3，剩提醒這個 change 跟上的任務）：公運處顯名聲明的第一行點名衍生表與健檢卡讀的每一支公運處 feed，`docs/data-sources.md` 授權那一節的引文、頁尾（`attribution_component.yml` 的 `statement`）與 `bin/health-card` 的 `ATTRIBUTION` 三處一字不差；授權那一節有一張資料集表（feed、資料集頁面、頁面列的 JSON、查證日期）。三個測試綁住它：`spec/analysis/attribution_spec.rb` 掃 `analysis/*.sql`、`app/**/*.rb`、`lib/**/*.rb`、`bin/*` 裡以 `Get` 開頭、`.gz` 結尾的檔名，沒被第一行點名就失敗；`spec/requests/site_layout_spec.rb` 比對頁尾與文件；`spec/analysis/card_spec.rb` 比對健檢卡與文件。`site-layout` 的 Attribution footer on every page 以它的版本為底。
- **02-route-stop-sequence**（暫存，0/11）：站序卡 `CardComponent.new(id: "stops")` 包住 `StopSequenceComponent.new(stop_sequence:, ends:)`，放在區塊導覽之後、折返停留之前；`section[data-section="stop-sequence"]` 裡是小標、`h2` 標題、預設收起的 `details[data-stop-sequence]`。`route-page` 的 Stop sequence block 是它新增的，這裡以它為底修改。

已核對的事實（2026-10-24）：

- `GetBusShape.gz` 是靜態快照的一支，n-gear 每天抓（`../gems/n-gear` 的 `Feeds`，`bus_shape`，官方名稱「公車路線軌跡」）。最外層是 JSON 陣列，不是其他三支的 `{"BusInfo": [...]}`；每列有 `UniRouteId`、`RouteID`、`SubRouteID`、`GoBack`、`utime`、`wkt`。2026-10-24 的快照有 1028 列、406 條路線；804 列的 `SubRouteID` 是 -1，其他 224 列分屬 62 條路線的特殊附屬路線（例如 10723 的 160559「1狗狗公車」）。
- `RouteID` 對的是路線 `Id`：15373、10712、11764、16111、19108、10482 各有 `SubRouteID` -1 的兩列（`GoBack` 0、1）；中山幹線的附屬路線 162347、162348 沒有自己的列。`wkt` 是 `LINESTRING (經度 緯度, 經度 緯度, …)`，座標之間是逗號加空格。三條有路線頁的路線每個方向 205 到 266 點。
- 軌跡會舊、快照會缺：251區 的 `utime` 是 2023-12-29、251 是 2026-07-30、中山幹線是 2024-11-29；10-19 到 10-24 六份快照裡 251區 的 `wkt` 完全一樣；10-23 那份整份只有 989 列（平常 1028）。
- 跟 GPS 的吻合度見 proposal 的表（2026-10-22 一天、三條路線，量到的）。
- `bin/health-card` 只檢查 `GetRoute.gz`、`GetStop.gz`、`GetPathDetail.gz` 三支靜態檔（`STATIC_FILES`），不讀 `GetBusShape.gz`；它的「資料來源與授權」一節是 `ATTRIBUTION`，照 health-card 的 Limitations and attribution text 逐字收錄 `docs/data-sources.md` 授權那一節的三段聲明。
- data.gov.tw 有「臺北市公車路線軌跡」（data.gov.tw/dataset/160167，2026-10-24 查到）：提供機關是臺北市公共運輸處，授權是政府資料開放授權條款第 1 版，頁面列的 JSON 是 `TstBusShape.json`，資料集說明指向公運處的「臺北市 Data.Taipei 平台 API 說明文件」。V6.3 的 API 總表第 19 項是 BusShape 公車路線軌跡 `GetBusShape.gz`（靜態），名稱跟 n-gear 的 `title_zh` 一致。
- `spec/analysis/derived_export_spec.rb` 逐一列出八個 CSV 的欄位名，並斷言連跑兩次八個檔位元組相同。
- `RouteDay` 的子表都是 `route_day_id` 外鍵 `on_delete: :cascade`、`has_many …, dependent: nil`，並以 `(route_day_id, go_back)` 建唯一索引（例如 `route_day_ends`）。
- 測試的 fixture 路線 9001：去程 甲站 (25.05, 121.5) 到 戊站 (25.06, 121.5)，返程 戊站對面 (25.06, 121.5003) 到 甲站 (25.05, 121.5003)，各 5 站（`spec/fixtures/analysis/static/2026-10-19/GetStop.gz`）。
- `RoutePage::LayoverStats` 等四個查詢物件在 7 天範圍用 `order(day: :desc).pick` 會取到最早那一天（已知問題，未修）；02-route-stop-sequence 的決定「站序取涵蓋日子裡最新一天，用 reorder 取」避開了它。

詞彙照 `docs/spectra/LANGUAGE.md`：路線、去返程、起站、末站、站牌、衍生表、原始檔、靜態快照、路線頁、資料限制、顯名聲明；新增「路線軌跡」。

## Goals / Non-Goals

**Goals:**

- 不熟這條線的讀者在站序卡上一眼看出車走哪些路，起站、末站在哪裡。
- 路線軌跡跟其他衍生資料一樣，每晚跟著路線日進衍生表，記得取自哪一天的快照、公運處哪一天更新。
- 缺檔、缺列、壞資料都不擋住那一天的其他數字，而且會說出來。
- 兩張地圖共用同一套載入流程與 Leaflet 設定，預算重新量。

**Non-Goals:**

- 畫 GPS、報 GPS 與路線軌跡的吻合度、畫沿線每一站或捷運與人數、畫別條路線、用軌跡算捷運重疊、附屬路線各自的軌跡與 307、265區 的特殊情形、GetRoute 等三支的顯名與聲明的測試（01-bus-feeds-attribution 做）。理由寫在 proposal 的 Non-Goals。

## Decisions

### 路線圖放在站序卡的清單上方，一直看得到

`StopSequenceComponent` 在 `h2` 標題之後、`details[data-stop-sequence]` 之前，輸出它的 `content`（ViewComponent 由呼叫端傳進來的區塊）；`show.html.erb` 把 `RouteMapComponent.new(route_shape: RoutePage::RouteShape.new(route_days))` 當成這個區塊傳進去。站序元件不認識路線軌跡，只留一個位置。

理由：使用者 2026-10-24 選的。02-route-stop-sequence 的站序卡回答「這條路線停哪些站、在哪裡折返？」，目的是「先看懂路線怎麼跑，再看數字」，跟這張圖同一件事，所以併進同一張卡，不另開一張。地圖是固定高度的盒子（手機 240 px、640 px 以上 288 px，跟端點地圖同一組），沒有 02-route-stop-sequence 收起清單的理由（251 一個方向 55 站，展開會把折返停留推到很下面）。用 `content` 而不是多一個參數，站序元件的測試不用知道路線軌跡。

替代方案：收在展開的清單裡（只有點開才載，最省；但這張圖是給不熟這條線的人看的，要先想到點開才看得到，使用者否決）；自己一張卡放在站序卡旁邊（兩張認路的卡，而且一樣要改 Page content，沒有比較獨立，否決）；把地圖併進 02-route-stop-sequence 本身（它的標題與路線 Id 兩個任務要在交件前做，不該被 Leaflet 卡住，否決）。

### 路線軌跡進衍生表 route_day_shapes，跟著路線日存

新表 `route_day_shapes`：`route_day_id`（外鍵，`on_delete: :cascade`）、`go_back`、`shape_updated_at`（`timestamptz`，`utime` 當台北時間）、`points`（`jsonb`，`[[緯度, 經度], …]`），唯一索引 `(route_day_id, go_back)`；`RouteDay has_many :shapes, class_name: "RouteDayShape", dependent: nil`。DuckDB 端新增 `analysis/route_shape.sql`，`RouteDayLoader` 把它接在 `turnaround_facilities.sql` 之後、`derived_export.sql` 之前（`extra_files`），`derived_export.sql` 多寫 `shapes.csv`（`go_back,shape_updated_at,points`，照 `go_back` 排），loader 多一個 staging table 與 insert。

理由：Rails 只讀衍生表（`docs/spectra/LANGUAGE.md`「衍生表」），所以不在讀頁面時打開 gz。跟著路線日存而不是只存一份「目前的軌跡」，是因為快照每天都可能不同、也可能缺（10-23 少了 39 列），頁面才能退回更早有軌跡的那一天；這也跟 `route_days.static_day` 記站序取自哪一份快照同一個做法。另開一個不以數字開頭的 SQL 檔，`bin/health-card` 就不會跑到它，健檢卡的數字與五個檢查檔完全不變（卡上只有顯名聲明的第一行跟著文件變，見「GetBusShape 寫進公運處聲明的第一行，授權先查證」）。

替代方案：Rails 直接讀 gz（破壞「Rails 只讀衍生表」，否決）；放進 `analysis/10_load.sql`（健檢卡也會讀到這支檔，缺檔時連健檢卡都失敗，否決）；存原本的 WKT 字串、在 Ruby 裡解析（原始格式漏進 Rails，轉換分兩處，否決）。

### 取 RouteID 等於路線 Id、SubRouteID 為 -1 的列，點轉成緯度經度、取到小數 6 位

`analysis/route_shape.sql` 讀 `GetBusShape.gz`（陣列格式，`maximum_object_size` 照 `10_load.sql` 讀 `GetStop.gz` 的做法給足），只留 `RouteID` 等於變數 `route_id`、`SubRouteID` 等於 -1 的列。`wkt` 去掉 `LINESTRING (` 與 `)`，以「逗號加空格」切成座標，每個座標以空格切成經度、緯度，轉成 `[緯度, 經度]`，各自取到小數 6 位（約 0.1 公尺），照原本順序存。

可以用的列：`utime` 讀得出來（當成台北時間的時刻）、幾何是 `LINESTRING`、至少 2 點、每一點的緯度在 20 到 27、經度在 118 到 123 之間；後面三個門檻寫在 `params.sql`。這個範圍框住台灣本島與外島，主要是抓到經緯度對調（緯度會變成 121 左右）。`utime` 讀不出來的列也不能用，因為 `shape_updated_at` 不能是空的、圖下面那一行要寫公運處哪一天更新（2026-10-24 apply 任務 2.1 時使用者決定，ingest 補上；2026-10-22 的快照 1028 列的 `utime` 都讀得出來，量到的）。同一條路線同一個方向如果有不只一列 `SubRouteID` 為 -1，取能用的列裡 `utime` 最新的那一列，並印一行說明。

理由：三條有路線頁的路線、以及接下來要加的 307（16111、19108）與 265區（10482）都是 `SubRouteID` -1 的兩列；`SubRouteID` 不是 -1 的是特殊附屬路線，不是整條路線的走法。取到 6 位讓回應裡的 JSON 比照原樣輸出小將近一半（估計：每點約 39 個字元變約 22 個，驗收時量 JSON 大小），精度仍遠小於畫面上一個像素。

替代方案：照附屬路線（`pathAttributeId`）對（中山幹線的 162347、162348 沒有自己的列，否決）；把點簡化成更少（點數只有 200 多，不需要，否決）。

### 缺檔或不能用的列只少那一個方向，其他照常寫入，印一行說明

`RouteDayLoader` 在跑 DuckDB 之前看那一天的靜態快照有沒有 `GetBusShape.gz`：有就把路徑傳給變數 `bus_shape_path`；沒有就在暫存目錄寫一個內容是 `[]` 的檔，把它的路徑傳進去，並印「YYYY-MM-DD：靜態快照沒有 GetBusShape.gz，路線 <Id> 這一天沒有路線軌跡」（`route-shape` 的 Scenario「Shapes file missing」要點名路線、日期與缺的檔）。`shapes.csv` 固定是兩列，方向 0 與 1 各一列：可以用的那一列帶點與更新時間；沒有可用軌跡的方向，點與更新時間是空的，`issue` 寫原因代碼（`no_row` 沒有這個方向的列、`not_linestring`、`too_few_points` 少於 2 點、`out_of_range` 座標超出範圍、`no_update_time` 公運處的更新時間讀不出來）；同一個方向有不只一列、取了能用的列裡最新的那一列時，點照樣有，`issue` 寫 `duplicate_rows`。loader 只把有點的列寫進 `route_day_shapes`，對每一列有 `issue` 的印一行，寫出路線、日期、方向與原因；缺檔時只印缺檔那一行，不再逐方向印 `no_row`。

理由：路線軌跡是輔助，那一天的趟次、折返停留這些核心數字不能因為地圖的資料而寫不進去；但也不能悄悄少一條線，所以每一種缺都要印出來。照 turnaround-facilities 的做法：沒有設定兩端的路線也是印一行、照常寫入其他表。

替代方案：缺檔就讓那一天失敗（地圖的資料擋住核心數字，否決）；悄悄略過（少了一條線沒人知道，否決）。

### 頁面取涵蓋日子裡最新一個有軌跡的路線日，用 reorder 取

`RoutePage::RouteShape.new(route_days)`：在 `route_days` 裡挑有 `route_day_shapes` 列的路線日，用 `reorder(day: :desc)` 取第一個的 `id`；再讀那一天的軌跡（最多 2 列）與那一天 `route_day_stops` 每個方向 `seq` 最小與最大的站牌。全部只查三次，同一個物件呼叫多次不重查。

理由：涵蓋日子是從舊到新給的，`order` 會疊在後面，所以要 `reorder`（02-route-stop-sequence 的決定「站序取涵蓋日子裡最新一天，用 reorder 取」，避開那四個查詢物件的已知問題）。最新一天沒有軌跡時退回更早有軌跡的一天，跟 turnaround-facilities 的「最近一個有位置的日子」同一個想法；起站、末站取同一個路線日，圖裡的線與站一定對得上。

替代方案：只看最新一天（那天的快照缺列就沒有圖，否決）；起站、末站取站序卡用的最新一天（最新一天沒有軌跡時，兩者會是不同的日子，否決）。

### 圖上只畫兩個方向的線與各自的起站、末站

`app/frontend/route_map/runtime.js` 匯出 `draw(container)`：每個方向一條 `L.polyline`，兩個方向都是橘色 `#E95F00`，去程 class `route-map-line route-map-line-0`（實線）、返程 `route-map-line route-map-line-1`（虛線），線寬 4；每個方向的起站與末站各一個標記（`route-map-stop route-map-stop-first` 與 `route-map-stop-last`，樣子照端點地圖的末站與下一趟起站），滑過或點按顯示「去程起站：甲站」這類提示；右上角一個圖例「去程／返程」；視野 fit 所有線的外框，加邊距，縮放不超過 `data-max-zoom`。不畫其他站牌、不畫車、不上任何數字。

理由：兩個方向常走同一條路的兩側，但在端點附近會分開（251區 返程在公館端多繞台電大樓、溫州街口、臺大綜合體育館、臺大），用實線與虛線分得出來：只有一個方向走的那一段（例如公館端的繞行）是單獨的一段實線或虛線。顏色是使用者 2026-10-24 在任務 5.1 看過畫面後指定的橘色，取代原本的去程 `teal-700`、返程 `slate-500`（疊在 OSM 底圖上太暗）；`#E95F00` 是從使用者給的參考圖取樣的主色，圖帶的螢幕描述檔轉到 sRGB 後同一個值（量到的）。起站、末站就是折返的地方，跟站序清單的折返列對得上。

替代方案：兩個方向不同顏色（原本的 teal 與 slate 太暗，使用者否決；去程橘色、返程淡橘或維持灰，使用者選了兩個方向同一個橘色）；兩個方向同一個顏色又同一種線（分不出公館端的繞行，否決）；標出沿線每一站（02-route-stop-sequence 的清單已經有，圖會擠，留給之後，否決）；用箭頭標方向（Leaflet 要外掛，否決）。

### 地圖下面只寫資料來源與公運處更新日

取代原本的決定「地圖下面寫明是登記的路線、快照日與公運處更新日」（2026-10-24 ingest：使用者在任務 5.1 看過畫面後決定，這一行只講資料來源與更新日期）。

容器之後一行 `p[data-route-shape-source]`，帶 `data-updated-on`（`iso8601`），文字是「資料來源：臺北市公共運輸處公車路線軌跡，YYYY-MM-DD 更新。」更新日取畫出來的方向裡 `shape_updated_at` 最晚的那一天（台北日）。涵蓋的日子都沒有軌跡時，不輸出地圖容器，改成 `p[data-no-route-shape]`「這幾天的快照沒有這條路線的路線軌跡。」

理由：圖下面那一行讓讀者知道線從哪裡來、多久沒更新就夠了；251區 的軌跡是 2023 年底更新的，寫出來讓人自己判斷。「是登記的、不是 GPS 量到的」由資料限制那一句講，不在圖下面重複。代價：涵蓋的最新一天沒有軌跡、頁面退回更早一天時，讀者從頁面上看不出線取自哪一天（使用者知道並接受）。

替代方案：照原本的決定寫明是登記的路線與快照日（句子太長、講了不必要的事，使用者否決）；只寫在資料限制那張卡（離圖太遠，否決）；不寫更新日（舊的軌跡看起來跟新的一樣，否決）。

### endMap 與 routeMap 共用 Alpine 載入流程與 Leaflet 設定，各自一個繪圖 chunk

- `app/frontend/entrypoints/application.js`：把 `endMap` 的生命週期（`IntersectionObserver` 0.25、`pending → loading → ready | static`、`turbo:before-cache` 還原、`destroy()` 釋放、`reportError`）抽成一個函式 `lazyMap(load)`；`Alpine.data("endMap", () => lazyMap(() => import("../end_map/runtime.js")))`、`Alpine.data("routeMap", () => lazyMap(() => import("../route_map/runtime.js")))`。每個 `import()` 的路徑仍寫死在呼叫端，Vite 才切得出 chunk。
- 新增 `app/frontend/maps/base_map.js`：建 Leaflet 地圖的共用設定（`keyboard: false`、滾輪與觸控的手勢照「地圖手勢照 Google 地圖：滾輪捲頁，按住 Ctrl 或 ⌘ 才縮放」、粗指標時不拖曳、減少動態效果時關三種動畫並設 `data-animations="off"`、顯名不加前綴、縮放鈕不進 tab 順序、圖磚層讀容器的 `data-tile-url`、`data-tile-attribution`、`data-max-zoom`）與標記、提示的小工具，`end_map/runtime.js` 與 `route_map/runtime.js` 都從這裡建圖。
- Vite 會把 Leaflet、它的 CSS 與 `base_map.js` 拆成兩個繪圖 chunk 共用的 chunk。turnaround-map 的 Map budget 改成「共用的 chunk 加上任一個繪圖 chunk，brotli 後不超過 100 KB」。

理由：兩張圖是同一個產品決定下的互動規則（長頁面裡沒按鍵的滾輪捲頁、單指捲頁、鍵盤不進地圖），分成兩份就會各改各的。兩個呼叫端讓這個共用的介面成立，不是預先抽象。共用 chunk 讓同一頁兩種圖只下載一次 Leaflet。

替代方案：`route_map/runtime.js` 自己複製一份設定（兩份會分歧，否決）；兩種圖畫在同一個 runtime（`end_map/runtime.js` 的名字與 turnaround-map 的 system spec 都對著端點地圖，否決）。

### 地圖手勢照 Google 地圖：滾輪捲頁，按住 Ctrl 或 ⌘ 才縮放

取代決定「endMap 與 routeMap 共用 Alpine 載入流程與 Leaflet 設定，各自一個繪圖 chunk」裡 `scrollWheelZoom: false` 那一項（2026-10-24 ingest：使用者在任務 5.1 看過路線圖，要滑鼠滾輪能縮放，選了像 Google 地圖的做法）。兩張地圖一起改，因為互動規則本來就共用。

縮放鍵在 Mac 是 ⌘、其他系統是 Ctrl（2026-10-24 使用者在任務 4.5 補充），用 `navigator.platform` 判斷：它在各瀏覽器都有，`navigator.userAgentData` 只有 Chromium 有。`maps/base_map.js` 的 `drawMap` 打開 Leaflet 的 `scrollWheelZoom`，但在地圖元素上用 capture 階段的 `wheel` 監聽先擋一道：沒按縮放鍵的滾輪事件不傳給 Leaflet、也不 `preventDefault`，頁面照常捲，地圖上蓋一句寫著縮放鍵的提示；按著縮放鍵的交給 Leaflet 以游標為中心縮放，並 `preventDefault`，頁面不捲、瀏覽器也不放大頁面，提示收起。觸控板捏合送的是按著 Ctrl 的滾輪事件，所以 Ctrl 在 Mac 也當縮放鍵處理，不然 Mac 上的捏合會放大整個網頁（Google 地圖在 Mac 上也是這樣）；Windows 上按 Windows 鍵（瀏覽器的 `metaKey`）滾動，照樣捲頁並出提示。觸控螢幕照舊：粗指標時不拖曳，單指捲頁；兩指由 Leaflet 的 `touchZoom` 跟著兩指的中點移動並縮放。拖曳關著時單指在地圖上移動，蓋「用兩根手指移動或縮放地圖」的提示。滑鼠照舊可以拖曳。提示是地圖元素裡的一個 `div.map-gesture-note`，顯示時帶 `data-shown`，不吃滑鼠、不進 tab 順序，最後一次手勢後 1.2 秒收起，減少動態效果時不淡入淡出。字放在 `config/locales` 的 `maps.gestures`（`wheel_zoom` 帶 `{key}` 給腳本填、`two_fingers`），兩張圖共用，跟全螢幕按鈕的字一起由 `ApplicationComponent#base_map_labels_json` 寫進兩種容器的 `data-base-map-labels`。

一格滾輪縮放不到一級（2026-10-24 使用者說一格縮太多）：Leaflet 預設 `zoomSnap` 1，一格滾輪至少放大一級，也就是兩倍。改成 `zoomSnap: 0.5`、`wheelPxPerZoomLevel: 240`，一格是 0.5 級、約 1.41 倍。推算（照 Leaflet 1.9.4 的原始碼，真資料驗收時看手感）：Leaflet 先把滾輪的 px 依系統除以一個倍數，Mac 是螢幕像素比的 3 倍、Windows 是 2 倍、Linux 的 Chrome 是 1 倍，再用 S 形函數換成級數；Retina 的 Mac 一格 120 px 算出 0.06 級，Windows 一格 100 px 算出 0.15 級，都進位成剛好 0.5 級。`wheelPxPerZoomLevel` 要調高：維持預設 60 時，Windows 一格算出 0.57 級，會進位成一整級。原本 ingest 寫的 `zoomSnap: 0.25` 會讓每一格只有 0.25 級，任務 4.5 實作時算出來改掉。縮放鈕照舊一次一級（`zoomDelta: 1`）。附帶的效果：觸控板捏合以半級為單位縮放，`fitBounds` 也能停在半級，細長的路線框得比較大；小數等級的圖磚是整數等級的圖磚縮放顯示，圖磚張數可能比整數等級多一點。

理由：長頁面裡滾輪直接縮放，捲頁會卡在地圖上，turnaround-map 當初因此整個關掉；Google 地圖的做法兩邊都顧到，讀者多半用過，提示也說得出該怎麼做。

替代方案：滾輪直接縮放（捲頁會卡在地圖上，否決）；點一下地圖才開滾輪縮放（多一步，讀者不知道要點，否決）；用 Leaflet.GestureHandling 外掛（多一個相依套件，自己寫幾十行就夠，否決）。

### 地圖可以全螢幕，按鈕在縮放鈕下面，全螢幕時滾輪與單指直接操作地圖

2026-10-24 ingest：使用者在任務 4.5 實作中要一個全螢幕的按鈕。兩種地圖都加，規則共用。

`maps/base_map.js` 的 `drawMap` 在 `document.fullscreenEnabled` 為真時加一個 Leaflet 控制項，放在縮放鈕下面：`div.map-fullscreen` 裡一個 `a`，跟縮放鈕一樣 `tabIndex` 是 -1、`role="button"`，`title` 與 `aria-label` 讀 `data-base-map-labels` 的 `fullscreen`、`exitFullscreen`。按下時對地圖容器（`[data-end-map]` 或 `[data-route-map]`）呼叫 `requestFullscreen()`，全螢幕時再按呼叫 `document.exitFullscreen()`；Esc 由瀏覽器處理。容器在 `fullscreenchange` 時：全螢幕的是自己，就打開拖曳、手勢改成直接操作（滾輪不用按鍵、不出提示）、容器帶 `data-fullscreen`；離開時恢復頁面裡的手勢與拖曳設定；兩種情況都呼叫 `map.invalidateSize()`。樣式讓 `:fullscreen` 的容器與畫布填滿畫面。

理由：讀者想看路線細節時，頁面裡 288 px 高的地圖太小；全螢幕時沒有頁面要捲，滾輪與單指直接給地圖用，跟 Google 地圖全螢幕時一樣。iPhone 的 Safari 不支援讓元素全螢幕，就不出按鈕，不做假的。

替代方案：只用 CSS 把容器撐滿畫面（iPhone 也能用，但不是真的全螢幕，捲動、返回鍵與 Esc 都要自己處理，否決）；只給路線圖（兩張圖的規則會分歧，否決）。

### GetBusShape 寫進公運處聲明的第一行，授權先查證

取代原本的決定「頁尾多一行公車路線軌跡的顯名，授權先查證」（2026-10-24 ingest，跟上 01-bus-feeds-attribution）。

任務 1.2 先打開 data.gov.tw「臺北市公車路線軌跡」（data.gov.tw/dataset/160167），確認提供機關是臺北市公共運輸處、授權是政府資料開放授權條款第 1 版。對得上就：

- `docs/data-sources.md` 授權那一節的資料集表多一列：公車路線軌跡（GetBusShape）、資料集頁面、頁面列的 JSON、查證日期。
- 聲明第一行在「附屬路線與路線對應（GetPathDetail）」之後加上「、公車路線軌跡（GetBusShape）」，名稱用 API 說明文件 V6.3 與 n-gear `title_zh` 的「公車路線軌跡」。`docs/data-sources.md` 的引文、`attribution_component.yml` 的 `statement`（tw 與 en 同一段原文）、`bin/health-card` 的 `ATTRIBUTION` 三處一起改，第二、三行不動；`AttributionComponent` 的 `.rb` 與 `.html.erb` 不改，頁尾不多一行。

查到的授權不是第 1 版、或提供機關不同，就停下回報，不寫進聲明。頁面找不到時，那一列照 01-bus-feeds-attribution 的做法記「同一份 API 說明文件、同一個主機，授權依同系列推定」。

健檢卡跟著變：`bin/health-card` 不讀 `GetBusShape.gz`，但 health-card 的 Limitations and attribution text 要它逐字收錄文件裡的三段聲明，所以卡上的第一行也會點名 GetBusShape。多點名一支卡沒用到的 feed 不違反條款；卡的數字與五個檢查檔不變，`route-shape` 的 Route shape of a route day 照這樣寫。

測試：聲明的字是固定文案，不另寫斷言；01-bus-feeds-attribution 的測試照舊把三處綁在一起，任務 1.2 先改文件、看 `spec/requests/site_layout_spec.rb` 與 `spec/analysis/card_spec.rb` 失敗，再改另外兩處。程式開始讀路線軌跡的任務 2.2，把 `spec/analysis/attribution_spec.rb` 的「今天讀的六支都掃得到」改成七支、加上 GetBusShape（`site-layout` 的 Example: feeds read today 多的那一列），在 `RouteDayLoader` 寫到 `GetBusShape.gz` 之前先失敗。任務 1.2 排在 2.1 之前：路線軌跡的 SQL 或 Ruby 一寫到 `GetBusShape.gz`，聲明就要已經點名它，`attribution_spec.rb` 才不會失敗。

理由：01-bus-feeds-attribution 之後，聲明第一行要點名程式讀到的每一支公運處 feed，另起一行的做法過不了 `attribution_spec.rb`。原本否決「加進第一行」的理由是那一行寫著「即時開放資料」，01-bus-feeds-attribution 已經拿掉「即時」，理由不成立。同一個機關、同一份 API 說明文件、同一個授權，一段列完，跟其他六支一樣。

替代方案：頁尾在公運處聲明之後另起一行（`attribution_spec.rb` 要求代碼在第一行，而且同一個機關分兩處寫，否決）；健檢卡用一段不含 GetBusShape 的聲明（違反健檢卡逐字收錄文件聲明的規格，三處就不再一字不差，否決）。

### 詞彙表新增「路線軌跡」

`docs/spectra/LANGUAGE.md`「路網物件」底下新增一條「路線軌跡」：定義（公運處登記的一條路線一個方向行經的線，不是 GPS 量到的）、在資料或程式碼裡（`GetBusShape.gz` 的 `wkt`，`RouteID` 對路線 `Id`、`SubRouteID` -1；衍生表 `route_day_shapes`）、邊界（附屬路線另有 `SubRouteID` 的列不算；會舊；某天的快照可能缺）、不要用（路線形狀、shape、行經路線、單獨出現的「軌跡」；指車機 GPS 時寫「GPS 軌跡」）。

理由：使用者 2026-10-24 選的詞，跟資料集正式名稱「公車路線軌跡」與 `docs/background.md` 一致。turnaround-map 的非目標寫「路線形狀」、決定裡人工查證時寫「GPS 軌跡」，這條把兩者分開。

### archive 順序：turnaround-facilities → turnaround-map → 01-bus-feeds-attribution → 02-route-stop-sequence → 03-route-shape-map

五份 delta 的底：`route-page` 的 Stop sequence block 以 02-route-stop-sequence 的 ADDED 版為底，Data limitations on the page 以 turnaround-map 的版本為底；`site-layout` 以 01-bus-feeds-attribution 的版本為底；`turnaround-map` 以 turnaround-map 的版本為底；`derived-tables` 以 turnaround-facilities 的版本為底。turnaround-facilities 與 turnaround-map 已在 2026-10-24 archive。apply 之前先跑 `/spectra-drift 03-route-shape-map`，核對那幾個 change 落地的表名、元件標記、檔名與這裡一致，不一致先 ingest。

site-easter-eggs 也修改 `site-layout` 的 Attribution footer on every page，加上 `public/` 底下靜態錯誤頁的例外。它若比這個 change 先 archive，這裡的 delta 要先併進那段例外再 archive；若後 archive，由它併進這裡的版本。

理由：同一條 requirement 被好幾個 change 修改時，後 archive 的版本才是最後的版本；寫在前一個版本上才不會把它的字吃掉（turnaround-map 對 turnaround-facilities 的同一個做法）。

替代方案：先寫在現在的主 spec 上、archive 前再重寫（那時要重新對三份 delta，容易漏，否決）。

## Implementation Contract

**行為**：

- `bin/rails derived:load ROUTE=11764 DAY=2026-10-22` 之後，`route_day_shapes` 有那一天兩列，`points` 去程 212 點、返程 231 點（2026-10-22 的快照），`shape_updated_at` 是 2023-12-29 的兩個時刻；路線頁 `/routes/11764?day=2026-10-22` 的站序卡在標題之後、清單之前有路線圖的容器，捲到之後畫出兩條線與四個起站、末站標記，圖下面一行寫「資料來源：臺北市公共運輸處公車路線軌跡，2023-12-29 更新。」
- 快照沒有 `GetBusShape.gz` 的日子照樣載入，印一行說明；頁面退回更早有軌跡的日子，都沒有時寫「這幾天的快照沒有這條路線的路線軌跡。」，不輸出地圖容器。
- 沒有 JavaScript 或 chunk 載不到：容器是一句話，站序清單完整。
- 兩種地圖都有全螢幕按鈕（瀏覽器不支援時沒有）；全螢幕時地圖填滿畫面，滾輪不用按鍵就縮放、單指也能移動、不出提示，再按一次或 Esc 回到頁面。
- 兩種地圖的手勢：縮放鍵在 Mac 是 ⌘、其他系統是 Ctrl（Mac 上觸控板捏合送的 Ctrl 也縮放）；滑鼠滾輪沒按縮放鍵時捲頁、地圖不縮放，地圖上短暫出現寫著縮放鍵的提示；按著縮放鍵時以游標為中心縮放、頁面不捲；觸控螢幕單指捲頁並短暫出現兩指的提示，兩指移動與縮放；滑鼠照舊拖曳。
- 首頁不請求地圖的共用 chunk 與兩個繪圖 chunk；路線頁只捲到站序卡時，不請求端點地圖的繪圖 chunk。
- 公運處聲明的第一行點名公車路線軌跡（GetBusShape）：頁尾、`docs/data-sources.md` 與 `bin/health-card` 產出的卡同一段；`docs/data-sources.md` 授權那一節的資料集表有這一支的資料集頁面與查證日期。健檢卡除了這一行，數字與五個檢查檔不變。

**介面與資料形狀**：

- 資料表 `route_day_shapes(route_day_id bigint not null references route_days on delete cascade, go_back integer not null, shape_updated_at timestamptz not null, points jsonb not null)`，唯一索引 `(route_day_id, go_back)`；model `RouteDayShape belongs_to :route_day`，annotaterb 自動加 schema 註解。
- `analysis/route_shape.sql` 讀變數 `bus_shape_path`、`route_id`，建 `route_shapes`：方向 0 與 1 各一列，`go_back`、`shape_updated_at`、`points`、`issue`（`no_row`、`not_linestring`、`too_few_points`、`out_of_range`、`no_update_time`、`duplicate_rows` 或空）；`params.sql` 加可以用的列的三個門檻（最少點數 2、緯度 20 到 27、經度 118 到 123）。`derived_export.sql` 寫第九個檔 `shapes.csv`（`go_back,shape_updated_at,points,issue`）。
- `RouteDayLoader`：`STAGING` 與 `STAGING_TABLES` 多 `shapes`；`replace` 多 `insert_shapes`（只寫有點的列），回傳的計數多 `shapes`；跑 DuckDB 前決定 `bus_shape_path`（缺檔時是內容為 `[]` 的暫存檔，並印缺檔那一行），寫入後對每一列有 `issue` 的印一行（缺檔時不再逐方向印）。
- `RoutePage::RouteShape.new(route_days)`：`#available?`、`#updated_on`（`Date`）、`#lines`（每個方向 `Line = Data.define(:go_back, :points)`，照 `go_back` 排）、`#end_stops`（每個畫出的方向 `EndStops = Data.define(:go_back, :first, :last)`，`first`、`last` 是 `Stop = Data.define(:name, :lat, :lon)`）。
- `RouteMapComponent.new(route_shape:, tiles: MapTiles)`（`bin/rails g view_component:component RouteMap route_shape tiles --locale`）：`div[data-route-map][data-map="pending"][x-data="routeMap"][aria-hidden="true"][data-tile-url][data-tile-attribution][data-max-zoom][data-labels]`，裡面依序 `script[type="application/json"][data-route-map-data]`、`p[data-map-note]`、`div[data-map-canvas]`；容器之後 `p[data-route-shape-source][data-updated-on]`。沒有軌跡時只有 `p[data-no-route-shape]`。
- JSON：`{"lines": [{"goBack": 0, "points": [[25.05, 121.5], …]}, …], "endStops": [{"goBack": 0, "first": {"name": "甲站", "lat": 25.05, "lon": 121.5}, "last": {…}}, …]}`，鍵名 camelCase，座標是數字。
- `StopSequenceComponent` 的模板在 `h2` 之後、`details` 之前輸出 `content`；`show.html.erb` 把 `RouteMapComponent` 當成區塊傳進去。
- 前端：`lazyMap(load)`、`Alpine.data("routeMap")`、`app/frontend/maps/base_map.js`、`app/frontend/route_map/runtime.js` 的 `draw(container)` 回 `{ dispose() }`；畫出的元素帶 class `route-map-line-0`、`route-map-line-1`、`route-map-stop-first`、`route-map-stop-last`、`route-map-legend`；`drawMap` 為兩種地圖裝上手勢與全螢幕按鈕，讀容器的 `data-base-map-labels`（`{"wheelZoom": "…{key}…", "twoFingers": "…", "fullscreen": "…", "exitFullscreen": "…"}`），提示是地圖元素裡的 `div.map-gesture-note`，顯示時帶 `data-shown`；全螢幕按鈕是縮放鈕下面的 `div.map-fullscreen` 裡的 `a`，全螢幕時容器帶 `data-fullscreen`。`ApplicationComponent#base_map_labels_json` 產生 `data-base-map-labels`，`RouteMapComponent` 與 `EndMapComponent` 的容器都帶它。
- 文案：`route_map_component.yml`（tw、zh-TW、en）放那一句、圖下面那一行、沒有軌跡的那一句、標記的提示與圖例；`attribution_component.yml` 的 `statement` 與 `bin/health-card` 的 `ATTRIBUTION` 第一行多「公車路線軌跡（GetBusShape）」；`data_limitations_component.yml` 的 `items` 多一句；`config/locales/tw.yml` 與 `en.yml` 多 `maps.gestures`（`wheel_zoom`、`two_fingers`）與 `maps.fullscreen`（`enter`、`exit`）。

**失敗模式**：

- 快照沒有 `GetBusShape.gz`、沒有這條路線的列、列不能用（幾何不能用或 `utime` 讀不出來）：那個方向沒有軌跡，印一行說明，其他表照常寫入。
- 同一個方向不只一列 `SubRouteID` -1：取 `utime` 最新的，印一行說明。
- 涵蓋的日子都沒有軌跡：沒有地圖容器，寫那一句。
- chunk 載不到、Leaflet 丟例外：`data-map="static"`，那一句顯示，`reportError`。
- 圖磚服務不通：底圖空白，線與標記照畫。

**驗收**：

- `bundle exec rspec` 全綠，含：`spec/analysis/route_shape_spec.rb`（fixture 兩個方向的點數、第一點與最後一點、取到 6 位、更新時間；9100 與附屬路線的列不留；缺檔用 `[]` 時兩個方向都沒有點、`issue` 是 `no_row`；`route-shape` 規格那張表的五種情形各自的 `issue`；同一個方向兩列時留 `utime` 較新的、`issue` 是 `duplicate_rows`）、`spec/analysis/derived_export_spec.rb`（九個檔、`shapes.csv` 的欄位名、連跑兩次位元組相同）、`spec/models/route_day_loader_spec.rb`（存兩列、重載列數不變、缺檔時照常寫入並印出那一行、不能用的方向印出原因）、`spec/models/route_page/route_shape_spec.rb`（涵蓋日子從舊到新給、最新一天沒有軌跡時退回前一天；起站末站取同一個路線日；只有一個方向；`updated_on` 取較晚的；三次查詢以內）、`spec/components/route_map_component_spec.rb`（JSON 形狀、座標是數字、沒有車牌、data 屬性、圖下面那一行有更新日而沒有快照日、沒有軌跡時那一句）、`spec/requests/routes_spec.rb`（站序卡裡容器在 `details` 之前、不在 `details` 裡；沒有腳本時是 `pending`、那一句與 JSON 都在；Bullet 不報 N+1）、`spec/analysis/attribution_spec.rb`（今天讀的七支都掃得到，含 `GetBusShape.gz`；每一支都被聲明第一行點名）、`spec/requests/site_layout_spec.rb` 與 `spec/analysis/card_spec.rb`（頁尾與健檢卡的聲明跟文件逐字相同，照舊通過）、`spec/system/route_map_spec.rb`（`:js`：捲到之後 `ready`、兩條線與四個標記；擋掉繪圖 chunk 時 `static`；首頁不請求；只捲到站序卡時不請求端點地圖的繪圖 chunk；減少動態效果時 `data-animations="off"`）、`spec/system/end_map_spec.rb` 照舊全過；手勢另有 `spec/system/route_map_spec.rb` 的例子（CDP 的 `Emulation.setUserAgentOverride` 把 `navigator.platform` 設成 Mac 與 Windows，各用 `Input.dispatchMouseEvent` 在地圖上滾三種按鍵；觸控模擬加 `Input.dispatchTouchEvent` 單指拖曳；量頁面捲動、線段外框大小與提示）與 `spec/system/end_map_spec.rb` 新加的沒按鍵滾動的例子，兩個元件 spec 檢查容器的 `data-base-map-labels`。
- 預算：`yarn build` 後量共用 chunk 與兩個繪圖 chunk 的 `brotli -q 11`、`gzip -9`，兩組合計都不超過 100 KB，寫回這份 design 的 Risks。
- 真資料：三條路線重跑 `derived:load` 之後，`?day=2026-10-22` 在 1280 px 與 390 px 寬各看一次，線沿著實際道路、兩端起站末站對得上站序清單、公館端的繞行看得出來；量每張圖初次畫出的圖磚張數與 KB、回應裡 JSON 的大小，寫回 Risks。
- `bin/rubocop` 對新增與修改的 Ruby 檔沒有 offense，`bin/brakeman` 沒有警告。

**範圍邊界**：範圍內是 `route_day_shapes` 與它的 migration、model、`analysis/route_shape.sql` 與 export、`RouteDayLoader`、`RoutePage::RouteShape`、`RouteMapComponent`、站序元件留給它的位置、`lazyMap` 與 `base_map.js` 的抽取、兩種地圖的手勢與全螢幕按鈕（`base_map.js`、`maps.gestures`、`maps.fullscreen`、`base_map_labels_json`、兩種容器的 `data-base-map-labels`）、`route_map/runtime.js`、CSS、顯名（三處聲明的第一行與授權那一節的資料集表）、資料限制、詞彙表、`docs/data-sources.md`、測試與預算量測。範圍外是 GPS 的任何畫法與比對、端點地圖畫什麼（手勢與全螢幕在範圍內）、底圖來源、站序清單的內容、其他六支 feed 的顯名、附屬路線的軌跡、307 與 265區、首頁、健檢卡的計算與檢查檔（卡上只有聲明第一行跟著文件變）、排程與部署。

## Risks / Trade-offs

- [登記的軌跡跟實際走的路不一樣，例如改道之後沒更新] → 頁面寫明是登記的、寫出更新日；資料限制補一句；只驗了 2026-10-22 一天（量到的），真資料驗收再看一次。自動比對 GPS 是另一個 change。
- [前置的四個 change 任何一個改了介面] → apply 前跑 `/spectra-drift 03-route-shape-map`，不一致先 ingest。
- [GetBusShape 的資料集頁面在 apply 前改版或下架] → 任務 1.2 重新查證，授權或提供機關對不上就停下回報，不寫進聲明。
- [抽出 `lazyMap` 與 `base_map.js` 改壞端點地圖] → `spec/system/end_map_spec.rb` 不改、要照舊全過。
- [共用 chunk 加繪圖 chunk 超過 100 KB] → 預算是估計：turnaround-map 量到的端點地圖 chunk 加上一個約 2 KB 的繪圖檔（估計，驗收時量）；超過就停下回報，不自己放寬。2026-10-24 任務 4.3 量到的（Leaflet 1.9.4，`yarn build` 之後，單位 bytes）：共用 chunk（manifest 裡兩個繪圖 chunk 都 import 的 `_base_map-*.js`，Leaflet 與 `maps/base_map.js`）原始 149,987、`brotli -q 11` 後 37,787、`gzip -9` 後 43,285；跟著它載入的 CSS（Leaflet 的 CSS）原始 15,095、brotli 5,667、gzip 6,392；端點地圖的繪圖 chunk（`end_map/runtime.js`）原始 1,746、brotli 728、gzip 851；路線圖的繪圖 chunk（`route_map/runtime.js`）原始 1,199、brotli 501、gzip 607。共用 chunk 與它的 CSS 加端點地圖的繪圖 chunk，brotli 44,182、gzip 50,528；加路線圖的繪圖 chunk，brotli 43,955、gzip 50,284，兩組都在 100 KB 以內。Leaflet 只在共用 chunk 裡，application 的 chunk 與首頁插圖的 chunk 都沒有。任務 4.5、4.6 加了手勢與全螢幕按鈕之後重量（2026-10-24，同樣做法）：共用 chunk 原始 151,696、brotli 38,313、gzip 43,920，CSS 不變；端點地圖的繪圖 chunk brotli 726、gzip 854；路線圖的 brotli 502、gzip 610。共用加端點地圖 brotli 44,706、gzip 51,166；加路線圖 brotli 44,482、gzip 50,922，仍在 100 KB 以內。
- [手勢提示蓋住地圖] → 只在手勢當下出現、最後一次手勢後 1.2 秒收起，不吃滑鼠、不進 tab 順序；減少動態效果時不淡入淡出。
- [桌機打開路線頁就載入地圖與圖磚] → 使用者 2026-10-24 接受；驗收量一次張數與 KB。2026-10-24 任務 5.1 量到的（開發環境，三條路線 `?day=2026-10-22`，headless Chrome 用 CDP 把視窗設成 1280×900 與 390×844，捲到路線圖、等圖磚載完，數路線圖裡的圖磚；OSM 的圖磚沒有回 `Timing-Allow-Origin`，瀏覽器量不到大小，KB 是對同一批網址 HEAD 取 `content-length` 加總）：中山幹線 15373 在 1280 寬是縮放 11、10 張、276.1 KB，390 寬是縮放 11、4 張、139.6 KB；251 10712 在 1280 寬是縮放 12、10 張、311.5 KB，390 寬是縮放 11、6 張、186.0 KB；251區 11764 在 1280 寬是縮放 12、10 張、311.5 KB，390 寬是縮放 12、4 張、148.4 KB。只捲到站序卡時，端點地圖一張圖磚都沒載。回應裡路線圖的 JSON：15373 是 10,036 bytes（205 與 218 點）、10712 是 12,323 bytes（258 與 266 點）、11764 是 10,452 bytes（212 與 231 點），gzip 後約 3 KB，跟 proposal 估的約 10 KB 相符。任務 4.5 把縮放改成可以停在半級（`zoomSnap` 0.5）之後重量圖磚（同樣做法）：地圖一開始框得比較大，15373 在 1280 寬是圖磚縮放 12、14 張、461.9 KB，390 寬是縮放 11、4 張、140.8 KB；10712 在 1280 寬是縮放 12、10 張、311.1 KB，390 寬是縮放 12、6 張、197.4 KB；11764 在 1280 寬是縮放 13、14 張、452.5 KB，390 寬是縮放 12、4 張、148.4 KB。桌機上兩條路線多載 4 張，都遠低於 30 張的警戒。
- [265區 有三重、大南兩種走法，路線層級的軌跡只有一條] → 加 265區 的 change 查證它畫的是哪一種，必要時改用附屬路線的列。
- [307 一頁兩個路線 Id] → 由 307 的 change 決定畫一條還是兩條。
- [某天的快照整份缺列] → 頁面退回更早有軌跡的日子，圖下面照寫那幾條線的更新日；頁面不寫取自哪一天（使用者 2026-10-24 決定圖下面只寫資料來源與更新日）。

## Migration Plan

- 新的 migration 建 `route_day_shapes`；`bin/rails db:migrate`，annotaterb 自動更新 model 的 schema 註解。
- `yarn build`；部署時照常跑 migration。
- 三條路線已經載入的日子重跑 `bin/rails derived:load`，才會有軌跡；沒重跑的日子頁面寫「這幾天的快照沒有這條路線的路線軌跡。」
- 回退：拿掉 `RouteMapComponent` 的 render 與 `routeMap`，頁面回到 02-route-stop-sequence 的樣子；`route_day_shapes` 留著不影響其他表，要拿掉就 rollback 那個 migration。
