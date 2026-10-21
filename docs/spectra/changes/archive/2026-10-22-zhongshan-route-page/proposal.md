## Why

這個 change 服務三樣交付物之外、但三樣都要用的那一層：路線頁（每天更新、給司機與站長看的畫面），以及它讀的衍生表。健檢卡與換休息試算之後也從這批衍生表取數。上一個 change `zhongshan-first-health-card` 用 DuckDB 直接讀原始檔，為中山幹線（路線 `Id` 15373）驗過了趟次、折返停留、載客剖面的定義，產出一張 Markdown 卡；它的 Non-Goals 寫明「第一張卡的 SQL 驗過之後，搬進每晚批次是下一個 change」。現在還沒有任何畫面，接下來要做什麼很難想像，所以這個 change 從原始檔一路打通到一個看得到的路線頁，而不是只做到資料庫。

需要的資料全部是 n-gear 已經在收的原始檔，跟上一個 change 相同：

- 動態 feed `bus_event`（到離站）：重建趟次、算折返停留與行駛時間。
- 動態 feed `bus_seat_event`（車上人數 `RemainingNum`）：逐站車上人數、載客剖面。
- 靜態 feed 同一天的快照 `GetRoute.gz`、`GetStop.gz`、`GetPathDetail.gz`：路線名稱、起迄、附屬路線、站序與站名。

資料從採集開始的 2026-10-18 起才有，所以「最近一個月」還湊不滿，這個 change 的範圍上限是最近 7 天。

## What Changes

- 新增 rake task `derived:load`：給路線 `Id` 與台北日（或一段日期），對每一天先用 DuckDB 跑已驗過的 `analysis/` SQL 階段，把逐趟的結果寫成 CSV（趟次、折返停留、每趟逐站車上人數，以及當天的路線與站序資訊），再寫進 PostgreSQL 衍生表。同一個交易裡先刪掉「這條路線、這個台北日」既有的資料，再整批寫入，所以同一天重跑幾次結果都一樣。回補從 2026-10-19 起：2026-10-18 只從 15:11 開始採集，是不完整的一天。
- `bin/health-card` 與 `derived:load` 共用「先 `params.sql`、再編號階段檔」的組 SQL 與執行 DuckDB 的程式，`bin/health-card` 的輸出不變。
- 衍生表存逐趟資料，不存彙總：一個月的 p85 不能用每天的 p85 合起來，司機也要能查每趟的時刻（`docs/use-cases.md` 第 11 項）。彙總在讀頁面時用 SQL 算。
- 新增指標「行駛時間」：完整趟次的終點減起點；起點取自到站時刻（`start_from_arrival`）或終點取自離站時刻（`end_from_departure`）的趟次排除並計數。按方向與發車小時給趟數、p50、p85、p95。
- 新增路線頁 `/routes/15373`：可以選一個台北日、切換「當天」與「最近 7 天」，顯示趟次數、行駛時間表、折返停留（按結束那趟的方向分列，也就是兩端分開）、載客剖面。趟數少的格子標出來。頁面不出現任何車牌。
- 同一天的資料，路線頁上的趟次數、折返停留的分佈數字、載客剖面的中位數與 p90，要跟 `bin/health-card` 對同一份輸入產出的卡一致，用測試鎖住，確認搬進資料庫之後定義沒有走樣。
- 第一次真正用到「衍生表」與「行駛時間」，`docs/spectra/LANGUAGE.md` 這兩條的「在資料或程式碼裡」要更新成實際的表與欄位。

## Non-Goals

非目標，這個 change 不做：

- 排程與部署。`config/deploy.yml` 還是 Kamal 範本，網站部署在哪還沒決定；指令與 rake task 在筆電上手動跑，用 `bin/dev` 看頁面。每晚自動跑等主機定了另開 change。
- 車牌查詢。路線頁的邊界是車牌只能從搜尋進入（`docs/spectra/LANGUAGE.md` 路線頁一條），這個 change 的頁面完全不顯示車牌，搜尋另開 change。
- 中山幹線以外的路線。路線清單是設定，但只放 15373；307、251 區間等各自驗過定義再加。
- 平日與假日分開算。辦公日曆還沒抓，`DateType` 怎麼對到平假日待確認；頁面寫明最近 7 天沒有分日型別，並列出涵蓋的日期與星期。
- 最近一個月與月卡。資料還不滿一個月；天數是參數，之後改成 30 天不需要改結構。
- 班次串、歸零檢查、資料品質數字搬上頁面。它們留在健檢卡；這個 change 的頁面只放行駛時間、折返停留、趟次數、載客剖面。
- 換休息試算、任何互動式試算。
- 改動已驗過的趟次、折返停留、載客剖面定義。

## Capabilities

### New Capabilities

- `derived-tables`：把一條路線一個台北日的逐趟結果從原始檔算出來、寫進 PostgreSQL：算一天的指令、寫入的 rake task、一次替換一路線一天、回補日期範圍、失敗時不留下半套資料。
- `run-time`：行駛時間的定義：哪些趟次算、怎麼分組、報哪些百分位數、排除的趟次怎麼計數。
- `route-page`：路線頁：網址與參數、日期與範圍、顯示的四塊內容、樣本少的標示、不顯示車牌、與健檢卡一致。

### Modified Capabilities

無。趟次重建、折返停留、載客剖面三份既有 spec 的定義原樣沿用；這個 change 只把它們的逐趟結果存進資料庫，彙總在資料庫端重算。

## Impact

- 新增 `analysis/derived_export.sql`，沿用 `analysis/params.sql` 與編號階段檔；組 SQL 與執行 DuckDB 的程式從 `bin/health-card` 抽到 `lib/`，`bin/health-card` 的行為不變。
- 新增 rake task（`lib/tasks/`）、PostgreSQL migration 與對應的 ActiveRecord model；這是 repo 第一批 migration，會產生 `db/schema.rb`。
- 新增 `config/routes.rb` 的路線頁路由、controller、ViewComponent 元件與它們的 `.yml` 文案。
- 新增 `spec/` 下的 request、component、rake task 與資料一致性測試，沿用 `spec/fixtures/analysis/` 的合成 fixture。
- 修改 `docs/spectra/LANGUAGE.md` 的「衍生表」與「行駛時間」兩條。
- 不改 `Gemfile`；DuckDB CLI 仍是外部依賴（上一個 change 已經要求）。
- 資料限制與假設，頁面上與 spec 裡都要寫明：車不等於人，折返停留是駕駛休息的上限，雙班制下對不回單一駕駛；車上人數是票證推出來的值，準確度看下車刷卡率，且實測不會在趟次之間歸零；10 秒輪詢一定漏站，漏了起站或末站的趟次不算行駛時間；跨小時檔的重複讀檔時一律再去重；天數少、離峰一個方向只有幾趟，樣本少的格子要標出來。
