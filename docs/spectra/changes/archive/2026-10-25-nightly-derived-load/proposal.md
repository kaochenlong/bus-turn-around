## Why

這個 change 服務三樣交付物中的第一樣：路線健檢卡在網站上的路線頁（與帶路線清單的首頁）。它需要的資料是 Mac mini 上 n-gear 每天收下來的原始檔（`bus_event`、`bus_seat_event`、`bus_data` 的小時檔與每天 04:30 的 `static/` 快照），加上三份外部快照（捷運出入口、公廁、辦公日曆），算出來的衍生表寫進正式站的 PostgreSQL。

採集從 2026-10-18 起每天都在跑，但採集之後沒有一步是自動的：一天的資料要有人在筆電上跑 `bin/rails derived:load`，再跑 `bin/push-derived --push` 把開發資料庫的衍生表整份換到正式站。正式站因此停在 2026-10-22。`docs/decisions.md` 第 12 條與 `deploy-digitalocean` 的 design 都把「每晚自動跑要在哪裡算」留給下一個 change，這就是那個 change。2026-10-25 定的方向：在 Mac mini 上算，`derived:load` 透過 ssh 轉送直接寫正式站的資料庫。

為什麼是 mini、為什麼直接寫（量到的數字都是 2026-10-25 在筆電上量的，mini 上的實際數字由第一次執行的紀錄補上）：

| 事實 | 數字 | 意義 |
| --- | --- | --- |
| DuckDB 算 307（16111 加 19108）2026-10-22 一個路線日 | 5.3 秒、CPU 24.7 秒、峰值記憶體 2.98 GB | 正式站的 Droplet 整台 2 GiB，放不下；第 12 條也說主機不裝 DuckDB、不放原始檔 |
| 筆電每小時鏡射 mini 的原始檔 | 147 次有 3 次連不到，每天 19 到 25 次 | 筆電會睡，鏡射最多晚一小時，排程不能靠它 |
| Mac mini | 12 核、24 GiB、剩 265 GiB、已開機 136 天 | 原始檔就在本機，這個專案的排程本來就用它的 launchd（第 8 條） |
| 衍生表 16 個路線日 | 40 MB、`trip_stop_counts` 187k 列 | 每天四條路線約 10 MB；整份 dump 每晚推會隨天數線性長大，一個路線日一個交易的增量寫入不會 |

## What Changes

- 新指令 `bin/nightly-load`：在 mini 上跑，不加參數只印計畫（正式站有哪些路線日、哪些要載入、哪些跳過、schema 對不對），`--load` 才開 ssh 轉送連正式站的 PostgreSQL，對每個缺的路線日跑 `RouteDayLoader`，一個路線日一個交易；`--recompute` 把正式站已有的路線日也重算，可用 `ROUTE=` 限定一條路線。一天要等讀檔視窗結束（隔天 02:00）才算，載入前比對正式站與 checkout 的 migration 版本，不一致就停；一個路線日失敗不擋其他路線日，結束碼非零；同時只跑一個。
- 新設定 `config/derived_days.yml`：第一天 2026-10-19，以及跳過的日子與理由，先放 2026-10-23 與 2026-10-24（薔琵颱風減班停駛，使用者決定不放上網站）。
- `bin/push-derived --push` 多一個檢查：正式站有、這台沒有的路線日存在時拒絕推，不提供繞過的參數。
- mini 上的排程（LaunchAgent，每小時一次、冪等補跑）、包一層的 shell script、環境變數檔，照第 11 條放在 repo 外；mini 要裝 Ruby 4.0.9 與 DuckDB、clone website、抓三份外部快照、放一把只准轉送到資料庫的埠的 ssh 金鑰到正式站。
- 文件：`docs/decisions.md` 加第 14 條；README 的架構一節、`docs/spectra/LANGUAGE.md` 的「衍生表」與「路線頁」、`analysis/README.md`、AGENTS.md 常用指令改成每晚自動載入。詞彙表「路線頁」那一句「資料由人工載入…也不是每天自動更新」是 `ui-touchups` 的決定，這個 change 推翻它。
- 不改 schema、不加 migration，正式站不用重新 deploy；`derived:load`、`RouteDayLoader`、分析 SQL 的定義都不動。

## 非目標

- 颱風日的日型別或標示：這次只用跳過清單，10-23、10-24 不載入；要不要標成颱風日另開 change。
- 正式站留幾天、刪舊資料：全部保留，`route_days` 每天四列、`trip_stop_counts` 每天約 5 萬列，一年內不是問題。
- 原始檔的異地備份、把原始檔或 DuckDB 放上 Droplet、在筆電或雲端排程：mini 的替代方案都否決於 Why 的那張表。
- 「最近 7 天」有四個查詢物件取到最早那天（`RoutePage::MrtOverlap`、`LayoverDistribution`、`LayoverStats`、`LoadProfile` 用 `order(day: :desc)` 疊在 `Coverage#route_days` 的升冪排序上）：是路線頁的 bug，另開 change 修，這個 change 不碰路線頁。
- 三份外部快照在 mini 上的自動更新（公廁每月、辦公日曆每年、捷運出入口不定期）：這次手動抓一次，2027 的辦公日曆要在一月前再抓。
- 失敗通知走哪個服務：包一層的 script 只在成功時打一個可選的 URL，用哪個 dead man's switch 由使用者決定。
- 淘汰 `bin/push-derived`：這次只加檢查，淘汰留到 `--recompute` 用過之後。
- 從 mini deploy 或跑 migration：正式站的 schema 只由 deploy 時容器的 `db:prepare` 改。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `derived-tables`: 新增每晚載入指令 `bin/nightly-load` 的需求（計畫與載入兩種模式、要載入的路線日怎麼選、讀檔視窗以隔天 02:00 為界、載入前的 schema 比對、一個路線日失敗不擋其他、同時只跑一個）、`config/derived_days.yml` 的格式與檢查，以及 `bin/push-derived` 拒絕刪掉它沒有的路線日。既有的 `derived:load` 需求不改。

## Impact

- 新增：bin/nightly-load、app/models/nightly_load_command.rb、app/models/derived_days.rb、app/models/production_tunnel.rb、config/derived_days.yml、spec/models/nightly_load_command_spec.rb、spec/models/derived_days_spec.rb、spec/models/production_tunnel_spec.rb。
- 修改：app/models/derived_push_command.rb 與 spec/models/derived_push_command_spec.rb（拒絕刪掉它沒有的路線日）、app/models/derived_load_command.rb 與 app/models/route_day_loader.rb（寫入那一行的文字抽到 loader，兩個指令共用）、docs/decisions.md、README.md、docs/spectra/LANGUAGE.md、analysis/README.md、AGENTS.md、docs/spectra/specs/derived-tables/spec.md（歸檔時套用）。
- repo 外（使用者在 mini 與正式站操作）：mini 的 Homebrew 裝 duckdb、rbenv 裝 Ruby 4.0.9、clone website、三份外部快照、repo 外 ops 目錄的 script 與 plist、mini 上的環境變數檔；正式站 ssh 使用者的 authorized_keys 多一行受限的金鑰。
- 不動：正式站的 image 與 schema、n-gear、筆電的每小時鏡射、`analysis/` 的 SQL、路線頁。
