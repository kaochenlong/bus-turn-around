## Context

路線頁 `/routes/:route_id` 現在依序是摘要、區塊導覽、折返停留那張卡（分佈圖加表）、來回與週期、換休息試算、行駛時間、載客那張卡（沿線人數圖、捷運重疊、載客剖面表）、資料限制。每一塊是一個查詢物件（`app/models/route_page/`）配一個 ViewComponent，查詢物件拿 `RoutePage::Coverage#route_days` 回的那幾天，讀 `derived:load` 寫進 PostgreSQL 的衍生表。`spec/requests/routes_spec.rb` 用 `data-section` 的順序斷言十個區塊，區塊導覽斷言七個連結，`SectionNavComponent::SECTIONS` 是 `layovers cycles buffer runtimes load mrt limits`。「來回與週期」是 run-time-vs-cycle 在 2026-10-24 加的，已 archive 進 `docs/spectra/specs/route-page/spec.md`，Page content、Section links 與 Data limitations on the page 三條都有它（2026-10-24 核對）。

已核對的事實（2026-10-23）：

- `derived:load`（`app/models/derived_load_command.rb` 檢查可算條件，`app/models/route_day_loader.rb` 寫入）每一天先跑 `params.sql`、編號階段檔，再接 `analysis/mrt_overlap.sql` 與 `analysis/derived_export.sql`，匯出五個 CSV，在一個交易裡刪掉那一天再寫入。捷運出入口快照用資料夾裡檔名日期最新的一份，日期存進 `route_days.mrt_exits_day`；沒有快照時那一天失敗，訊息指向 `bin/rails external:mrt_exits`。辦公日曆同一套做法。
- `bus_data` 的原始檔跟另外兩支 feed 同一種格式，每筆有 `BusID`、`RouteID`、`GoBack`、`Longitude`、`Latitude`、`Speed`、`DutyStatus`、`BusStatus`、`DataTime`、`_fetched_at`，欄位都是字串。2026-10-23 的真資料：一個小時檔壓縮後約 4.5 MB、解壓後約 44 MB；抽樣 20,000 筆裡 `Speed` 是 `"0"` 的有 8,986 筆（量到的）。`analysis/10_load.sql` 只讀 `bus_event` 與 `bus_seat_event`，`input_files`、`load_counts` 與 `quality.csv` 都只認這兩支。
- `analysis/30_layovers.sql` 的 `layovers` view 每列有 `trip_id`、`next_trip_id`、`bus_id`、`route_id`、`go_back`、`end_time`、`next_start_time`、`minutes`，`go_back` 是結束那趟的方向，所以「一端」在資料裡就是「結束在那一端的趟次方向」，跟 `turnaround-ends` 一致。
- `config/route_page.yml` 三條路線的停車端都是人看 GPS 驗的：251 的福安居一那一端 30 筆折返停留裡九成 GPS 在較近那個站牌 136 公尺內，每筆最長靜止中位數 14.4 分鐘；251區 同一端 38 筆、112 公尺內、3.5 分鐘；中山幹線職能發展學院二的查證寫在 zhongshan-turnaround-ends 的 design。這些數字是這個 change 的位置定義要重現的東西。
- `RoutePage.ends(route_id)` 對設定裡沒有的路線會丟 `RoutePage::Ends::InvalidConfiguration`（`from_config(nil)`）。現在 `derived:load` 不讀設定，所以路線可以先載入、看過數字、人工查證兩端之後才寫進設定。
- `csv` 從 Ruby 3.4 起是 bundled gem，Gemfile 沒有列它，`bundle exec ruby -e 'require "csv"'` 載不到。`bin/health-card` 的註解寫明它在 bundler 底下也跑、Gemfile 沒有 csv，而它自己不用 csv。

公廁資料來源在 2026-10-24 從臺北市環保局的公廁點位（data.gov.tw/dataset/138798）換成環境部的全國公廁建檔資料（data.gov.tw/dataset/30794），換的時候還沒有任何一條任務開始。已核對的事實（2026-10-24）：

- 有路線頁的三條路線裡，251 與 251區 的停車端福安居一在新北市深坑區（2026-10-23 靜態快照的座標 24.998289, 121.614805），下一條要加的 307 與 307西藏三民 一端是板橋的臺北客運板橋前站(藝文)（25.022559, 121.452109）。臺北市檔對這兩個點最近的一處分別在 2,549 與 3,701 公尺外，300 與 500 公尺內都是 0 處；它的座標範圍涵蓋這兩個點，所以不會報錯，只會默默報 0。
- 全國檔沒有整份檔案，只有環境部資料開放平臺的 API `https://data.moenv.gov.tw/api/v2/fac_p_07`，`api_key` 跟著資料集頁的下載連結公開，三種格式各一把。一次最多回 1,000 列（`limit=2000` 也只回 1,000），用 `offset` 翻頁；`format=CSV` 回 UTF-8、LF、無 BOM，表頭 `county,areacode,village,number,name,address,administration,latitude,longitude,grade,type2,type,exec,diaper`。不帶排序翻頁不穩定：宜蘭的一列在不同頁出現 23 次，整份多 22 列、臺北市少 2 列；帶 `sort=number asc` 抓整份是 47 頁、46,006 列、13 到 16 秒、11.2 MB，`number` 不重複而且照字典序遞增，臺北市（county 63000）7,013 列、新北市（65000）6,143 列，22 個縣市都有。每列都有經緯度而且是數字，`name` 與 `address` 都不空，欄位裡沒有逗號、引號或換行；26 列的緯度在 121 附近、經度在 24 附近，看起來對調了。`filters=county,EQ,63000` 可用，`filters=address,LIKE,深坑` 回「系統發生錯誤」的 HTML。每月更新，這一份最後修改 2026-10-23。
- 一列是一間廁所，不是一處：`type` 是女廁所、男廁所、無障礙廁所、混合廁所、親子廁所、性別友善廁所；`type2` 是商業營業場所、文化育樂活動場所、交通、社福機構、集會場所、民眾洽公場所、公園、觀光地區及風景區、其他；`grade` 有特優級、優等級、普通級、不合格。新北市 6,143 列只有 2,224 個不同地址；同一地址各列的座標離它們平均位置最遠的距離，中位數 0 公尺、九成在 73 公尺內、最大 19 公里（登錄錯誤），1,367 個多列地址裡 112 個超過 100 公尺；名稱去掉「-女廁」這類尾綴之後同一地址仍有 395 個地址名稱不一致（例如鳶山簡易運動場與鳶山銅鐘同一地址）。
- 用各方向末站的座標量兩份檔的直線距離，「處」是不同地址：職能發展學院二（中山幹線停車端）全國檔 300 與 500 公尺內都是 2 處 33 間、臺北市檔 1 處；福安居一全國檔 300 公尺內 1 處 2 間（正洋加油站，200 公尺）、500 公尺內 9 處 28 間；板橋前站全國檔 300 公尺內 4 處 13 間、500 公尺內 9 處 22 間；莊敬里（307 另一端，松山）全國檔 300 公尺內 0 處、500 公尺內 4 處 9 間，臺北市檔 0 處與 3 處。
- 新北市列管公廁資訊（data.gov.tw/dataset/123792）6,151 列，中文欄位清單只有編號、鄉鎮、名稱、地址，沒有座標。
- `analysis/README.md` 記著 `read_json` 遇到空清單或 NULL 清單會報錯，所以當天有沒有小時檔要在跑 SQL 之前擋。
- 前端沒有地圖套件；首頁的 three.js 是 Alpine 元件按需載入的。這個 change 不碰前端 JS。

