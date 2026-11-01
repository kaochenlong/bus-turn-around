## Context

首頁「有頁面的路線」由 `HomePage::RouteList` 與 `RouteListComponent` 畫：卡片照 `config/route_page.yml` 的順序，每條路線最新的路線日用一個查詢讀、停車端的數字用另一個查詢（`HomePage::StopEndFigures`）讀；規格 `home-page` 的「Route list」與詞彙表「首頁」都寫明卡上放且只放一個數字（`share-preview-home-figure` 的決定「首頁每張路線卡放每個停車端最新一天的不到 15 分鐘比例與筆數」）。`share-preview-home-figure` 把「首頁的卡排序、篩選、搜尋、排行榜」列為它的非目標但沒有寫理由，是那個 change 的範圍限制，不是否決。

行政區在資料裡不存在：原始檔與 19 支靜態 feed 都沒有這個欄位，`GetStop.gz` 的 `address` 只有路名。能用的是座標：`GetStop.gz`（JSON 頂層鍵 `BusInfo`）每個站牌一列，有 `stopLocationId`、`longitude`、`latitude`（字串）；衍生表 `route_day_stops` 也存了每站的經緯度與 `stop_location_id`。內政部國土測繪中心的「鄉鎮市區界線(TWD97經緯度)」（data.gov.tw/dataset/7441，政府資料開放授權條款第 1 版，2026-11-02 查的）是 TGOS 的 SHP 壓縮檔 `https://www.tgos.tw/tgos/VirtualDir/Product/3fe61d4a-ca23-4f45-8aca-4a536f40f290/鄉(鎮、市、區)界線1140318.zip`，裡面要用的是 `TOWN_MOI_1140318.shp`、`.shx`、`.dbf`、`.prj`（UTF-8，欄位 `COUNTYNAME`、`TOWNNAME`），另外還有檔名是 Big5 的成員，macOS 的 `unzip` 解到那個檔會出錯。2026-11-01 用 DuckDB 的 spatial 延伸（`LOAD spatial`、`ST_Read`、`ST_Within`、`SET geometry_always_xy = true`）判過：大安區面積算出 11.33 km²，國父紀念館、臺大醫院判在區外，捷運忠孝復興站、大安森林公園判在區內。這台筆電的 DuckDB 1.5.6 已經裝了延伸；mini 是 DuckDB 2.0.0、還沒裝，`INSTALL spatial` 要連網一次，之後 `LOAD` 不用網路。

七條路線的站位分佈（2026-10-22 靜態快照，站位數的占比，量到的）：

| 行政區 | 經過（至少一個站位） | 站位一成以上 |
| --- | --- | --- |
| 臺北市士林區 | 中山幹線 46% | 中山幹線 |
| 臺北市中山區 | 中山幹線 15、復興幹線 23、307 10 | 三條都是 |
| 臺北市中正區 | 七條全部（1% 到 27%） | 中山幹線、251、235、22 |
| 臺北市萬華區 | 中山幹線 21、307 12、235 5 | 中山幹線、307 |
| 臺北市大安區 | 235 30、復興幹線 46、22 38、251 5、251區 5 | 235、復興幹線、22 |
| 臺北市信義區 | 22 36 | 22 |
| 臺北市文山區 | 251 64、251區 77、復興幹線 17 | 三條都是 |
| 臺北市松山區 | 307 18、復興幹線 7 | 307 |
| 新北市新莊區、三重區 | 235 45、235 8 | 新莊區 235 |
| 新北市深坑區、板橋區、中和區 | 251 14、251區 16；307 26、24 | 都算 |

外部快照的既有做法：`MrtExitsSnapshot` 這類 class 接一個可注入的 fetcher、檢查內容、先寫 `.partial` 再改名；`NewestSnapshot` 取資料夾裡檔名日期最新的 `<YYYY-MM-DD>.csv`；`RouteDayLoader` 要求捷運出入口與公廁快照都在，缺了那一天失敗並指名 task，`route_days` 記下用了哪一天的快照；`bin/push-derived` 靠外鍵從 `route_days` 找衍生表，新表只要參照 `route_days` 就會自動帶上；規格 `derived-tables`「Stop speed rows stored with the route day」寫明 `stops.csv` 以 `shape_meters` 結尾。`nightly-derived-load` 的決定「mini 的 checkout 每小時跟 origin/main，外部快照在 mini 另抓一份」：新快照也要在 mini 有一份。首頁的 JavaScript 走 Alpine，元件在 `app/frontend/entrypoints/application.js` 用 `Alpine.data` 登記（`homeHero`、`timetable`、`dayDispatch`），瀏覽器行為用 `:js` 的 system spec 測、純函式用 Vitest（`yarn test:js`）。

