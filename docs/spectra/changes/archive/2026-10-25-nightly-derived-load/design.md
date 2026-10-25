## Context

資料從採集到上線目前分四步，前兩步自動、後兩步手動：

1. Mac mini 上的 n-gear 每 10 秒採集，每小時把兩小時前的小時檔壓成 `.jsonl.gz`，每天 04:30 存 `static/<台北日>/` 的靜態快照（`docs/decisions.md` 第 8 條：排程用 launchd，部署在一台不會睡的 Mac）。
2. 筆電每小時用 rsync 鏡射一份（排除 `external/`），這是筆電上分析用的資料來源，最多晚一小時。
3. 筆電跑 `bin/rails derived:load ROUTE=… FROM=… TO=…`：`DerivedLoadCommand` 對每一天先 `RawDayCheck.check!`，再由 `RouteDayLoader` 用 DuckDB 跑 `analysis/` 匯出 CSV，在一個交易裡刪掉再寫入那條路線那一天（`derived-tables` 的「Replace one route day atomically」）。一天要等隔天的 01 時檔出現才算。
4. 筆電跑 `bin/push-derived --push`（`DerivedPushCommand`）：檢查這台有路線日、pg_dump 主版本不比正式站新、兩邊 `schema_migrations` 最大版本相同，然後匯出開發資料庫的衍生表、備份正式站、一個交易整份換掉、比對列數。衍生表清單從 `route_days` 沿外鍵自動推，目前十張。

第 12 條把「每晚自動跑要在哪裡算」留給這個 change；`deploy-digitalocean` 的決定「這次的資料用 pg_dump 從開發資料庫搬，不在主機上算」只限那一次，它列的替代方案「用 `derived:load` 透過 `ssh -L` 直接寫正式資料庫」就是這裡選的路，當時的顧慮是「要重算、比 dump 慢、production 環境在筆電跑要處理 credentials」：每晚算的本來就是新的一天，重算不是成本；一個路線日 DuckDB 5 秒加寫入幾秒；credentials 的問題在下面的決定裡解掉。

2026-10-25 量到與查到的事實（除註明外都在筆電上量）：

| 事實 | 數字或狀態 |
| --- | --- |
| DuckDB 算 307（16111 加 19108）2026-10-22 一個路線日 | 5.3 秒、CPU 24.7 秒、峰值記憶體 2.98 GB（量到的；mini 上沒量，第一次執行的紀錄補上） |
| 一天的原始檔 | `bus_data` 190 MB、`bus_event` 37 MB、`bus_seat_event` 42 MB、`static` 6 MB（mini 上 2026-10-22） |
| 衍生表 | 16 個路線日 40 MB，`trip_stop_counts` 187k 列；每路線日約 2.5 MB、12k 列（量到的） |
| 正式站 | 1 vCPU、2 GiB；`website-db` 容器 postgres:16，資料庫的埠只綁主機的 127.0.0.1；資料停在 2026-10-22 |
| Mac mini | Apple Silicon 12 核、24 GiB、剩 265 GiB、開機 136 天；Homebrew 有 rbenv、ruby-build、postgresql@14（keg-only）；rbenv 只有 Ruby 3.4.2；沒有 duckdb、沒有 website 的 checkout；`data/` 沒有 `external/`；known_hosts 沒有正式站 |
| 筆電每小時鏡射 | 147 次有 3 次連不到 mini，每天 19 到 25 次 |
| production 環境不帶任何 key 能不能開 | 能：拿掉 `config/master.key` 與 `config/credentials/*.key` 的副本，`RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 WEBSITE_DATABASE_PASSWORD=x DB_HOST=127.0.0.1 DB_PORT=1 bin/rails runner` 開得起來，資料庫設定照環境變數，第一個查詢才因為埠沒開而失敗 |
| 測試環境的頁面路線 | `config_for` 是 deep merge，`RoutePage.route_ids` 在 test 是 `[15373, 10712, 11764, 16111, 9001]` |
| 辦公日曆 | 2026-10-25 日（光復節）與 2026-10-26 一（補假）都是假日；10-23、10-24 是颱風減班的日子，使用者決定不放上網站 |

