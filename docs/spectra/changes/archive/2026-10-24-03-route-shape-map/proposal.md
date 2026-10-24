## Why

這個 change 服務三樣交付物的第一樣：路線健檢卡在網站上的路線頁。暫存中的 02-route-stop-sequence 會在區塊導覽之後加一張「站序」卡，回答「這條路線停哪些站、在哪裡折返？」，但它只是文字清單，而且預設收起。不熟這條線的讀者（記者、議員辦公室、審議委員，`docs/use-cases.md` 第 3、5、6 項）要的是看一眼就知道車走哪些路。使用者 2026-10-24 決定在那張卡的清單上方加一張路線圖，一直看得到。

需要的資料都已經在收，只差進衍生表：

- **路線軌跡**：n-gear 每天 04:30 的靜態快照裡有 `GetBusShape.gz`（公運處的「公車路線軌跡」），每條路線每個方向一條 WKT `LINESTRING`，座標是經度、緯度，用 `RouteID` 對路線 `Id`，`SubRouteID` 是 -1 的那兩列就是整條路線。現在沒有任何階段讀它。
- **起站與末站**：衍生表 `route_day_stops` 已經有兩個方向每站的座標。
- **底圖**：用 turnaround-map 接好的 OpenStreetMap 圖磚、`config/map.yml` 與 `MapTiles`，不新增外部來源。

路線軌跡是公運處登記的線，不是 GPS 量到的。2026-10-22 拿它跟 `bus_data` 的 GPS 比過（照 `(BusID, DataTime)` 去重，量到的）：

| 路線 | 站牌離線最遠 | GPS 落在線 50 公尺內 |
| --- | --- | --- |
| 251區 11764 | 14.6 公尺 | 去程 99.8%、返程 96.2% |
| 251 10712 | 15.1 公尺 | 96.8% 到 99.9% |
| 中山幹線 15373 | 13.2 公尺 | 96.4% 到 99.9% |

沒有落在線上的，大多是停車那一端的折返動作：251區 返程離線超過 50 公尺的 508 點，除了 1 點都在深坑端的福安居一附近。中山幹線返程在士林一帶有 15 台車偏離 40 到 100 公尺。所以這條線可以拿來畫「車走哪些路」，但資料限制要寫明它是登記的、不是量到的。

軌跡本身也會舊、會缺：251區 的軌跡 `utime` 是 2023-12-29，10-19 到 10-24 六份快照完全一樣；10-23 那份快照整份少了 39 列（989 列，平常是 1028 列），251區 剛好還在。所以軌跡要跟著路線日存，記下取自哪一天的快照；頁面用涵蓋日子裡最新一個有軌跡的日子。

## What Changes