進行中的 `daan-top-three-routes`（5/6，等使用者驗收）也改 `docs/spectra/LANGUAGE.md`，這個 change 在它歸檔並 commit 之後才 apply。

## Goals / Non-Goals

**Goals:**

- 每個站位判到哪一縣市、哪一鄉鎮市區，寫成外部快照；每晚載入時每一站帶行政區、每個路線日每一區帶站位占比與是否達門檻。
- 首頁「有頁面的路線」有行政區下拉選單，選了只留站位一成以上在那一區的路線，網址可以帶著分享，沒有 JavaScript 時全部顯示。
- 頁尾顯名聲明、資料來源文件、analysis 的 README、詞彙表跟著補。
- 用七條路線的真資料驗收一次。

**Non-Goals:**

- 用「經過任一站位」或停車端所在的區當「屬於那一區」：前者讓中正區對到七條全部，後者讓 235 只剩新莊區。
- 天母這類不是行政區的地名，以及用里界湊地名：沒有誰說得準天母的邊界。
- 卡片上顯示占比或任何第二個數字：`share-preview-home-figure` 的「首頁每張路線卡放每個停車端最新一天的不到 15 分鐘比例與筆數」照舊。
- 路線頁顯示行政區、站序區塊標出區界：之後再說。
- 載入時直接做空間判斷：mini、每台跑測試的機器與 CI 都要裝 spatial 延伸。
- mini 上自動更新這份快照、把快照送上 mini 的自動化：跟其他三份快照一樣由使用者處理。
- 新站位出現時自動重跑 task：快照不定期重跑，對不到的站當沒有行政區。
- 多選、排序、搜尋、排行榜。
- 站位剛好落在區界上的判定精度：點在哪個多邊形裡就算哪一區。

## Decisions

### 站位的行政區來自 external:stop_districts 寫的快照，spatial 延伸只在跑 task 的機器

新 rake task `bin/rails external:stop_districts`（`StopDistrictsSnapshot`）：用可注入的 fetcher 下載區界的 zip，用 `rubyzip` 只解出檔名符合 `TOWN_MOI_<版本>.shp`、`.shx`、`.dbf`、`.prj` 的成員到暫存目錄（`.cpg` 有就一起），其他成員（含 Big5 檔名的）不碰；讀資料根目錄裡目錄名最新的 `static/<台北日>/GetStop.gz`；用 `AnalysisRun.run`（`stages: false`，所以只接 `params.sql` 與這支檔）跑新的 `analysis/stop_district_snapshot.sql`，變數 `shapefile_path`、`stops_path`、`output_path`：`LOAD spatial`、`SET geometry_always_xy = true`，區界用 `ST_Read` 讀，站位是 `GetStop.gz` 每個 `stopLocationId` 取站牌 `Id` 最小那一列的經緯度，`ST_Within(ST_Point(lon, lat), geom)` 判在哪個多邊形裡，`COPY` 成 `stop_location_id,county,town` 的 CSV，照 `stop_location_id` 遞增。Ruby 再檢查寫出的檔（表頭、每列三欄、Id 是嚴格遞增的整數、縣市與鄉鎮市區都不是空的、至少一列），通過才從 `.partial` 改名成 `external/stop-districts/<今天的台北日>.csv`。印一行「<路徑>：站位 N 個，判到行政區 M 個，判不到 K 個（區界檔 TOWN_MOI_1140318）」。`LOAD spatial` 失敗時印「需要 DuckDB 的 spatial 延伸：先在這台機器跑 duckdb -c "INSTALL spatial"」，結束碼非零，不寫檔。`rubyzip` 目前是 bundle 裡的間接相依（3.7.0），改成 `Gemfile` 明寫。

