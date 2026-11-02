# 決定與理由

每一條都是 2026-10-18 定的。之後改變要在這裡記一筆，不要只改程式。

## 1. 採集器獨立成 gem（n-gear），不是 Rails 裡的 job

- 它是整個系統唯一有時間壓力的程序，不該跟 web app 共用生命週期。Rails 部署一次重啟一次，collector 就斷一次。
- 每 10 秒一圈的迴圈不需要載入 Rails，用 stdlib 的 net/http、zlib、json 就寫得完，不需要任何 runtime dependency。
- 別人也用得到，像是研究生、其他縣市的公民團體，`gem install` 就能開始收同一批資料做別的題目。
- 也好測，真實快照可以直接當 fixture，fetch 層注入假的 client，不用 WebMock。

## 2. 原始事件寫檔，衍生結果才進 PostgreSQL

- 原始檔是唯一的資料來源，可以公開釋出，也可以給 Python 或 R 直接讀，任何衍生結果隨時都能從頭重算。灌進資料庫的話，就多了一份可能跟檔案對不上的副本。
- 每小時一個 JSONL，兩小時後去重壓成同名 `.jsonl.gz`。collector 完全不依賴資料庫。
- 健檢卡、試算器要給網頁讀的是幾千到幾萬列的衍生表，那才需要並行讀取、交易、ActiveRecord。

## 3. 分析引擎用 DuckDB，不用 PostgreSQL

- 工作負載是 OLAP：對幾百萬行做掃描、window function、group by。欄式向量化引擎比列式儲存快一到兩個數量級，差距大到決定「能不能每晚重算全部」。GPS 一天約 600 萬行。
- DuckDB 直接讀 `.jsonl.gz` 與 Parquet，glob 一整個月就是一張表，不用先 COPY 進資料庫、建索引、vacuum。
- 不需要維運，沒有 server process，排程就是起一個 process 跑 SQL 然後結束。
- spatial 擴充涵蓋軌跡重疊與站牌到出口距離，不用 PostGIS。
- 限制有四個：
  - 同時只能有一個寫入者。
  - `.duckdb` 檔不要當長期儲存（版本之間格式會變），儲存用 Parquet。
  - Ruby 的 `duckdb` gem 是 native extension，要先裝 libduckdb。
  - 對幾十個檔案即時查要幾秒，所以網頁一定要查預先算好的表。

## 4. 檔案按台北時間分區，`_fetched_at` 用 UTC

- 資料裡的 DataTime 是台北時間，分析按台北日切，用 UTC 分區的話，每天換檔的時間點會落在台北早上八點。
- 每一行是市府的原始欄位，一個都不改，只多加抓取時刻。

## 5. 去重的契約：原始檔「允許重複、不漏」

- 採集時用記憶體滑動視窗（30 分鐘）加啟動暖機（讀回視窗內既有檔案的 key）。
- compaction 時以 (BusID, DataTime) 留第一筆、保持原本的順序，跨小時的重複不處理。
- 下游一律再去重一次。寧可重複也不要為了去重而漏。

## 6. 輪詢 10 秒，帶 ETag 條件式請求

- 實測 blob 大約每 5 到 6 秒更新，55 秒抓一次會漏站。10 秒是在「跟得上到離站事件」跟「對市府主機有禮貌」之間取的平衡。GPS 比到離站更密，10 秒會漏掉一部分 GPS 點，這點可以接受。
- 全路網一起收，不只收打算分析的路線，因為沒收到的事件永遠補不回來。

## 7. gem 內的 compaction 用 gzip，Parquet 留給分析端

- gzip 不需要額外依賴、可以還原，DuckDB 也能直接讀，Parquet 在 Ruby 裡則要 Arrow 的 native 依賴。
- 壓縮比實測 10 到 12 倍，已經把一天從 2 到 3 GB 壓到兩三百 MB。要更小、更快的欄式格式，由 DuckDB 在分析端轉。