詞彙依 `docs/spectra/LANGUAGE.md`：折返點、末站、起站、折返停留、去返程、路線頁、衍生表、台北日、資料限制。「折返點位置」「靜止點」「折返點設施」與公廁的「間」「處」還不在詞彙表裡，這個 change 補進「起站、末站、折返點、調度站」那條並新增「折返點設施」一條。

## Goals / Non-Goals

**Goals:**

- 每條有路線頁的路線，每一端每天有一個可以重算、講得清楚的折返點位置，停車端來自車實際停的地方，開過去就走那一端以末站計。
- 每一端 500 公尺內的每一間公廁存進衍生表，不管那一端在哪個縣市；路線頁以地址併成處，報 300 公尺內幾處、最近一處幾公尺、有幾間，附清單，讓站長與司機看得出是哪一間。
- 位置旁邊帶三個查核數字，讀的人自己判斷這個位置可不可信。
- 公廁資料有固定的下載與存放方式，分頁抓的整份只在每一頁都對的時候寫，用到哪一份快照看得到。
- 兩端當天的靜止回報另外聚成約 20 公尺的格子存進衍生表，少於 3 台車的格子不存，給下一個 change 的地圖畫；這個 change 不顯示它。

**Non-Goals:**

- 地圖（另開 change `turnaround-map`，讀這次的位置、公廁與靜止格）；路邊大型車格位與公車停車場；調度站與路邊的區分；開放時段與能不能借用；步行距離。
- 任何「夠不夠」的判定或顏色；摘要的重點數字；健檢卡。
- 從折返停留或 GPS 推哪一端停車；其他路線；排程與部署；修改既有指標的定義。

## Decisions

### 折返點的性質留在設定，位置每晚從靜止點算出

兩端是停車還是開過去就走，照舊是 `config/route_page.yml` 裡人工查證的事實；這個 change 不推性質，只推位置，而且是用設定裡的性質決定哪一端推：停車端從 GPS 靜止點算，開過去就走那一端以末站計。這不翻 zhongshan-turnaround-ends 的決定「折返點的性質是逐路線查證後寫進設定的事實，不從資料推」，也不翻它的非目標「從折返停留分佈或 GPS 自動推哪一端停車」；那兩條講的是性質，這裡講的是位置。

位置是每晚算出來的，不是寫進設定的。討論時提過另一個做法：位置也跟性質一樣寫進設定，另附一個工具從 GPS 算出候選位置給人看；使用者選了每晚自動算。zhongshan-turnaround-ends 不自動推的理由是「自動推要先在幾條路線上看過它推得對不對」，這裡用三個每天存下來、頁面上也顯示的數字回應它：當天結束在這一端的折返停留筆數、其中至少有一筆靜止回報落在位置 150 公尺內的筆數、位置到末站的距離。第二個數字接近第一個、第三個數字不大，位置就是可信的；反過來讀的人也看得到。驗收時要在三條路線上對照人工查證的結果。

替代方案：位置寫進設定（人工步驟一條路線一次，業者改折返方式時沒有人會改，否決於使用者）；只用末站座標不碰 GPS（三條路線的停車端 GPS 都在末站 140 公尺內，但 300 公尺的問題差 140 公尺就差很多，而且回場的路線會錯，否決）。

### 靜止點與位置的定義：速度 0 的 GPS 回報，50 公尺內最密集處的平均

停車端當天的每一筆折返停留（`layovers` view 裡 `go_back` 等於這一端的列），取同一車牌在 `end_time` 到 `next_start_time`（含兩端）之間、`Speed` 轉成數字等於 0 的 `bus_data` 回報，照 `(BusID, DataTime)` 去重，叫靜止回報。不看 `RouteID`，因為車在末站常把路線碼切成 0 或別的碼。

把靜止回報按座標分組（同一對經緯度算同一個靜止點，帶筆數），對每個靜止點數 50 公尺內（含自己）所有靜止點的筆數總和，最多的那一點是種子；筆數相同時取緯度小的，再取經度小的，不用時間或車牌當依據，這樣同一份輸入連跑兩次位元組相同。位置是種子 50 公尺內所有靜止點以筆數加權的平均座標，存六位小數。距離一律用 `analysis/mrt_overlap.sql` 那個 haversine 巨集（地球半徑 6,371,000 公尺），公尺一位小數。

三個查核數字：`n_layovers` 是當天結束在這一端的折返停留筆數；`n_located_layovers` 是其中至少有一筆靜止回報落在位置 150 公尺內的筆數；`end_stop_meters` 是位置到該方向末站的距離。另記 `n_standstill_records` 是靜止回報總筆數。一筆靜止回報都沒有的那一天，位置是空的，三個數字裡只有 `n_layovers` 有值。

理由：這個定義一句話講得清楚，而且正好是人工查證時看的東西（GPS 停在哪裡、離站牌多遠）。按座標分組再算，是因為車停著時 GPS 常回報完全相同的座標，分組後 n 乘 n 的距離表很小。50 公尺是一台公車長的三到四倍，把同一個停車位的抖動收在一起；150 公尺是查證時用過的尺度（112 與 136 公尺都在內）。三個半徑與公廁的 500 公尺都寫在 `analysis/params.sql`，階段檔不寫字面數字。

替代方案：取每筆折返停留裡最長一段靜止的位置再取中位數（兩層定義，講不清楚，否決）；網格計數（網格邊界切開同一個停車位，否決）；用 `DutyStatus` 或 `BusStatus` 過濾（實測代碼意義還待確認，否決）。

### 開過去就走那一端的位置以末站計

性質是 `pass_through` 的那一端，位置是該方向 `seq` 最大的站牌（`stops`），`location_source` 寫 `end_stop`，`end_stop_meters` 是 0，`n_located_layovers` 是空的，`n_layovers` 與 `n_standstill_records` 照記：靜止回報兩端都收，開過去就走那一端的筆數就是 `turnaround-map` 畫這一端的格子時，涵蓋比例那一行的分母。兩端每天都有一列，不管性質。