正式站的 schema 只由 deploy 時容器的 `bin/docker-entrypoint` 跑 `db:prepare` 改。這個 change 不加 migration。

## Goals / Non-Goals

**Goals:**

- 每一條頁面路線的每一個台北日，在讀檔視窗結束後的一小時內出現在正式站，中間沒有人的步驟；算在 Mac mini 上，直接寫進正式站的資料庫，一個路線日一個交易。
- 漏掉的日子（mini 當時沒跑、DuckDB 失敗、網路斷）下一個小時自動補；不載入的日子寫在設定裡，附理由。
- 算法改了之後重算全部，是 mini 上的一個指令。
- 舊的整份推送不能把 mini 寫進去的日子刪掉。
- 不改 schema、不加 migration、不改 `derived:load` 與分析 SQL 的定義。

**Non-Goals:**

- 颱風日的日型別或標示（只用跳過清單）；正式站留幾天、刪舊資料（全部保留）。
- 原始檔的異地備份；把原始檔或 DuckDB 放上 Droplet；在筆電或雲端排程。
- 「最近 7 天」四個查詢物件取到最早那天的 bug（路線頁的 change）。
- 三份外部快照在 mini 上的自動更新；失敗通知走哪個服務（script 只在成功時打一個可選的 URL）。
- 淘汰 `bin/push-derived`；從 mini deploy 或跑 migration。

## Decisions

### 在 Mac mini 上算，launchd 每小時跑一次、冪等補跑

原始檔就在 mini 上，沒有鏡射的延遲；mini 不會睡、已開機 136 天、24 GiB 放得下 3 GB 的峰值；這個專案的排程本來就是 mini 的 launchd（第 8 條）。排程照第 8 條的做法：`StartInterval` 3600 加 `RunAtLoad`，不用 `StartCalendarInterval`，機器睡過頭或某一次失敗，下一個小時補跑一次；指令本身是冪等的，沒有要載入的路線日時只讀正式站一次就結束。launchd 不會在上一次還在跑時起第二個同 label 的程序，但手動跑的 `--recompute` 會跟它重疊，所以另有鎖（見下面）。

替代方案：Droplet 上算（否決：整台 2 GiB 放不下 2.98 GB 的峰值，第 12 條也說主機不裝 DuckDB、不放原始檔，而且會跟 Puma 搶同一顆 CPU）；筆電上算（否決：會睡、鏡射最多晚一小時、開發資料庫兼當發佈來源，手上實驗中的東西會跟著上線）；雲端 runner（否決：原始檔沒有異地備份，還要把正式站的連線祕密交給第三方）。

### derived:load 透過 ssh 轉送直接寫正式資料庫，一個路線日一個交易

正式站資料庫的埠只綁主機的 127.0.0.1，mini 用 ssh 轉送（`ssh -N -L`）連到 `config/deploy.yml` 的 db 主機，把那個埠接到本機的一個埠，Rails 以 `DB_HOST=127.0.0.1`、`DB_PORT=<本機埠>` 連上去，`RouteDayLoader` 照舊一個路線日一個交易刪掉再寫入。正式站因此是累積的：每天多四列 `route_days`，舊的日子不動。讀頁面的人在交易提交前看到的是舊的那一天，提交後是新的，中間沒有半天。

理由：增量、冪等，`RouteDayLoader` 本來就有「寫入列數對不上 CSV 就失敗」的檢查；不用在 mini 再養一個 Postgres，也不用每晚 dump 一份隨天數線性長大的衍生表推到一台 1 vCPU 的機器。

替代方案：mini 放一個 postgres:16 容器當發佈資料庫，每晚算進去再 `bin/push-derived --push` 整份換（否決：零程式碼改動，但每晚推的量隨天數線性長大；mini 現有的 best100-db 是 postgres:17，推送的版本檢查會拒收，要另開容器；而且一旦 mini 是來源，筆電上誤跑一次 `--push` 就用四天的舊資料蓋掉正式站）。