理由：spatial 延伸要連網安裝、跟 DuckDB 版本綁；只在跑 task 的機器要它，每晚載入、`derived:load` 的測試與 CI 都只讀 CSV，跟捷運出入口快照一樣。

替代方案：

- 載入時直接判（`derived:load` 的 SQL 讀 shapefile）。否決：mini 與每台跑測試的機器都要裝延伸，規格 `derived-tables` 的測試也得依賴它。
- 行政區用手抄進 `config/route_page.yml`。否決：是算得出來的事實，全路網幾百條抄不動。
- 讀 `GetStopLocation.gz`（每個站位一列）。否決：fixture 與載入都已經讀 `GetStop.gz`，它每個站牌都有座標，同一站位取站牌 `Id` 最小那一筆就是同一個點。

### 屬於那一區是站位一成以上：門檻 district_min_share_percent 在 params.sql，每晚算進 route_day_districts

新的 `analysis/stop_districts.sql`（載入時跑，`bin/health-card` 不跑）讀變數 `stop_districts_path` 的快照與第 10 階段的 `stops`：每一站用 `stop_location_id` 對快照，`district` 是縣市加鄉鎮市區（臺北市大安區），對不到或沒有站位的站是 NULL。`route_day_districts` 只看頁面路線（`route_id` 等於 `route_id` 變數）的站：分母 `n_total` 是頁面路線兩個方向不同站位的數目（有 `stop_location_id` 的，不管對不對得到行政區），每一區的 `n_locations` 是其中判到那一區的站位數，`share` 是 `n_locations / n_total` 取三位小數，`qualifies` 是 `n_locations * 100 >= n_total * district_min_share_percent`。`analysis/params.sql` 加 `SET VARIABLE district_min_share_percent = 10;`，附理由。成員路線（307 的 19108）的站帶 `district` 但不進占比。

理由：「經過」讓中正區對到七條全部，等於沒篩；停車端所在區太窄。用整數比較是因為 `70 * 0.1` 在浮點數是 7.000000000000001，7 個站位會被判成不到一成；百分比整數相乘沒有這個問題。分母用全部站位而不是「判得到的站位」，是因為對不到的站（新站、不在快照裡）不該把別區的占比撐高。

替代方案：里程占比（路線軌跡切在各區的長度）。否決：要把軌跡跟多邊形相交，複雜得多，而且乘客與站長在意的是站，不是公里數。

### 快照是每晚載入的必要條件，缺了那一天失敗

`RouteDayLoader` 用 `NewestSnapshot` 找 `external/stop-districts/` 最新的檔，缺了就失敗，訊息指名 `bin/rails external:stop_districts`，查的順序在公廁快照之後、辦公日曆之前；`route_days` 新欄 `stop_districts_day` 記用了哪一天的快照，這個 change 之前載入的路線日是 NULL。

理由：跟捷運出入口、公廁一樣的規則，載入的結果才不會一半有行政區、一半沒有而看不出是缺檔還是真的對不到。

替代方案：快照可有可無，缺了就全部 NULL。否決：理由如上。

### 行政區的名稱：臺北市不帶市名，其他縣市帶

頁面上顯示與網址裡用的名稱：縣市是臺北市時只寫鄉鎮市區（士林區），其他縣市寫縣市加鄉鎮市區（新北市新莊區）。選單的順序：臺北市的區在前，其他縣市照縣市名、再照區名，排序在程式碼裡用字元碼位比較（Ruby 的字串排序），不交給資料庫的 collation；同一順序也用在網址對不上選項時的處理。

理由：這是臺北市的網站，加市名只會讓每一個選項都多三個字；新北市的區帶市名才分得出中正區（臺北市）跟中和區。字元順序不好看但穩定，照路線數排會天天變、連結轉給人之後對不上。

### 首頁的篩選在瀏覽器做，網址帶 district，沒有 JavaScript 時全部顯示