## 8. 排程用 launchd，部署在一台不會睡的 Mac

- 採集器一個 LaunchAgent（KeepAlive、RunAtLoad），compaction 另一個（StartInterval 3600 加 RunAtLoad，不用 StartCalendarInterval，機器睡過頭時前者會補跑一次）。
- plist 裡 ruby 寫絕對路徑，因為 launchd 的 PATH 只有系統目錄。
- 停止靠 TERM，因為從非互動 shell 用 `&` 起的程序會繼承「忽略 INT」，所以 CLI 同時 trap INT 與 TERM，睡眠切成半秒一段。

## 9. 命名

- 專案：折返點 Turnaround。終點折返是休息發生的地方，也是這套制度該轉彎的地方。英文同時有車輛折返和局面翻轉的意思。副標候選「末站有廁所嗎」。
- 採集器：空檔 Neutral。班表裡的空檔是司機唯一能休息的地方，車子打空檔引擎才真的歇著。雙關只在中文成立，英文 neutral 只有排檔那層意思。
- gem：`n-gear`，N 檔就是空檔，模組是 `NGear`，執行檔是 `ngear`。rubygems 查過 `neutral` 已被佔，`n-gear`、`ngear`、`n_gear`、`turnaround` 都沒人用。連字號在 Ruby 慣例上代表命名空間延伸，用 `lib/n-gear.rb` 當入口即可。

## 10. 程式碼全英文，README 中英各一份

- 因為準備開源，註解、訊息、CLI 輸出、gemspec 都用英文。
- 公運處的正式 feed 名稱保留在 `title_zh`，`ngear feeds` 會把中英兩種名稱並列，因為查對 API 文件要靠它。
- 每輪摘要那一行的格式有契約測試鎖住，下游要拿它算更新週期。

## 11. 文件放哪裡

- `README.md`：給人看的入口。`docs/spectra/config.yaml` 的 `context`：給 AI 看的初衷，每次 propose 都會被餵進去。`docs/`：長文參考。
- 實作計畫不放 docs，用 Spectra change。n-gear 是獨立 repo、沒有 Spectra，繼續用 IMPLEMENTATION_PLAN.md，並且加進 gitignore。
- 主機、路徑、PID 這類營運細節不進公開 repo。

## 12. 網站部署在 DigitalOcean 新加坡的一台 Droplet

- 2026-10-24 定的。網站用 Kamal 部署到 sgp1 的一台 Droplet（Ubuntu 24.04、1 vCPU、2 GiB），kamal-proxy 終止 TLS、向 Let's Encrypt 簽證書；Cloudflare 只做 DNS，不開代理。
- Postgres 以 Kamal accessory 跟網站跑在同一台（postgres:16，對齊開發用的版本），資料庫的埠只綁主機的 127.0.0.1。不用 Managed PostgreSQL、不開備份：衍生表隨時能從原始檔重算（第 2 條），資料庫壞掉的代價是重灌一次。
- 主機不裝 DuckDB、不放原始檔。衍生表由筆電算好（`derived:load`）再推上去，第一次是把開發資料庫的五張表 pg_dump 再 pg_restore；之後用 `bin/push-derived --push`，整份換成開發資料庫的衍生表（`route_days` 與沿外鍵連到它的每一張表）。deploy 不動資料，要推的是三種時候：change 新增或改了衍生表、改了算法或 `config/route_page.yml` 兩端的性質、要讓正式站出現新的日子或路線；開發資料庫裡要剛好是正式站該有的日子。每晚自動跑要在哪裡算，另開 change 決定。
- 採集器 n-gear 留在 Mac mini（第 8 條照舊），不跟網站同機。
- image 在筆電建、從 git HEAD 的乾淨 clone 建、推到 Kamal 的本機 registry，不用外部 registry；每個 image 對應一個 commit。
- 密碼只在 production credentials：`.kamal/secrets` 用 `config/credentials/production.key` 當 RAILS_MASTER_KEY，資料庫密碼從 credentials 的 `database.password` 讀。這個專案是 per-environment credentials，`config/master.key` 只解共用那份。
- IP 與網域寫在 `config/deploy.yml`：reserved IP 同時是 DNS 與部署目標，換機器只搬 IP。兩者從 DNS 就查得到，不是秘密。第 11 條「主機、路徑、PID 這類營運細節不進公開 repo」照舊適用於採集器那邊。