### bin/nightly-load 不加參數只印計畫，--load 才寫，--recompute 重算

跟 `bin/push-derived` 同一套慣例：`bin/nightly-load` 開轉送、讀正式站、印計畫，什麼都不寫；`bin/nightly-load --load` 照計畫載入；`--recompute` 把正式站已有的路線日也算進要載入的清單（算法或 `config/route_page.yml` 兩端的性質改了之後用），可用環境變數 `ROUTE=<頁面路線 Id>` 限定一條路線，`ROUTE` 沒有 `--recompute` 就是用法錯誤。程式是 `bin/nightly-load`（Ruby，設環境變數後載入 Rails）加 `NightlyLoadCommand`（`app/models/`，跟 `DerivedLoadCommand`、`DerivedPushCommand` 同一層、同一種結構：`new(argv, …).run` 回結束碼，印的字走注入的 `out`）；ssh 轉送是 `ProductionTunnel`，等得到本機埠接受連線才交棒，結束時一定關掉。轉送目標從 `config/deploy.yml` 讀（`DerivedPushCommand.deploy_config`，`accessories.db.host` 與 `ssh.user`，沒設就用 Kamal 的預設使用者），不另寫設定。寫入那一行「<日> 寫入：趟次 …、折返停留 …、趟次站 …、兩端公廁 … 間、靜止格 … 格」的文字從 `DerivedLoadCommand` 抽成兩個指令共用，`bin/nightly-load` 在日期後面多印路線 Id。

替代方案：做成 rake task（否決：rake task 開不了轉送，而轉送要在第一個查詢之前開好；`bin/push-derived` 也不是 rake task）；`--recompute` 不做、重算用手開轉送跑 `derived:load`（否決：每次要在 production 環境手動開轉送、設四個環境變數，第一次算法改動就會有人記錯一個）。

### 要載入的路線日由 config/derived_days.yml 決定，讀檔視窗以隔天 02:00 為界

要載入的集合是：頁面路線（`RoutePage.route_ids`，設定裡的順序）× 日子（`first_day` 到「讀檔視窗已結束的最後一天」），扣掉設定裡跳過的日子，再扣掉正式站已有的路線日（`--recompute` 時不扣）。「讀檔視窗已結束的最後一天」= 以台北時間的現在減兩小時，取日期，再減一天：隔天 01:59 還不算，02:00 起算。`RawDayCheck` 只檢查「隔天的 01 時檔存在」，01:05 那個檔就在了但還在寫，排程每小時跑一次會撞到，所以多這條時間規則；`RawDayCheck` 照舊也做，它另外擋 `bus_data` 與靜態快照缺檔的日子。

設定檔是 `config/derived_days.yml`，沒有 `shared:`/`test:` 的分段（`config_for` 是 deep merge，test 段清不掉 shared 段的跳過日子，fixture 的 2026-10-23 會變成不能載入），由 `DerivedDays.from_config` 讀，`NightlyLoadCommand` 吃注入的 `DerivedDays`，測試給自己的。內容：

```yaml
# 每晚載入從哪一天開始，以及哪些日子不載入與理由。日期都是台北日。
first_day: 2026-10-19
skipped_days:
  2026-10-23: 薔琵颱風，公運處公告減班停駛，原始檔只有平日的三到四成，2026-10-24 決定不放上網站
  2026-10-24: 薔琵颱風，公運處公告減班停駛，原始檔只有平日的三到四成，2026-10-24 決定不放上網站
```

`first_day` 是 2026-10-19：採集從 10-18 15:11 開始，10-19 是第一個完整的台北日。跳過的日子一定要有理由，沒有理由是設定錯誤。新加進 `config/route_page.yml` 的頁面路線，下一個小時會從 `first_day` 起把每一天都算進正式站，這是想要的結果（路線頁要有歷史），代價是一次跑 N 天（估計每個路線日 6 秒，以第一次執行的紀錄為準）。