理由：車不停，沒有靜止點可算；這一端的設施問題是「如果要在這裡設休息站，附近有沒有廁所」，末站就是那個地方。`docs/background.md` 提到的折返點休息站講的正是這種端點。

替代方案：開過去就走那一端不出列（頁面上少一端，讀的人以為漏了，否決）。

### 還沒寫進設定的路線照常載入，兩端沒有設施的列

`RouteDayLoader` 在匯出前查 `RoutePage.route_ids` 有沒有這條路線：有，就用 `RoutePage.ends(route_id)` 取兩端的性質，當變數 `end_nature_0`、`end_nature_1`（值 `stop` 或 `pass_through`）傳給 SQL；沒有，兩個變數都是 `unknown`，`analysis/turnaround_facilities.sql` 不產生任何一端的列，`ends.csv` 與 `end_toilets.csv` 只有表頭，載入成功並在輸出多印一行說這條路線還沒有設定、沒有設施的列。設定裡有這條路線但缺方向或值不對時，`InvalidConfiguration` 照樣丟出、那一天失敗，這是設定錯誤。

理由：路線是先載入、看過數字、人工查證兩端之後才寫進設定的（`config/route_page.yml` 開頭的註解），載入不能反過來要求設定。沒有設施的列跟捷運重疊「舊資料沒有距離」是同一種狀態，頁面用同一種提示：要重新跑 `derived:load`。

替代方案：沒有設定就兩端都當停車算（悄悄假設性質，違反 zhongshan-turnaround-ends，否決）；沒有設定就失敗（打斷查證新路線的流程，否決）。

### GPS 只在 turnaround_facilities.sql 讀，編號階段檔與健檢卡不動

新增 `analysis/turnaround_facilities.sql`，檔名不以數字開頭，`bin/health-card` 不執行；`derived:load` 的附加檔順序是 `mrt_overlap.sql`、`turnaround_facilities.sql`、`derived_export.sql`。它自己用第 10 階段的 `day_files` 巨集與 `window_start`、`window_end` 列出 `bus_data` 在同一個讀檔視窗裡的小時檔（D-1 的 22、23 時、D 全天、D+1 的 00、01 時），用明確的 VARCHAR 欄位讀進來，只留 `BusID` 在當天折返停留裡出現過的車，再轉型。`analysis/10_load.sql` 的 `input_files`、`load_counts`、`50_quality.sql` 與 `60_export.sql` 一個字都不改。

理由：健檢卡不需要 GPS，改了第 10 階段，`quality.csv`、卡與 `spec/analysis/card_spec.rb` 全部跟著變。讀檔視窗沿用同一組，是因為折返停留的時間窗最晚到 D+1 的 01 時，跟趟次一樣。

替代方案：把 `bus_data` 加進第 10 階段的 `input_files`（健檢卡多讀 1 GB 卻用不到，否決）。

### 當天沒有 bus_data 小時檔時那一天不算

`DerivedLoadCommand#check_day` 多一項：`bus_data/<D>/` 至少有一個小時檔，沒有就那一天失敗，訊息寫出那個目錄；跟 `bus_event` 的檢查寫法相同。視窗內其他天的 `bus_data` 檔缺了不擋，跟 `bus_event` 一樣略過。

理由：`read_json` 遇到空清單會以 DuckDB 的錯誤結束，訊息看不出是哪支 feed 缺檔；在跑 SQL 之前擋，訊息才指得出目錄。當天有檔但某幾筆折返停留的時間窗裡沒有回報，不是錯誤，是「量不到」，記在 `n_located_layovers` 裡。

替代方案：沒有 `bus_data` 時照常載入、位置都空（一天的 GPS 整個沒收到是採集的問題，應該被看到，否決）。

### 公廁快照：抓環境部的全國公廁，照 number 排序分頁、逐頁檢查、整份一次寫

公廁的來源是環境部的全國公廁建檔資料，不是臺北市環保局的公廁點位。這條取代 2026-10-23 寫的「公廁快照：下載時去掉 BOM、用 CSV 解析器檢查，算的時候用最新的一份並記下日期」，換的時候那條還沒有任何任務開始，所以直接改寫，不另外留舊決定。

`bin/rails external:public_toilets` 用 `PublicToiletsSnapshot`（資料根目錄、台北日、可以替換的 fetcher，照 `MrtExitsSnapshot` 與 `OfficeCalendarSnapshot` 的做法，多一個可以替換的每頁列數，預設 1,000）向環境部的 API 要 CSV：網址是資料集頁公開的那條（含 `api_key`），固定帶 `format=CSV`、`sort=number asc`、`limit=<每頁列數>`，`offset` 從 0 起每頁加一個每頁列數，直到某一頁的列數少於每頁列數為止（含 0 列）。每一頁都要：HTTP 200、合法 UTF-8、去掉開頭的 BOM（這一份目前沒有，照 `OfficeCalendarSnapshot` 的做法照樣去掉）、表頭正好是那 14 欄、用 `CSV.parse` 解析、每列正好 14 欄、列數不超過每頁列數、`number` 與 `name` 不空、`latitude` 與 `longitude` 都是數字。整份接起來之後還要：至少一列、`number` 嚴格遞增（這一條同時擋住重複與沒排序的分頁）、頁數不超過 200 頁（API 永遠回滿頁時不會無限抓下去）。全部通過才用 `CSV.generate` 寫一次 `<TURNAROUND_DATA>/external/public-toilets/<台北日>.csv`（表頭一次、LF、無 BOM、欄位照 CSV 規則加引號），先寫 `.partial` 再改名，同一天重下載就覆蓋；任何一頁或整份有一項不通過就不寫檔、印原因（含第幾頁）、結束碼非零、既有快照不動。成功時印出寫了幾列，其中 `county` 是 63000（臺北市）與 65000（新北市）的各幾列，讓操作者一眼看出有沒有抓到自己要的兩個縣市。Gemfile 加 `csv`。

`derived:load` 算某一天時用資料夾裡檔名日期最新的一份，路徑與日期當變數 `public_toilets_path`、`public_toilets_day` 傳給 SQL，日期存進 `route_days.public_toilets_day`，路線頁顯示。沒有任何快照時那一天失敗，訊息指向 `bin/rails external:public_toilets`；檢查順序在捷運出入口之後、辦公日曆之前，兩樣都缺時訊息說的是捷運出入口，`derived-tables` 既有的規則不變。DuckDB 用 `read_csv` 讀，14 欄的名稱與型別明確列出（`latitude`、`longitude` 是 DOUBLE，其餘 VARCHAR），類別取 `type2`。