伺服器照舊輸出七張卡，每張卡的 `li` 帶 `data-districts`（達門檻的區的名稱，用空白隔開，沒有就是空字串），並且已經套好預設的區：不在那一區的卡帶 `hidden`、筆數那一行寫好；`data-section="routes"` 那一節掛 Alpine 元件 `districtFilter`（`app/frontend/route_list/district_filter.js`，在 `application.js` 用 `Alpine.data` 登記）。元件初始化時讀網址的 `district` 參數，是選項之一就選它並套用，不是就用伺服器選的預設，初始化不改網址；選單改變時才用 `history.replaceState` 把網址改成 `?district=<名稱>`；套用就是把 `data-districts` 不含那個名稱的卡藏起來（`hidden`），並重寫筆數那一行。沒有 JavaScript 時就停在預設的區。純函式（網址參數對選項、卡片符不符合）用 Vitest 測，畫面用 `:js` 的 system spec 測。

理由：資料都在伺服器算好、瀏覽器只決定顯示哪幾張，跟 `turnaround-map`「資料由伺服器算好寫進回應，前端只畫」同一個分工；網址帶參數，站長才能把「士林區的路線」轉給人。

替代方案：送表單給伺服器、照 `?district=` 重畫。否決：每選一次重載一頁，而且沒有比較簡單。

### 選單放標題列右側，只列達門檻的區，底下一行筆數；卡片不變

「有頁面的路線」的標題那一列放 `<label for="district-filter">行政區</label>` 與 `<select id="district-filter" name="district">`，選項是至少有一條路線在它最新一天達門檻的區，照上面的順序，沒有「全部」；一進來就選著預設的區（`HomePage::RouteDistricts::DEFAULT` 中山區，不在選項裡就第一個），清單底下一行 `data-district-count` 寫「中山區：3 條」，數的是顯示中的卡片數。卡片的內容與順序不變，沒有占比、沒有第二個數字。

理由：篩選只影響「哪幾張」，不影響卡上的數字，`share-preview-home-figure` 的決定照舊；筆數那一行在卡片外面，數的是清單的卡片數，不是量出來的指標，規格「No percentage outside the route list」仍成立。

2026-11-02 使用者看過畫面後改了兩處：選單不靠右，接在標題右邊靠左放（同一列，置中對齊）；清單的標題從「有頁面的路線」改成「公車路線」（en 是 Bus routes）。規格只說選單在標題那一列，不用改。同日再改：不要「全部」，一進來只看一區，預設中山區（選項裡沒有中山區時取第一個）；伺服器就把預設套好（不在那一區的卡帶 `hidden`、筆數那一行寫好），沒有 JavaScript 也停在預設的區；元件初始化只讀網址、不改網址，換區才寫 `?district=`。規格「Route list district filter」跟著改。

替代方案：選項文字帶路線數「士林區（1）」。否決：選項文字每天跟著資料變，而且跟筆數那一行重複。

### 還沒有行政區的路線日：整頁沒有就一句話取代選單，部分沒有就另一行

一條路線「有行政區」看它最新那一天的 `route_days.stop_districts_day` 是不是有值。全部有資料的路線都沒有時，標題列不放選單，放一句 `data-no-districts`「這幾天的資料還沒有行政區」；有的有有的沒有時選單照放，筆數那一行加「，另有 N 條的資料還沒有行政區」，那 N 張卡在任何一區底下都藏著。沒有資料的路線（虛線卡）不算在 N 裡。

理由：正式站重算之前會有這個過渡期，頁面要說清楚是資料還沒算，不是那一區沒有路線。

### 顯名聲明與資料來源文件多一條

`app/components/attribution_component.yml` 加一行「內政部國土測繪中心 鄉鎮市區界線(TWD97經緯度)（data.gov.tw/dataset/7441），依政府資料開放授權條款第 1 版釋出」，tw 與 en 同一句；`docs/data-sources.md` 的外部資料表加一列（用途、來源、狀態與 task）；`analysis/README.md` 的衍生表匯出一節加 `stop_districts.sql` 與 `stop_district_snapshot.sql` 兩列、變數與快照的說明。

### 詞彙表新增「行政區」

`docs/spectra/LANGUAGE.md`「指標」或資料那一群底下加「行政區」：定義（站位用座標對內政部鄉鎮市區界線判到的縣市與鄉鎮市區；路線「屬於」一區是頁面路線站位一成以上在那一區）、在資料或程式碼裡（快照 `external/stop-districts/`、`route_day_stops.district`、`route_day_districts`、`district_min_share_percent`）、邊界（臺北市不帶市名、其他縣市帶；天母是士林區的一部分；成員路線的站不進占比；對不到的站沒有行政區）、不要用（區域、地區、分區，以及天母這類地名當作篩選項）。「首頁」的定義補上篩選，邊界的「放且只放一個數字」補一句：篩選後那一行的筆數是清單裡卡片的數目，不是量出來的指標；「站牌與站位」的邊界補一句站位可以判到行政區。

