## Context

路線頁 `/routes/:route_id` 已經有摘要、行駛時間、折返停留、載客剖面四塊，資料來自 `derived:load` 寫進 PostgreSQL 的衍生表（`route_days`、`route_day_stops`、`trips`、`layovers`、`trip_stop_counts`）。`derived:load` 由 `lib/analysis_run.rb` 組 SQL：變數、`analysis/params.sql`、編號階段檔，再接 `analysis/derived_export.sql`；不以數字開頭的檔 `bin/health-card` 不會執行。

已核對的事實：

- `GetStop.gz` 每個站牌有 `latitude`、`longitude`（字串）。`analysis/10_load.sql` 的 `stops` 目前只帶 `route_id`、`go_back`、`seq`、`stop_id`、`stop_name`，沒有帶經緯度。
- 北捷出入口 CSV（data.gov.tw/dataset/128428）2026-10-22 下載：390 列，欄位「項次、出入口名稱、出入口編號、經度、緯度、是否為無障礙用」，**Big5 編碼**，DuckDB 的 `read_csv` 直接讀會報錯。出入口名稱像「頂埔站出口1」，沒有路線與站序。
- 用 2026-10-19 的中山幹線站牌與上述出入口試算（量到的）：距離門檻 300、500、800 公尺時，去程 46 站的重疊度是 28.3%、45.7%、52.2%，返程 45 站是 22.2%、40.0%、46.7%；500 公尺下兩個方向各是一段連續的站，對應中山北路到中華路。天母與青年公園兩端不在內。
- `spec/fixtures/analysis/static/2026-10-19/GetStop.gz` 的 10 個站牌全在同一個座標（25.05, 121.5），測不出距離。
- Gemfile 沒有 WebMock 一類的工具；`docs/decisions.md` 第 1 條的慣例是 fetch 層注入假 client。

詞彙依 `docs/spectra/LANGUAGE.md`：站牌、去返程、車上人數、載客剖面、衍生表、路線頁、台北日。「捷運重疊」還不在詞彙表裡，這個 change 新增一條。

## Goals / Non-Goals

**Goals:**

- 一個透明、可以重算的重疊定義，算出每個方向的重疊度與重疊路段，三種距離門檻並列。
- 重疊路段跟它的車上人數一起出現在路線頁。
- 捷運出入口資料有固定的下載與存放方式，用到哪一份快照看得到。

**Non-Goals:**

- 門檻對照與「超過 70%」標示；「尖峰每班次低於 5 人上下車」的對照。
- 門到門競爭力、捷運站間時間、TDX。
- 「同線連續段」與「軌跡長度」兩種定義。
- 健檢卡加重疊、其他路線、日型別、排程與部署。
- 修改既有的趟次、折返停留、載客剖面、行駛時間定義。

## Decisions

### 重疊用站牌到最近捷運出入口的直線距離

一個站牌到所有捷運出入口的距離取最小值，記下那個出入口的名稱。距離不超過門檻的站牌算「靠近捷運」。每個方向的重疊度是該方向靠近捷運的站牌數除以該方向的站牌數。同一方向站序相鄰、而且都靠近捷運的站，連成一段；至少兩站才算一段「重疊路段」，只有一站的不成段，但仍算進重疊度。

理由：現在就有資料、拿到卡上一句話講得清楚。公車橫越捷運線時只有路口附近一兩站會算進去，佔整條路線的比例小；一路沿著捷運走的路線才會被算高，那正是要找的。中山幹線的試算結果符合這個預期。

替代方案：同一條捷運線的連續段（出入口資料沒有路線與站序，要另找資料）；公車軌跡落在捷運線緩衝區內的長度比例（沒有捷運線軌跡的來源）。拿到資料再升級，這次的數字當對照。

### 衍生表存每個站牌的最近距離，門檻在讀頁面時套用

DuckDB 只算每個站牌的經緯度、最近出入口名稱與距離（公尺，一位小數），存進 `route_day_stops`。300、500、800 公尺三種門檻寫在路線頁查詢物件的常數裡，讀頁面時套用；500 公尺是主要的數字，重疊路段與它的車上人數都用 500 公尺。

理由：三種門檻共用同一份距離，加一種門檻不用重算衍生表，門檻也只寫在一個地方。

### 距離用 DuckDB 的 haversine 巨集，不裝 spatial 擴充

在 `analysis/params.sql` 旁邊不加任何常數；`analysis/mrt_overlap.sql` 自己定義一個 haversine 巨集（地球半徑 6,371,000 公尺），站牌與出入口兩兩相算取最小。

理由：spatial 擴充要在執行時下載，`derived:load` 目前不需要網路。一條路線 91 站乘 390 個出入口是三萬多對，直接算就夠快（試算是在毫秒級完成，量到的）。

### 出入口快照：下載時轉成 UTF-8，算的時候用最新的一份並記下日期

`bin/rails external:mrt_exits` 下載北捷的 CSV，從 Big5 轉成 UTF-8，檢查表頭正好是「項次,出入口名稱,出入口編號,經度,緯度,是否為無障礙用」，至少一列，經緯度都是數字；通過才寫到 `<TURNAROUND_DATA>/external/taipei-mrt-exits/<台北日>.csv`，同一天重下載就覆蓋。任何一項不通過就不寫檔，訊息說明哪裡不對。HTTP 呼叫由一個可以替換的 fetcher 負責，測試注入假的 fetcher，不連網路。