## 13. 行駛時間與折返停留從到離站事件算，GPS 用來定折返點的位置與性質

- 2026-10-24 記的，做法從第一張健檢卡起就是這樣，這裡補理由。趟次是同一車牌從起站離站到末站到站，行駛時間、折返停留、來回一趟、週期全部從到離站事件（`bus_event`）的時刻算；定時回報的 GPS（`bus_data`）只拿來找折返停留期間車停在哪裡、畫靜止格、查證每一端是停車還是直接折返。
- 自己量到的理由排前面：到離站事件帶站牌與進出站旗標，趟次的起訖直接讀得到；GPS 我們 10 秒才抓到一點，起訖要靠距離門檻猜站牌，站區密集處猜錯就差一站。2026-10-18 實測相隔 55 秒抓兩次，1,072 台共同出現的車裡 505 台站牌變了，有車直接從某站跳到下下站（`docs/data-sources.md`）。
- 事件也會漏，停車端的離站尤其常漏：中山幹線 2026-10-19 到 10-22 四個平日有三成去程趟次的起點是到站時刻，所以週期用到站不用發車（詞彙表「週期」）。缺事件的趟次標 `start_from_arrival`、`end_from_departure`，行駛時間與來回一趟把它們排除並計數，寧可少算不猜。
- 文獻排第二：Furth 與 Muller 2007 的班表寬裕量建議（行駛時間平均加一個標準差、循環時間平均加兩到三個標準差）以趟次的起訖時間為輸入，跟這個趟次定義相容，引用在 `docs/background.md`。TCRP Report 113 是否明文建議用事件不用定時回報，原文還沒讀，列在 background.md 的待確認。
- 2026-10-26 補：站間車速（change stop-to-stop-speed）不用到離站事件，改從 GPS 沿登記的路線軌跡量。中山幹線 2026-10-22 前後 1 秒內有 GPS 點的到離站紀錄裡，進站紀錄出現時車還在站前，離站牌中位數 93 公尺；離站紀錄出現時已經開出中位數 36 公尺（進站 5,551 筆、離站 5,523 筆，量到的）。「這站離站到下一站進站」只涵蓋站距扣掉一百多公尺，拿站距去除會把車速算大。同一台車的 GPS 約 20 秒一點，沿路線軌跡量兩站之間的距離與時間夠用。行駛時間與折返停留照舊從到離站事件算；到離站紀錄的位置對它們有多少影響，另開 change 量。

## 14. 衍生表每晚在 Mac mini 算，直接寫進正式站