### 測試：spatial 的 SQL 只在裝了延伸的機器上跑，沒裝就 pending

`analysis/stop_district_snapshot.sql` 的測試先試 `LOAD spatial`，失敗就把那幾個例子標 pending，理由印出「這台機器沒有 DuckDB 的 spatial 延伸」；其餘測試（class 的下載、解壓、檢查、改名用注入的 runner；載入的對照與占比讀 fixture CSV）照常跑。測試用的區界是一個很小的 shapefile fixture（兩個多邊形，`測試區` 與 `甲區`，縣市 `臺北市` 與 `新北市`），用 DuckDB spatial 的 GDAL 輸出產生一次後放進 `spec/fixtures/analysis/external/town-boundaries/`，怎麼產生寫在 fixture 的 README。

理由：延伸裝不裝是機器的事，不能讓整套測試依賴它；但 SQL 本身要有測試，所以在能跑的機器上跑。

### 真資料驗收：筆電寫快照、載入七條 2026-10-22、選單與分佈表相同

`TURNAROUND_DATA` 指向本機備份跑一次 task 寫出快照，`bin/rails derived:load ROUTE=<Id> DAY=2026-10-22` 載入七條，開發環境的首頁選單列出的區、每一區選出來的路線，要跟 Context 那張表「站位一成以上」那一欄相同；`route_day_districts` 的占比跟表上的百分比差在四捨五入內。結果寫進這份 design 新的一節「真資料驗收」。

## Implementation Contract

- **快照 task**：`TURNAROUND_DATA=<資料根目錄> bin/rails external:stop_districts`。`DOWNLOAD_URL` 存百分比編碼後的網址（`HttpFetcher` 用 `URI()`，不收非 ASCII 字元）；下載走共用的 `HttpFetcher`，不另外設 User-Agent。輸出檔 `external/stop-districts/<今天的台北日>.csv`，UTF-8、無 BOM、LF，表頭 `stop_location_id,county,town`，一列一個判得到的站位，照 `stop_location_id` 遞增，判不到的站位不寫。成功印一行路徑與三個數字並回 0；下載不是 HTTP 200、zip 裡沒有 `TOWN_MOI_*` 的四個成員、資料根目錄沒有任何 `static/<日>/GetStop.gz`、`LOAD spatial` 失敗、寫出的檔不過檢查，都印原因、回非零、不留檔也不留 `.partial`。
- **載入**：`RouteDayLoader` 多要一份快照（`NewestSnapshot`，目錄 `external/stop-districts`，標籤「站位行政區」）；變數 `stop_districts_path`、`stop_districts_day`；`analysis/stop_districts.sql` 接在 `stop_speeds.sql` 之後、`derived_export.sql` 之前，建 `stop_districts`（快照）、`stop_district_names`（每站的 `district`）、`route_day_districts`（`county`、`town`、`n_locations`、`n_total`、`share`、`qualifies`）。`derived_export.sql`：`stops.csv` 的欄位是 `go_back, seq, stop_name, latitude, longitude, nearest_exit_name, nearest_exit_meters, route_id, stop_location_id, district, shape_meters`（`district` 在 `shape_meters` 之前，所以「以 `shape_meters` 結尾」不變）；新檔 `districts.csv` 欄位 `county, town, n_locations, share, qualifies`，照 `n_locations` 遞減、`county`、`town`；`route_day.csv` 在 `public_toilets_day` 之後多 `stop_districts_day`。
- **衍生表**：migration 加 `route_day_stops.district`（string，可空）、`route_days.stop_districts_day`（date，可空）、新表 `route_day_districts`（`route_day_id` 外鍵、`county`、`town`、`n_locations`、`share`、`qualifies`，`(route_day_id, county, town)` 唯一）；model `RouteDayDistrict`，`RouteDay has_many :districts`；loader 的 `STAGING` 與 insert 跟著加，列數不符就失敗；`RouteDayLoader.summary` 那一行多「、行政區 N 區」。
- **首頁**：`HomePage::RouteDistricts` 用一個敘述讀所有最新路線日裡 `qualifies` 的列；`HomePage::RouteList::Entry` 多 `districts`（名稱陣列，照決定的順序）與 `districts_known`；`RouteList` 多 `district_options`（去重後排序）、`default_district` 與 `n_unknown`。`RouteListComponent`：`section[data-section="routes"]` 帶 `x-data="districtFilter"`；標題列的 label 與 select（`id="district-filter"`、`name="district"`、`data-district-filter`）；每張卡 `li[data-districts]`；`p[data-district-count]`；`p[data-no-districts]`。文案鍵在 `route_list_component.yml`：`district_label`「行政區」、`district_count`「%{district}：%{count} 條」、`district_unknown`「，另有 %{count} 條的資料還沒有行政區」、`no_districts`「這幾天的資料還沒有行政區」，en 另寫。
- **JavaScript**：`app/frontend/route_list/district_filter.js` 輸出 `districtFilter`（Alpine 元件）與純函式 `districtFromSearch(search, options)`、`matches(districts, district)`；網址參數用 `encodeURIComponent` 寫、`URLSearchParams` 讀。
- **失敗模式**：缺快照那一天失敗、指名 task；`districts.csv` 列數跟寫入不符失敗；網址參數不是選項就當「全部」；沒有 JavaScript 時全部顯示。
- **驗收**：`spec/models/stop_districts_snapshot_spec.rb`、`spec/analysis/stop_district_snapshot_spec.rb`（可 pending）、`spec/analysis/stop_districts_spec.rb`、`spec/analysis/derived_export_spec.rb`、`spec/models/route_day_loader_spec.rb`、`spec/models/derived_push_command_spec.rb`、`spec/components/route_list_component_spec.rb`、`spec/requests/pages_spec.rb`、`spec/system/home_district_filter_spec.rb`、`app/frontend/route_list/district_filter.test.js`；`bin/rails parallel:spec`、`yarn test:js`、`bin/rubocop`、`bin/brakeman` 都過；真資料驗收寫進 design。
- **範圍**：在範圍內的是上面列的檔、fixture、文件與詞彙表、開發資料庫七條 2026-10-22 的重載。不在範圍內的是路線頁、mini 與正式站的操作（快照複製、重算、部署）、卡片的內容。