理由：有路線頁的三條路線裡兩條的停車端在新北市，100 天文件要答的「終點站與折返點 300 公尺內有可用廁所的比例」是全網的數字，一份不分縣市的來源才不會在市界外默默報 0。抓整份而不是只抓臺北市與新北市，是因為篩縣市又是一個要人記得改的設定，路線跨到基隆或桃園時會重演同一個洞；整份 47 頁 16 秒 11 MB，每月一次，付得起。照 `number` 排序是因為量到不排序會重複回同一列；用遞增檢查而不是事後去重，是因為去重會把分頁不穩定藏起來。逐頁檢查、整份一次寫，是因為 `MrtExitsSnapshot` 的契約「看起來不對的檔永遠不寫」在分頁下只能靠全部收齊再寫來守住。`csv` 用來解析與寫出，不自己處理引號；表頭精確比對是為了格式一改就立刻看到。

替代方案：繼續用臺北市檔（市界外報 0，否決於 2026-10-24 的量測）；臺北市檔加新北市列管公廁（後者沒有座標，否決）；只抓 county 63000 與 65000（多一個設定，跨縣市時重演，否決）；每頁事後以 `number` 去重取代排序（藏住不穩定，否決）；用 JSON 格式再自己寫 CSV（多一種格式要對，CSV 直接進 `read_csv`，否決）；下載時只檢查表頭、欄位留給 DuckDB 載入時檢查（壞檔已經寫進快照，而且錯在算的時候才出現，否決）。

### 衍生表存位置與 500 公尺內的公廁，300 公尺在讀頁面時套用

`analysis/derived_export.sql` 多寫兩個檔。`ends.csv` 每個方向一列：`go_back`、`end_seq`、`end_stop_name`、`end_latitude`、`end_longitude`、`location_source`（`standstill` 或 `end_stop`，沒有位置時空）、`latitude`、`longitude`、`n_layovers`、`n_located_layovers`、`n_standstill_records`、`end_stop_meters`，照 `go_back` 排。`end_toilets.csv` 是有位置的那一端 500 公尺內的每一間公廁，照快照的粒度一間一列：`go_back`、`name`（快照的 `name`，例如「正洋加油站-無障礙廁所」）、`category`（快照的 `type2`）、`address`、`latitude`、`longitude`、`meters`，照 `go_back`、`meters`、`name` 排。`route_day.csv` 多 `public_toilets_day`。

資料表：`route_day_ends`（`route_day_id` 外鍵連動刪除、上面那些欄位、`route_day_id` 加 `go_back` 唯一）與 `route_day_end_toilets`（`route_day_end_id` 外鍵連動刪除、`name`、`category`、`address`、`latitude`、`longitude`、`meters`）；`route_days` 加 `public_toilets_day`（date，可空）。`RouteDayLoader` 的 staging 多 `ends` 與 `end_toilets` 兩張，先寫 ends 再寫 toilets（以 `go_back` 找回那一端），寫入筆數要等於 CSV 列數；一天的替換連同這兩張表一起刪一起寫，既有資料重新跑 `derived:load` 就會補齊，migration 不回填。

理由：跟捷運重疊「衍生表存每個站牌的最近距離，門檻在讀頁面時套用」同一個做法，500 公尺內逐間存，是因為清單本身就是要給人看的，而且下一個 change 的地圖要畫它們；存間不存處，是詞彙表「衍生表」那條的原則：存逐筆、不存彙總，併成處是彙總，在讀的時候做；300 公尺是 `docs/100-days.md` 的門檻，寫在 `RoutePage::Facilities` 的常數裡，改門檻不用重算。

替代方案：只存最近一處（清單沒了，否決）；存 300 公尺內（之後要看 500 公尺就得重算，否決）；在 SQL 裡先併成處再存（併法要改就得重算，而且地址併處的規則本來就粗，留在讀的那一層才好換，否決）。

### 公廁以地址併成一處，在讀頁面時併，距離取最近的一間

`RoutePage::Facilities` 把一端存下的每一間公廁按 `address` 分組，一組是一處；地址空的列自己算一處（目前全國 46,006 列沒有空地址，規則寫下來是為了不讓它悄悄併進別處）。一處的距離是它裡面最近那一間的 `meters`，一處的名稱、類別與座標就是那一間的，另記這一處有幾間。300 公尺內幾處、500 公尺內幾處用一處的距離算；最近一處是距離最小的那一處，平手時名稱字典序小的；清單每一處一列，照距離再名稱排，每列是最近那一間的名稱、類別、地址、公尺與間數。不平均座標，不改名稱。

理由：全國檔一列是一間廁所，直接報「300 公尺內 33 間」會把職能發展學院一棟樓數成三十幾個地方，對司機沒有意義；地址是檔案裡唯一穩定的分組鍵。不平均座標，是因為量到同一地址各列的座標九成在 73 公尺內、但有 112 個地址超過 100 公尺、最遠 19 公里，平均會把一處推到兩棟樓中間甚至海裡，取最近的一間則永遠是一個真的存在的點。不去名稱的尾綴，是因為量到 395 個地址去了尾綴仍不一致，規則寫不乾淨，而且「正洋加油站-無障礙廁所」這種名稱對司機反而有用。代價是大場所併成一處（鳶山簡易運動場與鳶山銅鐘同一地址），同一地點登記成不同地址時變兩處（一個停車場兩個出入口各一個地址）；資料限制寫明，驗收時在福安居一那一端看併出來的處合不合理。

替代方案：按名稱去尾綴分組（395 個地址併不乾淨，否決）；按座標 50 公尺聚類分組（又一個聚類定義，而且跟靜止點的 50 公尺容易混，否決）；不併，直接報間數（數字沒有意義，否決）；平均座標（會把一處推到不存在的點，否決）。

### 靜止格：兩端的靜止回報聚成 0.0002 度的格子，少於 3 台車的格子不匯出

`standstill_records` 涵蓋兩個方向當天所有折返停留的靜止回報；位置只讀停車端的列，這點不變。每一端另外建 `standstill_cells`：每筆靜止回報的緯度與經度各除以 `standstill_cell_degrees`（0.0002 度，南北約 22 公尺、在台北的東西約 20 公尺），商四捨五入到小數六位之後取整數部分，乘回 0.0002 當格子的西南角，寫四位小數；同一格的回報合計成 `n_records`，另數不同車牌 `n_buses` 與不同折返停留 `n_layovers`。`n_buses` 小於 `cell_min_buses`（3）的格子不匯出。兩個常數都在 `analysis/params.sql`。路線沒有設定（任一端性質 `unknown`）時，跟另外兩張結果表一樣沒有列。

匯出 `end_cells.csv`（`go_back,cell_latitude,cell_longitude,n_records,n_buses,n_layovers`，照 `go_back`、`cell_latitude`、`cell_longitude` 排），寫進 `route_day_end_cells`（`route_day_end_id` 外鍵連動刪除、四位小數的兩個座標、三個整數欄，`route_day_end_id` 加兩個座標唯一）。這個 change 只存不畫：`RoutePage::Facilities` 與頁面不讀它，下一個 change `turnaround-map` 讀。