替代方案：只載入「昨天」（否決：失敗一次那一天就永遠缺，而且颱風日還是得有地方寫）；把颱風日載入並標成颱風日（否決於使用者 2026-10-24 的決定，標示方式另開 change）；`shared:`/`test:` 分段（否決，理由在上面）。

### 載入前比對 migration 版本，不一致就停

開好轉送、讀正式站之後、寫任何東西之前，比對正式站 `schema_migrations` 的版本集合與這份 checkout `db/migrate/` 的版本集合（`ActiveRecord` 的 migration context 給得出兩邊），不一致就印出正式站多的與 checkout 多的版本，結束碼非零，不寫。這跟 `bin/push-derived` 的 schema 檢查是同一件事，但比的是整個集合，不只最大值。mini 的 checkout 跟正式站的 image 不是同一個來源（image 從筆電的 HEAD 建），所以這條檢查是 mini 寫錯欄位之前的最後一道。

替代方案：比對 deploy 的 commit（否決：正式站沒有地方給 commit，加一個版本端點是另一件事；migration 版本已經擋掉會把資料寫壞的那一類差異，剩下的差異是分析定義不同步，見 Risks）。

### 一個路線日失敗不擋其他路線日，結束碼非零

`--load` 照日子升冪、同一天照設定裡的路線順序跑。一天先 `RawDayCheck.check!` 一次，不過就印一行「<日>：<原因>」、那一天所有路線都不試；過了，每個路線日各自跑 `RouteDayLoader`，失敗就印「<日> <路線 Id> 失敗：<訊息>」繼續下一個，寫進去的留著（loader 自己的交易）。最後印「載入 N 個路線日、失敗 M 個、原始檔不齊 K 天」；M 或 K 不是 0 就結束碼 1。原始檔不齊的日子每小時都會再報一次，直到有人處理（補檔或寫進跳過清單），這是故意的：那是只有人能解決的異常。`derived:load` 的「Range loading stops at the first failure」不改，那是給人看著跑的範圍載入。

替代方案：第一個失敗就停（否決：一條路線的壞資料不該擋其他三條，排程又沒有人在看）；原始檔不齊算成功（否決：正式站會靜靜少一天）。

### 同時只跑一個：tmp/nightly-load.lock

`NightlyLoadCommand` 先對 checkout 根目錄的 `tmp/nightly-load.lock` 取排他、非阻塞的 `flock`，取不到就印「另一個 bin/nightly-load 還在跑，這次不做」、結束碼 0，不開轉送。鎖在開轉送之前拿，整個執行期間持有。理由：手動的 `--recompute` 可能跑幾十分鐘，排程的那一個會在同一個路線日上跟它撞 `route_days` 的 unique index。

替代方案：靠 launchd 不重複起同一個 label（不夠，手動跑的不在 launchd 底下）。

### mini 以 production 環境跑、不放 credentials

`bin/nightly-load` 把 `RAILS_ENV` 設成 `production`（已經設成別的就停，寫正式站的程序不該掛別的環境的名字），沒有 `SECRET_KEY_BASE` 也沒有 `SECRET_KEY_BASE_DUMMY` 時設 `SECRET_KEY_BASE_DUMMY=1`（Rails 給 `assets:precompile` 用的正式開關，產一把本機用的 dummy；這個程序不簽任何 cookie 或 token），`DB_HOST` 預設 `127.0.0.1`、`DB_PORT` 預設 `TUNNEL_PORT`（它也有預設值）。`WEBSITE_DATABASE_PASSWORD` 與 `TURNAROUND_DATA` 一定要有，缺了在開轉送之前就以用法錯誤停。mini 上因此只有一個祕密：資料庫密碼，放在 mini 自己的環境變數檔（mode 600，repo 外），由包一層的 script 讀進環境；production credentials 的 key 不上 mini。production 環境不帶 key 能開，2026-10-25 在筆電拿掉 key 的副本實測過（Context 的表）。