## Risks / Trade-offs

- [TGOS 的網址含中文與頓號] → `DOWNLOAD_URL` 用百分比編碼的形式，task 的測試用那個常數本身。
- [TGOS 擋 Ruby 的預設 User-Agent] → 2026-11-02 用 `curl -A Ruby` 對那個網址試過，回 HTTP 206（量到的）；真資料驗收再用 task 本身下載一次確認。要是擋了，改 User-Agent 會動到共用的 `HttpFetcher`，得另外決定。
- [區界檔換版，站位判的區變了] → 快照檔名帶日期、`route_days` 記快照日；重跑 task 之後在 mini `--recompute`。
- [新站位不在快照裡] → 那一站沒有行政區、不進任何一區的分子，分母照算；task 印判不到的數量，README 寫明不定期重跑。
- [快照還沒到 mini 就合併] → `bin/nightly-load` 每個路線日都失敗並印 task 名稱，每小時提醒；Migration Plan 把快照排在合併之前。
- [mini 沒有 spatial 延伸] → task 在筆電跑、把 CSV 複製過去就好；mini 要自己跑才裝。
- [Turbo 快取回到首頁時篩選狀態] → 元件初始化從網址讀，回頁時網址帶著參數就會重新套用；system spec 測一次上一頁。
- [選項與網址用中文] → 寫入用 `encodeURIComponent`、讀取用 `URLSearchParams`，system spec 用「新北市甲區」這種帶市名的值測。
- [與 daan-top-three-routes 同時改 LANGUAGE.md] → 等它歸檔並 commit 之後才 apply，開工先 `/spectra-drift`。
- [七條裡只有兩條以上才看得出篩選的用處] → 這是為全路網準備的；現在就能用士林區、文山區、新莊區各選出一兩條。

## Migration Plan