理由：地圖要畫的是車停在哪裡的分佈，一個位置點不夠。格子在匯出時就聚合並套門檻，是因為衍生表是頁面與之後月報唯一讀的東西，裡面不留任何靠一台車就畫得出來的格子（`docs/use-cases.md` 第 11 項：不給任何人監看司機的工具）。門檻只能在單日套，因為不同天的車數不能相加；代價是零星的格子不見，被丟掉的筆數可以從 `n_standstill_records` 減去各格 `n_records` 的和看出來。先四捨五入到小數六位再取整數，是避免 25.0604 這種剛好落在格線上的座標被浮點數誤差推到隔壁格。格子只拿來畫，位置仍照上面「靜止點與位置的定義」用 50 公尺鄰域算，所以那一條否決網格計數的理由（網格邊界切開同一個停車位）對位置仍然成立。

替代方案：存每筆折返停留每格的列、門檻在讀頁面時套（可以跨天算真正的車數，但衍生表裡會有一台車的格子，否決）；格子跟著 50 公尺的位置半徑走（地圖上一格 50 公尺太粗，停車位與站牌分不開，否決）；不存格子、地圖直接讀原始檔（Rails 不碰原始檔，`docs/decisions.md` 第 2 條，否決）。

### 路線頁每一端用涵蓋日子裡最近一個有位置的日子，並標出來

`RoutePage::Facilities.new(route_days, ends:)`：涵蓋的日子一列 `route_day_ends` 都沒有時 `needs_reload?` 為真，整塊只顯示要重新載入。否則每一端取涵蓋日子裡日期最近、而且 `latitude` 不空的那一列當這一端的位置，頁面標出那一天（`data-located-day`），並報涵蓋的日子裡有幾天這一端沒有位置；一天都沒有位置時，這一端顯示「量不到」與最近一天的 `n_layovers`，不顯示公廁。公廁數與清單從那一列的 `route_day_end_toilets` 讀，300 公尺內的數、500 公尺內的數、最近一處（名稱、類別、公尺）。性質與末站名稱從傳進來的 `RoutePage::Ends` 與那一列讀。標出的公廁快照日見下一條。

理由：折返停留與行駛時間的多天數字是把趟次合併算，位置不能合併；取最近一個有位置的日子並寫出來，是唯一不悄悄回退的做法。

替代方案：固定用最新一天（GPS 缺一天整塊就空，否決）；把多天的位置平均（位置會跑到兩個停車位中間，否決）。

### 公廁快照日跟著位置的日子，每一端各自標

每一端標出的公廁快照日，是那一端位置所在那天的 `route_days.public_toilets_day`：`RoutePage::Facilities` 的每個 `End` 帶 `public_toilets_day`（`located_day` 那天的快照日，量不到位置時是空的），元件每一端的 `[data-public-toilets-day]` 讀它。

Supersedes：Implementation Contract 原本的 `RoutePage::Facilities#public_toilets_day`（涵蓋日子裡最新一天的快照日，兩端共用），2026-10-24 由這條取代。task 4.1 照原本的寫法做完了，task 4.2 補 `End#public_toilets_day` 並拿掉它。

理由：一端的公廁清單來自位置那一天的 `route_day_end_toilets`，那些距離是用那一天載入時最新的快照算的。位置來自較早的日子、快照又在之後換過時，整塊共用最新一天的快照日，標的日期就不是清單的來源。

替代方案：整塊共用涵蓋日子裡最新一天的快照日（上面那個情形會標錯清單的來源，使用者 2026-10-24 否決）。

### 頁面只報數字，不判定夠不夠

新卡「折返點設施」（`CardComponent` 的 `id` 是 `facilities`，元件 `data-section="facilities"`）放在「來回與週期」那張卡之後、換休息試算之前（見下一條）；`SectionNavComponent::SECTIONS` 變成 `layovers cycles facilities buffer runtimes load mrt limits`。每一端一段，依 `go_back` 0、1 排：方向與末站名稱、性質（文案「停車」「開過去就走」，跟折返停留表相同）、位置來源的說明（停車端：「折返停留期間車輛靜止最密集處，離末站 N 公尺，M 筆折返停留裡 K 筆有靜止回報在 150 公尺內」；開過去就走：「以末站位置計」）、300 公尺內幾處、500 公尺內幾處、最近一處最近那一間的名稱、類別、公尺與這一處有幾間，以及一個預設關閉的 `details` 放 500 公尺內每一處的清單（最近那一間的名稱、類別、地址、公尺、間數，照公尺再名稱排）。段尾標出用的是哪一天的位置與那一天用的公廁快照。不出現任何「有廁所」「沒廁所」「達標」的判定，不用顏色。文案放元件同層的 `.yml`（tw、zh-TW、en）。資料限制元件加這一塊的限制。

理由：跟捷運重疊的決定一致；「夠不夠」要看開放時段與能不能借用，資料沒有，判了會被讀成官方認定。

替代方案：300 公尺內 0 處就標紅（判定，否決）。

### 卡片放在「來回與週期」之後、換休息試算之前

這個 change 寫的時候頁面還沒有「來回與週期」；它在 2026-10-24 由 run-time-vs-cycle 加在折返停留與換休息試算之間。「折返點設施」放在它之後：頁面 `data-section` 的順序是 `summary layover-chart layovers cycles facilities buffer-trade run-times load-chart mrt-overlap load-profile limitations`，區塊導覽八個連結。`route-page` 的 delta spec（Page content、Section links、Data limitations on the page）以 2026-10-24 的正式 spec 為底改寫，保留來回與週期的文字；以來回與週期加進來之前的版本為底的話，archive 時會把那幾句蓋掉。

理由：既有的順序不動，只插入一張卡。週期由停車端的折返停留加來回一趟組成，它跟折返停留那張卡相鄰比較好讀。原本的條件照舊守住：在折返停留之後、換休息試算之前。

替代方案：緊接在折返停留之後，來回與週期往後移一格（「兩端停多久」與「停在哪、附近有什麼」接在一起，但週期跟折返停留不再相鄰，使用者 2026-10-24 否決）。

### 頁尾顯名多一行環境部的公廁資料

路線頁用了環境部全國公廁建檔資料算出的數字，所以每一頁頁尾的顯名聲明（`AttributionComponent`）多一行「環境部 全國公廁建檔資料（data.gov.tw/dataset/30794），依政府資料開放授權條款第 1 版釋出」，放在辦公日曆那一行之後、不代表背書那一句之前，tw 與 en 同文。`site-layout` 的「Attribution footer on every page」跟著改，多一個 scenario。

理由：政府資料開放授權條款要求顯名，未盡顯名義務視為自始未取得授權。頁尾是全站每一頁都有的顯名處，捷運出入口與辦公日曆各有一行；辦公日曆那一行是 day-types 加的，做法相同。這一條是 2026-10-24 apply 途中發現漏掉、使用者同意補上的。