`derived:load` 算某一天時，用那個資料夾裡檔名日期最新的一份，把它的日期存進 `route_days.mrt_exits_day`，路線頁顯示這個日期。資料夾裡沒有任何快照時，那一天失敗，訊息說要先跑 `bin/rails external:mrt_exits`。

理由：決定第 2 條，原始資料放檔案、可以重算；出入口不定期更新，所以存成有日期的快照，用到哪一份要看得到。在下載時就轉成 UTF-8，DuckDB 與之後任何讀它的程式都不用再處理編碼。

替代方案：每次 `derived:load` 都下載（算一天要連網路，而且同一天重算可能拿到不同的資料，否決）；放進 repo（決定第 11 條之外，但資料跟程式混在一起，更新要 commit，否決）。

### 重疊路段的車上人數沿用載客剖面的值

每一段重疊路段、每個時段，取這段內每個站、每趟的車上人數（就是 `trip_stop_counts` 的值，`load-profile` 的定義），合在一起算中位數與 p90（`percentile_cont`，一位小數），並給有人數的趟數。

理由：不另外定義「載客」，沿用已經驗過、而且跟健檢卡一致的車上人數。

### 頁面只報數字，不標示門檻

頁面不寫「超過 70%」，也不對照「尖峰每班次低於 5 人上下車」。資料限制寫明：靠近捷運不等於可以被捷運取代；距離是直線距離；淨上下車不是上車人數加下車人數。

理由：我們的定義不是官方算法，標示門檻會被讀成官方認定；第二個門檻要的是上下車的總人數，車上人數相減只有淨值。上一個 change 的非目標「門檻對照裡的 70% 與 5 人…卡上這些欄位先不出現，不留空殼」理由在這裡依然成立。

## Implementation Contract

**行為**：

- 操作者執行 `bin/rails external:mrt_exits`（`TURNAROUND_DATA` 指到資料根目錄），得到 `external/taipei-mrt-exits/<今天的台北日>.csv`，印出寫了幾個出入口。
- 之後執行 `bin/rails derived:load ROUTE=15373 DAY=2026-10-19`，再開 `/routes/15373?day=2026-10-19`，在折返停留與載客剖面之間看到「與捷運重疊」：每個方向三種門檻的重疊度、500 公尺下的重疊路段與每段各時段的車上人數，以及用到的出入口快照日。

**介面與資料形狀**：

- `analysis/mrt_overlap.sql`：讀 `stops`（經緯度由 `analysis/10_load.sql` 帶出）與變數 `mrt_exits_path`，建立 `stop_mrt_distances`（`go_back`、`seq`、`latitude`、`longitude`、`nearest_exit_name`、`nearest_exit_meters`）。`derived:load` 的附加檔順序是 `mrt_overlap.sql`、`derived_export.sql`。
- `stops.csv` 的欄位改成 `go_back,seq,stop_name,latitude,longitude,nearest_exit_name,nearest_exit_meters`；`route_day.csv` 加 `mrt_exits_day`。
- 資料表：`route_day_stops` 加 `latitude`、`longitude`（double）、`nearest_exit_name`（string）、`nearest_exit_meters`（double）；`route_days` 加 `mrt_exits_day`（date）。既有資料重新跑 `derived:load` 就會補齊，migration 不回填。
- 路線頁：查詢物件給每個方向的站牌數與三種門檻的重疊度、500 公尺下的重疊路段（方向、起訖站序與站名、站數），以及每段各時段的中位數、p90、趟數。

**失敗模式**：

- `external:mrt_exits`：沒有 `TURNAROUND_DATA`、HTTP 非 200、表頭不符、沒有資料列、經緯度不是數字：印原因、結束碼非零、不寫檔、不改既有快照。
- `derived:load`：沒有任何出入口快照時，那一天失敗，訊息說要先跑 `bin/rails external:mrt_exits`，不寫入那一天。
- 路線頁：舊資料的站牌沒有距離（`nearest_exit_meters` 為空）時，「與捷運重疊」那一塊顯示要重新跑 `derived:load`，不顯示 0%。

**驗收**：

- `make test` 全綠，含：下載的成功與四種失敗、Big5 轉換、`mrt_overlap.sql` 對 fixture 的距離與最近出入口、`derived:load` 沒有快照時失敗、重疊度與重疊路段的定義測試、路線頁的 request 與 component 測試。
- 對真資料：`external:mrt_exits` 寫出 390 個出入口；重跑 2026-10-19 後，路線頁去程 500 公尺的重疊度是 45.7%、返程 40.0%，與 design 的試算相同（出入口快照若已更新，數字以新快照為準，並在驗收時記下差異）。
- `bin/rubocop`、`bin/brakeman` 對新增與修改的檔案沒有 offense 與警告。

**範圍邊界**：在範圍內的是上面的下載、距離、衍生表欄位、路線頁一塊、資料限制與文件更新。不在範圍內：門檻標示、競爭力、其他重疊定義、健檢卡、其他路線、日型別、排程、既有指標定義。

## Risks / Trade-offs

- [靠近捷運不等於可取代] → 頁面資料限制寫明；三種門檻並列，讓讀者看到結果對門檻的敏感程度。
- [出入口 CSV 的格式或編碼改了] → 下載時檢查表頭與數值，不符就不寫檔，既有快照保留。
- [用最新快照算舊日子] → 重算舊日子會用新快照；`route_days.mrt_exits_day` 記下用的是哪一份，頁面顯示。
- [舊資料沒有距離欄位] → migration 不回填，頁面提示重跑 `derived:load`。
- [fixture 站牌座標要改] → 目前沒有任何測試讀 fixture 的站牌座標；改完跑整套確認。