替代方案：development 環境加 `DATABASE_URL`（否決：寫正式站的程序掛 development 的名字，Bullet 與 letter_opener 都會載入，而且 `database.yml` 的 production 段已經為 ssh 轉送寫好 `DB_HOST` 與 `DB_PORT`）；把 `config/credentials/production.key` 放到 mini（否決：多一把能解開 TDX 憑證與全部祕密的 key，而這個程序只需要資料庫密碼）。

### 正式站的 ssh 金鑰只准轉送到資料庫的埠

mini 另產一把 ed25519 金鑰只給這件事用，正式站 ssh 使用者的 `authorized_keys` 那一行加上限制選項：只開轉送、只准轉送到資料庫的埠、強制執行一個什麼都不做的指令，所以不能開 shell、不能跑指令、不能轉送到別的地方。mini 的 `~/.ssh/config` 用 `Host` 段指定這把 key 與 `IdentitiesOnly yes`，程式不帶 `-i`。這把 key 泄漏的代價等於資料庫密碼泄漏的代價，不會多出主機的 shell。

替代方案：正式站開一個專用的使用者（否決：多一個帳號要管，`restrict` 加 `permitopen` 已經把能做的事限到同樣小）；直接用 mini 現有的 GitHub 用 key（否決：一把 key 兩個用途）。

### bin/push-derived 拒絕刪掉正式站有、這台沒有的路線日

`DerivedPushCommand#check` 在既有的版本與 schema 檢查之後，多讀一次正式站 `route_days` 的 `(route_id, day)`，有這台沒有的就列出來（路線 Id、第一天到最後一天、幾天）、說明這些是每晚寫進正式站的路線日、整份推會刪掉它們、要重算用 mini 上的 `bin/nightly-load --recompute`，結束碼非零，不匯出、不備份、不換。不提供繞過的參數：正式站被清空時這個檢查自然通過，其他情況都是 `--recompute` 的事。

替代方案：淘汰 `bin/push-derived`（留到 Open Questions：`--recompute` 用過一次再決定）；加 `--replace-all` 繞過（否決：繞過的參數就是下一次事故的來源）。

### mini 的 checkout 每小時跟 origin/main，外部快照在 mini 另抓一份

包一層的 script 每小時先 `git pull --ff-only origin main`、`bundle check || bundle install`，再跑 `bin/nightly-load --load`，成功時打一個可選的 URL（環境變數有給才打）。deploy 的流程多一條：deploy 前把 commit push 到 GitHub，mini 下一個小時會跟上；中間那一小時若 schema 不一致，上面的檢查會停、下一個小時再試。`external/` 不在鏡射裡，mini 的 `data/` 沒有這三份快照，所以在 mini 上用 production 環境跑一次 `external:mrt_exits`、`external:public_toilets`、`external:office_calendar`（2026 與 2027 兩年，兩年都有設定網址），不碰資料庫；之後的更新是手動的（Non-Goals）。

替代方案：script 不 pull、deploy 流程手動更新 mini（否決：多一步會被忘，忘了就是 schema 檢查每小時報錯直到有人想起來）；mini 走筆電的鏡射（不適用：鏡射的方向是 mini 到筆電）。

### 詞彙表與文件改成每晚自動載入

**Supersedes**: ui-touchups / 詞彙表「路線頁」的定義改成人工載入、某一天與最近 7 天