替代方案：只寫在 `docs/data-sources.md`（頁面上看不到，不滿足條款，否決）；只在折返點設施那張卡裡寫來源（其他來源都在頁尾，分散兩處，否決）。

## Implementation Contract

**行為**：

- 操作者執行 `bin/rails external:public_toilets`（`TURNAROUND_DATA` 指到資料根目錄），約十幾秒後得到 `external/public-toilets/<今天的台北日>.csv`，印出寫了幾列、其中臺北市與新北市各幾列。
- 之後執行 `bin/rails derived:load ROUTE=15373 DAY=2026-10-22`，輸出那一行多報兩端寫了幾間公廁、幾個靜止格；再開 `/routes/15373?day=2026-10-22`，在來回與週期與換休息試算之間看到「折返點設施」：去程（青年公園那一端，開過去就走）以末站計、返程（職能發展學院二，停車）由靜止點算出，各自的 300 與 500 公尺內處數、最近一處與它有幾間、每一處的清單、三個查核數字、位置的日子與那一天的公廁快照日。
- 對設定裡沒有的路線 `derived:load` 照常成功，輸出多一行說沒有設施的列；它的頁面（如果之後加進設定）在重新載入前顯示要重新跑 `derived:load`。
- 區塊導覽有八個連結，順序折返停留、來回與週期、折返點設施、換休息試算、行駛時間、載客剖面、捷運重疊、資料限制。頁面不出現任何車牌，不標任何門檻或合不合規。
- 每一頁頁尾的顯名聲明多一行環境部全國公廁建檔資料（data.gov.tw/dataset/30794）。

**介面與資料形狀**：

- `analysis/params.sql` 新增 `standstill_radius_meters = 50`、`located_radius_meters = 150`、`toilet_radius_meters = 500`、`standstill_cell_degrees = 0.0002`、`cell_min_buses = 3`。
- `analysis/turnaround_facilities.sql`：在 `mrt_overlap.sql` 之後執行，用它定義的 `haversine_meters` 巨集；讀 `stops`、`layovers`、變數 `data_root`、`window_start`、`window_end`、`public_toilets_path`、`end_nature_0`、`end_nature_1`；建立 `public_toilets`（快照的列，經緯度 double）、`standstill_records`（兩個方向的折返停留都算：`go_back`、`trip_id`、`bus_id`、`latitude`、`longitude`、`data_time`）、`turnaround_ends`（`ends.csv` 的欄位）、`end_toilets`（`end_toilets.csv` 的欄位）、`standstill_cells`（`end_cells.csv` 的欄位，只留 `n_buses` 不小於 `cell_min_buses` 的格）。`end_nature_*` 是 `stop`、`pass_through` 或 `unknown`；任一個是 `unknown` 時三張結果表都是空的。
- `analysis/derived_export.sql`：`route_day.csv` 多 `public_toilets_day`；新檔 `ends.csv`、`end_toilets.csv`、`end_cells.csv`，欄位與排序如上面的決定。
- `RouteDayLoader`：`STAGING` 多 `ends`、`end_toilets` 與 `end_cells`；匯出前查 `RoutePage.route_ids.include?(route_id)` 決定兩端性質的變數；附加檔順序 `mrt_overlap.sql`、`turnaround_facilities.sql`、`derived_export.sql`；`#call` 回傳的計數多 `ends:`、`end_toilets:` 與 `end_cells:`。
- `PublicToiletsSnapshot`：`PAGE_URL`（環境部 API 的網址樣板，含資料集頁公開的 CSV `api_key`、`format=CSV`、`sort=number asc`，`limit` 與 `offset` 由程式填）、`PAGE_SIZE = 1000`、`MAX_PAGES = 200`、`HEADER = "county,areacode,village,number,name,address,administration,latitude,longitude,grade,type2,type,exec,diaper"`、`DIRECTORY = "external/public-toilets"`、`TAIPEI_COUNTY = "63000"`、`NEW_TAIPEI_COUNTY = "65000"`；`.run(env, out:, fetcher:, day:)` 回結束碼；`.new(data_root:, day:, fetcher:, page_size: PAGE_SIZE, max_pages: MAX_PAGES)`；`#path`；`#call` 回 `{ rows:, taipei:, new_taipei: }`。fetcher 每頁呼叫一次 `call(url)`，回 `[status, body]`。
- 資料表：`route_day_ends`、`route_day_end_toilets`、`route_day_end_cells`、`route_days.public_toilets_day`，形狀如上面的決定；model `RouteDayEnd`（`belongs_to :route_day`、`has_many :toilets`、`has_many :cells`）、`RouteDayEndToilet`（`belongs_to :route_day_end`）、`RouteDayEndCell`（`belongs_to :route_day_end`）、`RouteDay has_many :ends`。
- `RoutePage::Facilities.new(route_days, ends:)`：`THRESHOLDS = [300, 500]`、`MAIN_THRESHOLD = 300`；`#needs_reload?`；`#ends` 回每個方向一個值物件：`go_back`、`nature`、`end_stop_name`、`located_day`（nil 表示量不到）、`public_toilets_day`（`located_day` 那天的 `route_days.public_toilets_day`，量不到時 nil）、`n_days_without_location`、`location_source`、`latitude`、`longitude`、`n_layovers`、`n_located_layovers`、`n_standstill_records`、`end_stop_meters`、`counts`（門檻對應處數）、`nearest`（最近一處：名稱、類別、地址、公尺、間數，或 nil）、`places`（500 公尺內每一處的清單：名稱、類別、地址、公尺、間數，照公尺再名稱排）。處是 `route_day_end_toilets` 按 `address` 分組（空地址每列自己一組），距離取組內最小的 `meters`，名稱、類別與座標取那一間的。不選任何車牌欄位。
- `TurnaroundFacilitiesComponent.new(facilities:)`，性質與末站從 `facilities.ends` 的值物件讀；頁面上可斷言的標記：`[data-section=facilities]`、`[data-end="0"]`、`[data-end="1"]`、`[data-end-nature]`、`[data-location-source]`、`[data-value=toilets-300]`、`[data-value=toilets-500]`（都是處數）、`[data-value=nearest-meters]`、`[data-value=nearest-rooms]`、`[data-value=located-layovers]`、`[data-located-day]`、`[data-public-toilets-day]`、`[data-needs-reload]`、`[data-no-location]`、`details[data-toilet-list]`。
- `AttributionComponent`：`.yml` 多 `public_toilets` 一行（tw 與 en 同文，跟 `mrt_exits`、`office_calendar` 一樣用 YAML anchor 共用），`.html.erb` 在辦公日曆那一行之後輸出。
- `SectionNavComponent::SECTIONS = %w[layovers cycles facilities buffer runtimes load mrt limits]`；頁面 `data-section` 順序 `summary layover-chart layovers cycles facilities buffer-trade run-times load-chart mrt-overlap load-profile limitations`。

**失敗模式**：