1. 筆電：`bundle install`（`rubyzip` 明寫）、跑 task 寫快照、`derived:load` 七條 2026-10-22、驗收。
2. 使用者把快照複製到 mini 的資料根目錄 `external/stop-districts/`（或在 mini `duckdb -c "INSTALL spatial"` 後自己跑 task）。
3. commit、push；部署 image（migration 跟著跑）；mini 拉到新版後 `bin/nightly-load --recompute --load` 重算七條所有路線日（七條十天約十分鐘，估的，照 2026-10-26 每個路線日 8.5 秒算）；重算之前首頁顯示「這幾天的資料還沒有行政區」。
4. 回滾：拿掉 `x-data` 與選單即可；新欄與新表留著不影響其他頁面。

## 真資料驗收

2026-11-02 照「真資料驗收：筆電寫快照、載入七條 2026-10-22、選單與分佈表相同」做的，`TURNAROUND_DATA` 指向本機備份。

- `bin/rails external:stop_districts`：用共用的 `HttpFetcher`（Net::HTTP 預設的 User-Agent）從 TGOS 下載成功，寫出 `external/stop-districts/2026-11-02.csv`：站位 5,376 個、判到行政區 5,376 個、判不到 0 個，區界檔 TOWN_MOI_1140318，整個 task 3.8 秒（量到的）。站位取自最新的靜態快照 2026-11-01。
- `bin/rails derived:load ROUTE=<Id> DAY=2026-10-22` 七條都成功，摘要那一行以行政區的區數結尾：中山幹線 4 區、251 4 區、251區 4 區、307 6 區、235 5 區、復興幹線 5 區、22 3 區；2026-10-22 的站序沒有任何一站對不到行政區。
- 七條的 `route_day_districts`（站位數、占比，`*` 是達門檻），跟 Context 那張表「站位一成以上」那一欄逐條相同，占比只差四捨五入（表上是 DuckDB 的 `round`，這裡是 Ruby 的，差在 0.5 的進位）：

| 路線 | 頁面路線的站位 | 行政區（站位數、占比） |
| --- | --- | --- |
| 中山幹線 | 84 | 士林區 39、46%*；萬華區 18、21%*；中正區 14、17%*；中山區 13、16%* |
| 251 | 110 | 文山區 70、64%*；中正區 19、17%*；新北市深坑區 15、14%*；大安區 6、6% |
| 251區 | 91 | 文山區 70、77%*；新北市深坑區 15、17%*；大安區 5、6%；中正區 1、1% |
| 307（16111 的站） | 127 | 新北市板橋區 33、26%*；新北市中和區 31、24%*；松山區 23、18%*；萬華區 15、12%*；中山區 13、10%*；中正區 12、9% |
| 235 | 129 | 新北市新莊區 58、45%*；大安區 39、30%*；中正區 16、12%*；新北市三重區 10、8%；萬華區 6、5% |
| 復興幹線 | 70 | 大安區 32、46%*；中山區 16、23%*；文山區 12、17%*；中正區 5、7%；松山區 5、7% |
| 22 | 56 | 大安區 21、38%*；信義區 20、36%*；中正區 15、27%* |

307 中山區的 13／127 剛好是 10.2%，整數比較判達門檻，跟「至少一成」的定義相符。不一致的項目：無。

開發環境（Rails 3000 加 Vite 5173，headless Chrome 1400 寬）看過的首頁，截圖在 `tmp/district-screens/`（不進 repo）。中山幹線最新的一天是開發庫早先載入的 2026-10-25，先把那一天重載一次才有行政區（重載後 4 區）：

- 選單在「有頁面的路線」標題列右側，選項依序是 全部、中山區、中正區、信義區、士林區、大安區、文山區、松山區、萬華區、新北市中和區、新北市新莊區、新北市板橋區、新北市深坑區：臺北市的區在前、照區名的字元碼位，新北市的帶市名、照區名。七張卡的 `data-districts` 跟上表達門檻的區一致，`data-unknown` 是 0。
- `/?district=大安區`：選單選著大安區，只剩 235、復興幹線、22 三張，底下一行「大安區：3 條」，藏起來的卡不留空格。
- `/?district=新北市新莊區`：只剩 235，一行「新北市新莊區：1 條」。
- 頁尾多了內政部國土測繪中心那一行。

## Open Questions

- 無。