`docs/spectra/LANGUAGE.md`「路線頁」定義裡「資料由人工載入：`bin/rails derived:load` 在筆電上算好，再用 `bin/push-derived` 推上正式站，所以至少晚一天，也不是每天自動更新」改成「資料由 Mac mini 每晚自動載入（`bin/nightly-load`），一天在隔天 02:00 讀檔視窗結束後的一小時內出現，所以至少晚一天」；「衍生表」的邊界「目前是手動執行，還沒有每晚排程」改成每晚由 mini 的排程算好直接寫進正式站。ui-touchups 當時把定義改成人工載入，是因為「每天更新」跟當時的事實不符；現在事實變了，定義跟著改，`home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」不受影響，首頁仍然不寫「每天更新」四個字。README 的架構一節「衍生表在筆電上算好，再推上正式站」、`analysis/README.md` 的 `derived:load` 段、AGENTS.md 的常用指令一起改。

### docs/decisions.md 加第 14 條

第 12 條不改寫，照該檔開頭的規則加一條「## 14. 衍生表每晚在 Mac mini 算，直接寫進正式站」，標 2026-10-25：在哪算、怎麼寫、為什麼不是 Droplet 或筆電、`bin/push-derived` 從此只在正式站清空時用得上、mini 上只有資料庫密碼一個祕密、第 11 條對 mini 營運細節的限制照舊。

## Implementation Contract

**指令**

- `bin/nightly-load`：印計畫，不寫。`bin/nightly-load --load`：載入。`--recompute` 可單獨（印重算計畫）或跟 `--load` 一起；`ROUTE=<頁面路線 Id>` 只能跟 `--recompute` 一起，給成員路線時訊息要說它是哪一頁的附屬路線、請用哪個 Id（跟 `derived:load` 同一句），給不是頁面路線的 Id 是用法錯誤。其他參數印用法、結束碼 1。
- 環境變數：`TURNAROUND_DATA`（必要）、`WEBSITE_DATABASE_PASSWORD`（必要）、`TUNNEL_PORT`（有預設值）、`DB_HOST`、`DB_PORT`、`RAILS_ENV`（沒設就是 production，設成別的就停）、`SECRET_KEY_BASE_DUMMY`（沒有 `SECRET_KEY_BASE` 時自動設 1）、`PATH`（要找得到 `duckdb`，找不到的訊息跟 `derived:load` 相同）。缺必要的環境變數、用法錯誤、設定檔不對、找不到 duckdb，都在開轉送之前停，結束碼 1。
- 執行順序：解析參數 → 鎖 → 讀設定、檢查環境變數與 duckdb → 開轉送（等本機埠接受連線，最多 20 秒；ssh 先結束或超時就印原因停，結束碼 1）→ 比對 migration 版本 → 讀正式站的路線日 → 印計畫 → （`--load`）逐路線日載入 → 印摘要 → 關轉送、放鎖。關轉送與放鎖在 `ensure` 裡，任何結果都做。
- 計畫印的內容，依序：正式站（`<user>@<host>` 的 `<資料庫名>`）與 migration 版本是否一致；頁面路線清單；日子範圍「`<first_day>` 到 `<最後一天>`（讀檔視窗已結束的最後一天）」與跳過的日子各附理由；正式站已有的路線日數與每條路線的第一天、最後一天、幾天；要載入的路線日數，按日子分組列出路線 Id；原始檔不齊的日子每天一行附 `RawDayCheck` 的訊息；最後一行「沒有動正式站；要載入就加 --load。」（`--load` 時不印這行）。
- `--load` 印的內容：每個路線日一行「`<日>` `<路線 Id>` 寫入：趟次 N、折返停留 N、趟次站 N、兩端公廁 N 間、靜止格 N 格」或「`<日>` `<路線 Id>` 失敗：`<訊息>`」，loader 自己印的註記（例如沒有路線軌跡）照舊；最後「載入 N 個路線日、失敗 M 個、原始檔不齊 K 天」。
- 結束碼：0 = 沒有要載入的、或全部寫入且沒有原始檔不齊的日子、或鎖被別人拿著；1 = 其他。

**選擇規則**

- 最後一天 = （台北時間的現在 − 2 小時）的日期 − 1 天。例：2026-10-26 01:59 → 2026-10-24；02:00 → 2026-10-25。
- 候選 = `first_day`..最後一天，去掉 `skipped_days`；每一天 `RawDayCheck.check!` 一次，失敗的日子整天不試。
- 要載入 = 候選日 × 頁面路線，去掉正式站已有的 `(route_id, day)`；`--recompute` 不去掉；`ROUTE=` 時路線只有那一條。順序：日子升冪，同一天照 `config/route_page.yml` 的順序。

**設定 `config/derived_days.yml`**

- 兩個鍵：`first_day`（`YYYY-MM-DD`）、`skipped_days`（鍵是 `YYYY-MM-DD`，值是非空字串的理由；可以是空的對應表）。缺鍵、日期格式不對、理由空白、多出來的鍵，都是設定錯誤：印出哪裡不對，結束碼 1，不開轉送。

**`bin/push-derived --push` 的新檢查**

- 在版本與 schema 檢查之後、匯出之前：正式站 `route_days` 有、這台沒有的 `(route_id, day)` 存在時，列出每條路線的 Id、第一天、最後一天、幾天，說明它們是每晚寫進正式站的、整份推會刪掉、要重算用 mini 上的 `bin/nightly-load --recompute`，結束碼 1，之後的匯出、備份、換掉都不跑。沒有這種路線日時行為不變。

**repo 外的檔案（照第 11 條，寫在筆電 repo 外的 ops 目錄，由使用者放到 mini）**

- 包一層的 shell script：設 PATH（Homebrew 的 bin、rbenv 的 shims）、進 website 的 checkout、讀環境變數檔（`set -a; . <檔>; set +a`）、`git pull --ff-only origin main`、`bundle check || bundle install`、`bin/nightly-load --load`，前面任何一步失敗就以非零結束，全部成功且環境變數 `NIGHTLY_LOAD_PING_URL` 有值時 `curl -fsS -m 10` 打它一次。
- 環境變數檔（mode 600）：`WEBSITE_DATABASE_PASSWORD`、`TURNAROUND_DATA`（mini 上 n-gear 的 `data/`）、可選的 `NIGHTLY_LOAD_PING_URL`、可選的 `TUNNEL_PORT`。
- LaunchAgent `tw.turnaround.nightly-load`：`ProgramArguments` 是那支 script，`RunAtLoad` true、`StartInterval` 3600，標準輸出與錯誤都寫到 mini 上 n-gear 資料目錄裡的紀錄檔（筆電的鏡射每小時會帶回來，從筆電就看得到紀錄）。

**驗收**

- `spec/models/derived_days_spec.rb`、`spec/models/nightly_load_command_spec.rb`（選擇規則、時間邊界、鎖、migration 比對、失敗不擋、摘要與結束碼，用注入的時鐘、路線清單、日子設定、loader、轉送；另一個標 `:duckdb` 的例子用 fixture 的 9001 與 2026-10-19 真的跑 loader）、`spec/models/production_tunnel_spec.rb`（argv、等埠、ssh 先結束的失敗、結束時關掉）、`spec/models/derived_push_command_spec.rb` 新增拒絕的例子。
- 使用者在 mini 上：`bin/nightly-load` 印出跟正式站一致的 16 個路線日與 2 個跳過的日子、要載入 0 個（2026-10-26 02:00 前）；02:00 之後跑一次 `--load`，四條路線 2026-10-25 各一行寫入，`curl -s https://bus.5xcamp.us/` 的路線卡最新資料日變成 2026-10-25。