- `external:public_toilets`：沒有 `TURNAROUND_DATA` 印用法；任何一頁 HTTP 非 200、不是合法 UTF-8、表頭不符、某列不是 14 欄、一頁超過每頁列數、`number` 或 `name` 空、經緯度不是數字，或整份沒有資料列、`number` 沒有嚴格遞增（重複或沒排序）、超過 200 頁：印原因（含第幾頁、第幾列）、結束碼非零、不寫檔、既有快照不動。
- `derived:load`：當天沒有 `bus_data` 小時檔，那一天失敗、訊息寫出 `bus_data/<D>` 目錄；沒有公廁快照，訊息指向 `bin/rails external:public_toilets`（捷運出入口也缺時先說出入口）；設定裡有這條路線但兩端不完整，`InvalidConfiguration` 丟出、那一天失敗。
- 路線頁：涵蓋的日子沒有任何設施的列，整塊顯示要重新載入；停車端在涵蓋的日子裡都沒有位置，那一端顯示量不到與折返停留筆數、不顯示公廁；整塊跟其他塊一樣在 `@coverage.data?` 為 false 時不出現。

**驗收**：

- `bundle exec rspec` 全綠，含：分頁快照的成功（假 fetcher 回兩頁，每頁列數縮小到 3 讓測試資料小）與各種失敗（不連網路）、`turnaround_facilities.sql` 對 fixture 的位置、查核數字與每一間公廁的距離等於 README 手算的值、fixture 的靜止格只有戊站端西南角 (25.0604, 121.5002) 那一格（25 筆、3 台車、3 筆折返停留），C 與 E 的格子因為只有一台車不匯出、灌入的資料驗門檻的另一側與開過去就走那一端的格子、匯出的八個檔連跑兩次位元組相同、`derived:load` 缺公廁快照與缺 `bus_data` 時失敗、沒有設定的路線兩張表空、`RoutePage::Facilities` 的門檻、併處、最近有位置日子與每一端公廁快照日的規則、元件與 request spec 的區塊順序與八個連結、fixture 寫入後的頁面沒有車牌且 Bullet 不報 N+1。
- 真資料：`external:public_toilets` 約十幾秒寫出 46,006 列、臺北市 7,013、新北市 6,143（2026-10-24 量到的，快照更新後以新數字為準，差幾十列是正常的更新，差幾千列或某個縣市是 0 要查）；重跑 15373、10712、11764 的 2026-10-22 之後，三條路線停車端的位置離末站或下一趟起站（較近的那一個）都在 150 公尺內、`n_located_layovers` 不低於 `n_layovers` 的九成，與人工查證一致（`config/route_page.yml` 的人工查證量的也是離較近的那個站牌；`end_stop_meters` 只量末站，下一趟起站另外量）；職能發展學院二那一端 300 公尺內約 2 處、福安居一那一端 300 公尺內約 1 處（正洋加油站）、500 公尺內約 9 處（用末站座標量的，位置離末站一百多公尺時會差一兩處，差很多要查），福安居一的清單看起來是深坑街上那幾個地方，併處沒有把不同地方併在一起；記下每條路線一個路線日 `derived:load` 的秒數與 2026-10-22 的三個查核數字、300 與 500 公尺內的處數與間數、每一端匯出的靜止格數與保留的靜止回報佔 `n_standstill_records` 的比例，寫回這份 design 的 Risks。
- `bin/rubocop` 與 `bin/brakeman` 對新增與修改的檔案沒有 offense 與警告。

**範圍邊界**：在範圍內的是公廁快照、靜止點、位置與靜止格、三張衍生表與路線日的快照日、可算條件、路線頁一張卡與導覽、資料限制、頁尾顯名的一行、fixture、文件與 Gemfile 的 csv。不在範圍內：地圖與任何前端 JS、在頁面上顯示靜止格、大型車格位、調度站判定、開放時段、步行距離、門檻判定、摘要、健檢卡、其他路線、既有指標定義、排程與部署。

## Risks / Trade-offs

