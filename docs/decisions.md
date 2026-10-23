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