**範圍**

- 在：上面列的指令、設定、檢查、文件、mini 與正式站的設定步驟。
- 不在：schema、migration、deploy 流程本身（只多「先 push」一句）、`derived:load` 的行為、分析 SQL、路線頁、外部快照的自動更新、通知服務。

## Risks / Trade-offs

- [整點時 compaction 正在把 `.jsonl` 換成 `.jsonl.gz`，DuckDB 讀到一半檔案不見] → 那個路線日失敗、結束碼 1，下一個小時重跑；loader 的交易保證正式站不會有半天。
- [main 上有別的 change 還沒 deploy 的 migration] → migration 比對停住、每小時報一次，直到 deploy；反過來 deploy 了還沒 push，mini 下一個小時 pull 到就好。殘餘風險：分析 SQL 或 loader 改了但沒有 migration，比對不會發現，mini 跟正式站的定義會差一天到下一次 pull 為止；要擋這個得有版本端點，另開 change。
- [新的頁面路線寫進設定後，下一個小時從 `first_day` 起全算] → 估計每個路線日 6 秒（筆電上 DuckDB 5.3 秒加寫入；mini 上以第一次執行的紀錄為準），一百天約 10 分鐘；期間排程的其他路線日等它做完。
- [`--recompute` 的時間隨天數線性長] → 16 個路線日估 2 分鐘，一年四條路線約 1,460 個路線日估 2.5 小時（估計，同上）；一個路線日一個交易，中途可以停、重跑接著做。
- [mini 的採集或靜態快照某天沒跑] → 那一天每小時報「原始檔不齊」直到寫進跳過清單，紀錄會吵，這是故意的。
- [2027-01-01 起沒有 2027 的辦公日曆快照] → loader 失敗、每小時報，直到在 mini 上抓；這次先把 2027 抓好。
- [資料庫密碼與受限的 ssh key 在 mini 上] → 環境變數檔 mode 600、key 只能轉送到資料庫的埠，泄漏的代價等於資料庫密碼泄漏，不多出主機 shell。
- [轉送的本機埠在 mini 上被佔] → `ExitOnForwardFailure` 讓 ssh 直接結束，指令印原因停；用 `TUNNEL_PORT` 換。
- [launchd 的 PATH 只有系統目錄] → script 自己設 PATH；`duckdb` 找不到的訊息跟 `derived:load` 相同。
- [寫入期間正式站的負載] → 每個路線日 COPY 加 INSERT 數秒，MVCC 讓讀取不等寫入；每天四個路線日，可忽略。
- [`SECRET_KEY_BASE_DUMMY` 讓 production 環境產一把假的 key] → 這個程序不簽任何東西；若日後有程式在載入時用到 `secret_key_base`，會在 mini 上以 dummy 簽，要在那時改成給真的 `SECRET_KEY_BASE`。