- **衍生表多一張 `route_day_shapes`**：`derived:load` 多跑 `analysis/route_shape.sql`，接在 `analysis/turnaround_facilities.sql` 之後、`analysis/derived_export.sql` 之前。它從那一天靜態快照的 `GetBusShape.gz` 取這條路線 `Id`、`SubRouteID` 為 -1 的列，每個方向一列：方向、照原本順序的點（緯度、經度）、公運處的更新時間 `utime`。`derived_export.sql` 多寫一個 `shapes.csv`，`RouteDayLoader` 在同一個交易裡替換。快照沒有 `GetBusShape.gz`、沒有這條路線的列，或那一列不是可以用的 `LINESTRING`、讀不出公運處的更新時間時，那一天那個方向就沒有軌跡，`derived:load` 印一行說明，其他的表照常寫入。
- **站序卡的清單上方多一張路線圖**：畫兩個方向的路線軌跡各一條線，加上每個方向的起站與末站，底圖跟 turnaround-map 的端點地圖同一套。資料由伺服器算好、寫進回應（一段 `application/json`），取涵蓋日子裡最新一個有軌跡的路線日。圖下面一行只寫資料來源（臺北市公共運輸處公車路線軌跡）與公運處哪一天更新（2026-10-24 使用者看過畫面後決定，不寫快照日，也不在這裡講「不是 GPS 量到的」）。兩個方向的線都是使用者指定的橘色 `#E95F00`，去程實線、返程虛線。涵蓋的日子都沒有軌跡時不畫圖，改成一句話。
- **按需載入**：跟端點地圖一樣，容器至少四分之一進到畫面才載入地圖的 chunk。載入前、載不到、沒有 JavaScript 時，容器裡是一句話，站序清單照樣完整。端點地圖的 `endMap` 與新的 `routeMap` 共用同一套 Alpine 載入流程；兩張圖的 Leaflet 設定（互動、顯名、圖磚層）抽成共用的模組，Vite 會把 Leaflet 拆成兩者共用的 chunk，所以 turnaround-map 的預算要改成「共用的 chunk 加上各自的繪圖 chunk」。
- **地圖手勢**：端點地圖與路線圖一起改成像 Google 地圖：滑鼠滾輪照常捲頁，按住縮放鍵滾動才縮放地圖，縮放鍵在 Mac 是 ⌘、Windows 是 Ctrl（Mac 上觸控板捏合也縮放）；觸控螢幕單指捲頁、兩指移動縮放；手勢不對時，地圖上短暫出現一句提示；一格滾輪縮放不到一級（2026-10-24 使用者看過畫面後決定）。
- **地圖全螢幕**：兩種地圖在縮放鈕下面多一顆全螢幕按鈕（瀏覽器不支援時沒有，例如 iPhone 的 Safari）；全螢幕時滾輪不用按鍵就縮放、單指也能移動，再按一次或 Esc 回到頁面。
- **顯名**：照 01-bus-feeds-attribution 的做法，公運處顯名聲明的第一行加上「公車路線軌跡（GetBusShape）」，`docs/data-sources.md`、頁尾與健檢卡三處同一段，`docs/data-sources.md` 授權那一節的資料集表多一列。資料集頁面與授權在任務 1.2 查證；2026-10-24 先查到 data.gov.tw/dataset/160167「臺北市公車路線軌跡」，提供機關是臺北市公共運輸處，授權是政府資料開放授權條款第 1 版。健檢卡不讀路線軌跡，但它逐字收錄這段聲明，所以卡上的第一行也會多這一支；卡的數字與五個檢查檔不變。
- **資料限制**補一句：路線圖畫的是公運處登記的路線軌跡，不是 GPS 量到的，臨時改道、繞路不會出現在圖上。
- **詞彙表**新增「路線軌跡」一條：定義、在資料裡叫什麼（`GetBusShape.gz`、`route_day_shapes`）、邊界，以及不要用的說法（路線形狀、shape、單獨出現的「軌跡」；指車機 GPS 時寫「GPS 軌跡」）。

## Non-Goals

- 畫任何 GPS：單一車牌的軌跡（turnaround-map 的非目標、`docs/use-cases.md` 第 11 項），或把多台車的 GPS 聚成「實際行經路線」。GPS 只拿來驗證路線軌跡，驗證寫在這份 proposal 與真資料驗收裡。
- 自動比對 GPS 與路線軌跡、在頁面上報吻合度：等於定一個新指標，另開 change。
- 在圖上畫沿線每一站、靠近捷運的站或路段、車上人數：02-route-stop-sequence 的站序卡「不標示靠近捷運、車上人數」照舊，沿線的數字在載客那張卡。
- 畫 251 的線來跟 251區 比對：route-251-pages 的決定「251區 當成獨立的路線，不跟 251 配對」。
- 用路線軌跡算「軌跡長度」的捷運重疊：zhongshan-mrt-overlap 的非目標，還缺捷運路線的線。
- 補 GetRoute、GetStop、GetPathDetail 的顯名，以及把聲明跟程式讀的 feed 綁在一起的測試：01-bus-feeds-attribution 做，這裡只把 GetBusShape 加進同一行。
- 附屬路線各自的軌跡（`SubRouteID` 不是 -1 的列）、307 一頁兩個路線 Id 怎麼畫、265區 的三重與大南兩種走法對到哪一條軌跡：等加那些路線的 change。
- 改端點地圖畫什麼、改底圖來源與 `config/map.yml`、改站序清單本身、首頁的地圖。

## Capabilities

### New Capabilities

- `route-shape`: 路線軌跡從靜態快照進衍生表的規則（取哪幾列、怎麼轉、缺檔與壞資料怎麼辦）、頁面取哪一天的軌跡、路線圖畫什麼、回應裡的資料形狀與不含車牌、按需載入與退路。

### Modified Capabilities