- 2026-10-25 定的。第 12 條留下的「每晚自動跑要在哪裡算」由這一條回答，第 12 條本身不改寫。
- 在 Mac mini 上算：原始檔就在那台，沒有鏡射的延遲；它不會睡，24 GiB 放得下 DuckDB 的峰值（筆電上量到一個路線日 2.98 GB）。不在 Droplet 算，因為整台 2 GiB 放不下這個峰值，第 12 條也說主機不裝 DuckDB、不放原始檔；不在筆電算，因為筆電會睡，鏡射最多晚一小時。
- `bin/nightly-load` 透過 ssh 轉送連正式站的 PostgreSQL，用 `derived:load` 的 `RouteDayLoader` 寫入正式站還沒有的路線日，一個路線日一個交易，所以正式站是累積的，舊的日子不動。不加參數只印計畫，`--load` 才寫，`--recompute` 連已有的路線日一起重算。
- 排程是 mini 的 launchd，每小時跑一次（`StartInterval` 3600 加 `RunAtLoad`，同第 8 條）。指令是冪等的，沒有要載入的路線日就只讀正式站一次，漏掉的日子下一個小時補；一天要等隔天 02:00 讀檔視窗結束才算。
- 從哪一天開始、哪些日子不載入與理由，寫在 `config/derived_days.yml`。
- `bin/push-derived` 從此只在正式站清空時用得上：正式站有它沒有的路線日時它拒絕推，因為那些是每晚寫進去的，整份換掉會把它們刪掉。
- mini 上只有一個祕密：正式站的資料庫密碼，放在 repo 外、mode 600 的環境變數檔。production credentials 的 key 不上 mini；mini 連正式站的 ssh 金鑰只准轉送到資料庫的埠，不能開 shell。
- 第 11 條「主機、路徑、PID 這類營運細節不進公開 repo」照舊：排程的 plist、包一層的 script 與環境變數檔都放在 repo 外。

## 15. 健檢卡的定稿在 Mac mini 印好存進資料庫，印過不改

- 2026-11-02 定的。第 12 條與第 14 條照舊，這一條補上它們沒有涵蓋的一種資料。
- 月卡要能引用，每個人要拿到同一份，所以定稿成 PDF，不靠瀏覽器列印：頁面每次打開都重算，定義或資料一改，同一個月的數字就變，不同瀏覽器印出來的版面也不同。班表頁與當天調度是每次內容都不同的單子，照舊用瀏覽器列印。
- 在 Mac mini 用 headless Chrome 開正式站的月卡頁印。mini 已經有 Chrome，正式站不用多裝東西。不在 Droplet 印：要把 Chrome 裝進 image，2 GiB 的機器有放不下它的峰值的風險，而且 Droplet 分不出一天是還沒載入還是不會來了。不加 Prawn、Grover 這類 gem：新依賴，部署要多裝東西。
- PDF 存正式站資料庫，下載時直接回傳，不跑 Chrome。位元組放在自己的表 `route_card_pdfs`：讀 `route_cards` 的地方都整列讀，放在同一張表的話，每開一次月卡頁就多讀每個舊月份的檔。資料庫是 mini 唯一到得了正式站的路（第 14 條）。存 Kamal 的 volume：mini 寫不進去，也跟資料庫在同一台機器上，沒有多一層保護。存 R2 這類外部儲存：mini 要多一個祕密，下載量大到不想經過網站，或不想只靠 mini 留備份時再重新考慮。
- 每小時檢查，資料到齊才印，不固定日期：`bin/monthly-cards --print` 接在 `bin/nightly-load` 後面跑，一個月實際上只印一次。固定日期在載入停著的時候會把缺資料的月份定稿。兩個指令共用一把鎖，手動 `--recompute` 跑的時候不印。
- 印過的版本不再改，更正是新的版本並寫原因。定義改了不用出新版：舊檔是當時的數字，下個月的逐月表會註明。
- 第 12 條「資料庫壞掉的代價是重灌一次」不適用於 `route_cards` 與 `route_card_pdfs`：定稿的檔重算不出同一份。所以 mini 上留一份 PDF 與一份 JSON（列上的涵蓋、摘要、程式版本、印製時間與原因），絕不覆寫；mini 上有資料庫沒印過的版本時不印，要先 `bin/monthly-cards --restore` 存回去。資料庫重建時先等衍生表載回去，再跑 `--restore`。
- 存下來的摘要與程式版本從頁面讀，不是 mini 自己算的：mini 的 checkout 跟著 origin/main，正式站要 deploy 才換版，兩邊可以是不同版。
- 第一份是 2026 年 10 月，寫在 `config/route_cards.yml`。資料從 10-19 開始收，10 月只有 7 個平日，印出來標部分月份，第 1 頁寫明少了哪幾天。
- 第 11 條照舊：接上排程的 script 放在 repo 外。