## Migration Plan

1. 筆電：程式、測試、文件（這個 change 的任務）。沒有 migration，正式站不用為了這件事 deploy；commit 與 push 由使用者做，mini 的 script 會 pull。
2. mini（使用者操作）：`brew install duckdb`、`brew upgrade ruby-build`、`rbenv install 4.0.9`、clone website、`bundle install`（`BUNDLE_WITHOUT=development:test`，pg gem 指向 Homebrew 的 libpq）、三份外部快照、產 ed25519 key。
3. 正式站（使用者操作）：ssh 使用者的 `authorized_keys` 加受限的那一行；mini 上試開一次轉送。
4. mini：放 script、環境變數檔、plist；先手動跑 `bin/nightly-load` 看計畫、再 `--load` 跑一次；`launchctl bootstrap` 載入 LaunchAgent，`launchctl print` 看狀態。
5. 第一個自動出現的日子是 2026-10-25（10-26 02:00 之後）；驗收看首頁與紀錄。
6. 退回：`launchctl bootout` 卸掉 LaunchAgent 即停止；已寫進正式站的日子是正確資料、留著；要拿掉某一天只能在 mini 上用轉送跑 rails runner 刪 `route_days` 那一列（連帶刪子表），這個 change 不提供指令。

## Open Questions

- 成功時打的 URL 用哪個 dead man's switch 服務，以及沒收到時通知到哪裡：使用者決定，不影響程式。
- `bin/push-derived` 要不要淘汰：等 `--recompute` 在正式站用過一次。
- 颱風日要不要標示而不是跳過：另開 change。
- 三份外部快照在 mini 上要不要自動更新：另開 change 或寫進 script。
- mini 上一個路線日的實際秒數與記憶體：第一次執行的紀錄補回這份 design 的 Context。