- `route-page`: Stop sequence block（02-route-stop-sequence 新增的）在清單上方多一張路線圖；Data limitations on the page 多一句。
- `derived-tables`: Derived export 多跑 `analysis/route_shape.sql`、多寫 `shapes.csv`；Replace one route day atomically 多一張 `route_day_shapes`。
- `site-layout`: Attribution footer on every page 以 01-bus-feeds-attribution 的版本為底，聲明第一行點名的公運處 feed 多 GetBusShape（Every bus feed named 的例子多一列），頁尾不另起一行。
- `turnaround-map`: Map budget 改成量「共用的地圖函式庫 chunk 加上各自的繪圖 chunk」，涵蓋端點地圖與路線圖；新增 Map gestures（兩種地圖的滾輪與觸控手勢照 Google 地圖）與 Map full screen（兩種地圖的全螢幕按鈕）。

## Impact

- **前置與順序**：這個 change 用 turnaround-map 的 `MapTiles`、Leaflet 與 `endMap`，圖放在 02-route-stop-sequence 的站序卡裡，顯名照 01-bus-feeds-attribution 的做法。五份 delta 的底：route-page 的 Stop sequence block 以 02-route-stop-sequence 為底，Data limitations on the page 以 turnaround-map 為底；site-layout 以 01-bus-feeds-attribution 為底；turnaround-map 以 turnaround-map 為底；derived-tables 以 turnaround-facilities 為底。turnaround-facilities 與 turnaround-map 已在 2026-10-24 archive；還要等 01-bus-feeds-attribution archive、02-route-stop-sequence 的站序區塊 apply 之後才 apply；archive 順序是 turnaround-facilities → turnaround-map → 01-bus-feeds-attribution → 02-route-stop-sequence → 03-route-shape-map。site-easter-eggs 也修改 site-layout 的 Attribution footer on every page（加上 `public/` 底下靜態錯誤頁的例外），它若比這個 change 先 archive，這裡的 delta 要併進那段例外。apply 前先跑 `/spectra-drift 03-route-shape-map`。
- **新增**：db/migrate 底下建 `route_day_shapes` 的 migration、app/models/route_day_shape.rb、analysis/route_shape.sql、app/models/route_page/route_shape.rb、app/components/route_map_component.rb 與同層的 .html.erb、.yml、app/frontend/route_map/runtime.js、app/frontend/maps/base_map.js、spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz（路線 9001 兩個方向）、spec/analysis/route_shape_spec.rb、spec/models/route_page/route_shape_spec.rb、spec/components/route_map_component_spec.rb、spec/system/route_map_spec.rb、spec/factories/route_day_shapes.rb。
- **修改**：analysis/derived_export.sql、analysis/README.md、app/models/route_day_loader.rb、app/models/route_day.rb、db/schema.rb、app/components/stop_sequence_component.html.erb、app/views/routes/show.html.erb、app/frontend/entrypoints/application.js、app/frontend/end_map/runtime.js、app/frontend/stylesheets/application.css、app/components/attribution_component.yml、app/components/data_limitations_component.yml、bin/health-card（只有 `ATTRIBUTION` 的第一行）、docs/data-sources.md、docs/spectra/LANGUAGE.md、spec/analysis/attribution_spec.rb、spec/analysis/derived_export_spec.rb、spec/models/route_day_loader_spec.rb、spec/requests/routes_spec.rb、spec/fixtures/analysis/README.md、config/locales/tw.yml、config/locales/en.yml、app/components/application_component.rb、app/components/end_map_component.html.erb、spec/components/end_map_component_spec.rb、spec/system/end_map_spec.rb。端點地圖的 spec/system/end_map_spec.rb 在抽出共用的載入流程與 Leaflet 設定時（任務 4.1）不改、要照舊全過，用來確認端點地圖的行為不變；地圖手勢（任務 4.5）才為端點地圖加一個例子。
- **資料**：三條路線已經載入的日子要重跑 `derived:load` 才有軌跡。每條路線每天兩列，2026-10-24 的快照裡三條路線每個方向 205 到 266 個點（量到的）。
- **回應大小**：路線圖的 JSON 約 10 KB（估計：約 470 個點 × 每點約 20 個字元，驗收時量）。
- **執行期**：多一張圖的圖磚。桌機上站序卡在第一個畫面附近，打開頁面時多半就會載入（使用者 2026-10-24 接受）。
- **資料限制與假設**：路線軌跡是登記的、不是量到的，所以不牽涉車不等於人、刷卡率、漏站、跨小時重複；GPS 只拿來驗證，數字見 Why 的表。