- [環境部 API 的 `api_key` 換了、欄位改了、一頁的上限改了] → 任一頁 HTTP 非 200 或表頭不符就整份不寫、既有快照不動，改一次 `PAGE_URL` 或 `HEADER` 常數；上限變小只會多幾頁，變大時每頁列數的檢查會擋下來，把 `PAGE_SIZE` 調上去就好。風險寫在這裡，不猜。
- [分頁不穩定或環境部換了排序方式] → `number` 嚴格遞增的檢查會擋下來，不會寫出有重複或漏列的快照；代價是那個月抓不到，重試或改排序欄位。
- [`PAGE_URL` 裡的 `api_key` 會被祕密掃描器當成外洩] → 它是資料集頁上隨下載連結公開的那把，不是祕密；常數旁邊的註解寫明出處，之後不要有人以為外洩而去換掉或藏起來。
- [整份 47 頁、16 秒、11 MB，每月一份] → 一年約 135 MB（估計），比一天的原始檔小；抓的時候逐頁檢查，失敗時印第幾頁。
- [26 列經緯度對調、同一地址座標相差 19 公里這類登錄錯誤] → 不修資料，快照照原檔寫；距離算出來不會落在任何一端 500 公尺內，所以不影響頁面，處的距離取最近一間也不受同地址的離群值影響。
- [同一地址併成一處把大場所併在一起、同一地點兩個地址變兩處] → 資料限制寫明；清單每一處帶地址與間數，讀的人看得出來；驗收時在福安居一那一端看併出來的處。
- [臺北市內全國檔與臺北市檔的差異（1,537 處對 7,013 間）] → 不核對兩份檔，只在職能發展學院二那一端對照一次（全國檔 2 處、臺北市檔 1 處）；哪一份比較全沒有答案，取全國檔是為了市界，不是為了完整度。
- [等級「不合格」的廁所照列] → 頁面只報有沒有、在哪裡，不判定能不能用；等級不上頁面。
- [每晚多讀一天約 1 GB 的 `bus_data` JSON，三條路線各讀一次（估計）] → 驗收時量一個路線日的秒數寫回這裡；太慢的話下一步是只列出折返停留時間窗涵蓋的小時檔，這次不做。
- [位置一天一個，調度站與路邊折返的路線可能每天跳] → 頁面標出用的是哪一天，`n_located_layovers` 讓人看到那一天有幾筆落在位置附近；跳動本身是資訊，月卡引用時要帶日期。
- [50 公尺的聚類半徑對一排停好幾台車的調度站可能偏向其中一個車位] → 三條路線驗收時對照人工查證的距離；半徑在 `params.sql`，要調只改一處。
- [`Speed` 是字串，格式若變成 `"0.0"`] → 轉成數字比較，不比字串。
- [商業營業場所、民眾洽公場所這些類別的公廁駕駛未必進得去] → 資料限制寫明，類別跟著每一處顯示。
- [Gemfile 加 `csv`] → Ruby 自帶的 bundled gem，沒有其他相依；`bin/health-card` 不用它。
- [舊資料沒有設施的列] → migration 不回填，頁面提示重跑 `derived:load`。
- [0.0002 度的格線切開同一個停車位，兩格各自不到 3 台車而都被丟掉] → 格子只拿來畫，位置不受影響；真資料驗收時看每一端保留的靜止回報比例，太低再談格子大小，常數在 `params.sql`。
- [fixture 只有四台車，3 台的門檻只能靠一格驗] → 戊站端那一格故意放三台車（TEST-0001、TEST-0003、TEST-0004），門檻的另一側與開過去就走那一端用灌入的資料斷言。
- [真資料驗收，2026-10-24 做的，資料日 2026-10-22、公廁快照 2026-10-24] → 以下都是量到的。`bin/rails external:public_toilets` 寫出 46,006 列，臺北市 7,013、新北市 6,143，22 個縣市，跟 2026-10-24 稍早量的相同；那天凌晨環境部的 API 時好時壞，每 3 分鐘重試一次，第 9 次才成功，成功那次連 Rails 開機 19.8 秒，失敗時是連線逾時（`Net::OpenTimeout`），沒有寫出任何檔。`derived:load` 一個路線日連 Rails 開機：15373 5.5 秒、10712 4.6 秒、11764 4.5 秒。各端：

  | 路線 | 一端 | 性質 | 位置離末站（公尺） | 位置離下一趟起站（公尺） | 折返停留，其中位置 150 公尺內 | 靜止回報 | 靜止格 | 格子保留的靜止回報 | 300 公尺內 | 500 公尺內 |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | 15373 中山幹線 | 青年公園(馬場町) | 開過去就走 | 0.0（以末站計） | 197.0（青年社宅） | 69，— | 128 | 9 | 117（91.4%） | 2 處 | 3 處 21 間 |
  | 15373 中山幹線 | 職能發展學院二 | 停車 | 31.1 | 24.6（職能發展學院二） | 36，33 | 756 | 11 | 729（96.4%） | 2 處 | 2 處 33 間 |
  | 10712 251 | 臺北車站(開封) | 開過去就走 | 0.0（以末站計） | 88.0（重慶南路一段） | 36，— | 63 | 5 | 44（69.8%） | 11 處 | 32 處 220 間 |
  | 10712 251 | 福安居一 | 停車 | 150.8 | 27.3（福安居） | 30，30 | 529 | 6 | 516（97.5%） | 2 處 | 9 處 27 間 |
  | 11764 251區 | 捷運公館站 | 開過去就走 | 0.0（以末站計） | 615.5（台電大樓） | 53，— | 116 | 10 | 111（95.7%） | 5 處 | 14 處 56 間 |
  | 11764 251區 | 福安居一 | 停車 | 157.7 | 36.6（福安居） | 38，38 | 952 | 7 | 779（81.8%） | 2 處 | 9 處 27 間 |

  福安居一的位置離末站超過 150 公尺，是因為車停在下一趟起站福安居那一側（兩站相距 140 公尺），離福安居 27.3 與 36.6 公尺，位置附近的折返停留是 30/30 與 38/38；使用者 2026-10-24 決定算通過，驗收改成量末站與下一趟起站較近的那一個，定義與 `params.sql` 不動。福安居一 300 公尺內是深坑地下停車場（233.4、224.2 公尺）與新店戶政事務所深坑區所兩處，正洋加油站在 342.7 與 347.6 公尺，跟用末站座標量的「300 公尺內 1 處、正洋加油站」不同，是位置往福安居那一側偏了約 150 公尺，在「差一兩處正常」內；500 公尺內 9 處，深坑街上的集順廟、衛生所、區公所、兩個停車場各自一處，沒有併在一起。職能發展學院二 300 公尺內的 2 處其實是同一棟樓：士東路 301 號的 32 間登記在三玉里、1 間登記在天玉里，地址字串不同所以分成兩處，就是上面「同一地點登記成不同地址」那一條。三頁 `?day=2026-10-22` 在 Rails 裡請求一次自動核對：區塊順序 `cycles` 之後是 `facilities`、導覽八個連結、這三天的車牌 34、8、15 個一個都不在頁面上、設施那一塊沒有判定的字樣、資料限制三句都在、頁尾有環境部公廁那一行。
- [archive 之前，別的 change 又改了 route-page 的 Page content、Section links 或 Data limitations on the page] → 這個 change 的 delta 以 2026-10-24 的正式 spec 為底；archive 前跑 `/spectra-drift turnaround-facilities` 或直接對照正式 spec，有變就再 ingest 一次。
- [turnaround-map 的 route-page delta 以這個 change 的 delta 為底寫成，也還沒有來回與週期] → apply turnaround-map 時，它的任務 1.1 核對前置條件，要一併把那份 delta 改成以這個 change archive 後的正式 spec 為底。

## Migration Plan

- migration 加兩張表與一欄；跑完 `bin/rails parallel:setup`。
- 先 `bin/rails external:public_toilets`，再對三條路線重跑 `derived:load`；重跑之前頁面那一塊顯示要重新載入，其他塊不受影響。
- 回退：還原 migration（刪兩張表與一欄）與程式即可，原始檔與快照不動。

## Open Questions

- 50 公尺與 150 公尺是否適合福安居一這種調度站端，要等真資料驗收；不符合時只調 `params.sql`，定義不變。2026-10-24 在 apply 途中試跑過一次（不是驗收：公廁快照還抓不到，公廁用 fixture 的檔代替，只看位置）：2026-10-22 的真資料，職能發展學院二的位置離末站 31.1 公尺、36 筆折返停留裡 33 筆在 150 公尺內；福安居一在 251 是 150.8 公尺、30 筆全部在內，在 251區 是 157.7 公尺、38 筆全部在內，兩者都略超過驗收寫的「`end_stop_meters` 在 150 公尺內」。`config/route_page.yml` 的人工查證量的是離「較近的那個站牌」，福安居一與下一趟起站福安居相距 140 公尺，`end_stop_meters` 量的是離末站；task 5.2 驗收時要決定這一條驗收的量法或門檻，不在這裡先改。2026-10-24 驗收時決定了：算通過，驗收改成量較近的站牌，50 與 150 公尺不動，數字見 Risks。
- 以地址併處在福安居一與板橋前站這種新北的端點併出來合不合理（深坑街上的廟、停車場、衛生所是不是各自一處），要等真資料驗收；不合理時改的是 `RoutePage::Facilities` 的分組，衍生表不用重算。2026-10-24 驗收：福安居一各自一處，合理；板橋前站還沒有路線頁，沒看。反過來的情形看到一例：職能發展學院二同一棟樓的地址一筆寫三玉里、一筆寫天玉里，分成兩處；要不要在分組前拿掉里名，另外決定。
