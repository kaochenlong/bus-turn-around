## Why

這個 change 服務三樣交付物的第一樣：路線健檢卡在網站上的路線頁。它是把路線頁做到全台北市之前的一次試跑。用到的資料都已經在資料根目錄裡，不需要新資料：

- n-gear 從公運處 data.taipei 收的到離站（`bus_event`）與車機 GPS（`bus_data`），用來重建趟次、折返停留，以及車在折返停留期間停在哪裡、停了多久。
- 每天 04:30 的靜態快照（`GetRoute.gz`、`GetStop.gz`、`GetPathDetail.gz`），提供路線清單與站序。

2026-10-24 討論「能不能做到全台北市的路線」時，結論是資料與算力都夠，卡住的是每一頁都要先人工查證兩端是停車還是直接折返。這是 `zhongshan-turnaround-ends` 的決定「折返點的性質是逐路線查證後寫進設定的事實，不從資料推」，而且它還有效。它的理由有兩個：

- 要自動推，得先在幾條路線上看過推得對不對；當時只有一條路線，寫成規則等於拿一個樣本定門檻。
- 推錯了沒有人會發現。

全市約 400 條路線、800 個端點（10-22 的快照有 416 個路線 Id，398 個當天有事件，量到的），人工查不完。使用者同意的方向是改成從資料判斷：判斷的根據放上頁面，分不清的端點標成待查證，人工查過的以設定為準。

在那之前，要先回答那條決定要求的問題：用跟人工查證一樣的證據、一條事先定好的規則，全路網有多少端點分得清楚，有多少要人看。光看折返停留的中位數不夠：

- `route-251-pages` 已經寫過，市區端「停兩分鐘」與「開過去就走」從分佈分不出來。
- 討論時用中位數粗算 10-22 全路網，當天至少 10 筆的 485 個端點裡，有 121 個落在 4 到 10 分鐘之間（粗算，沒有切趟次）。

所以要用人工查證時看的 GPS：每筆折返停留裡車最長靜止多久、離兩站最遠多遠。

為什麼是現在：批次載入、正式站推送、首頁列表，都要等這個答案。這個數字也決定下一個 change（把判斷放上頁面）值不值得做、門檻要不要改。

## What Changes

- **新的 rake task**：`bin/rails survey:end_natures FROM=<台北日> TO=<台北日>`，可以另外給 `ROUTES=<路線 Id,…>` 與 `OUT=<目錄>`，資料根目錄由 `TURNAROUND_DATA` 給。它的範圍與行為：
  - 範圍：每一天、那一天 `GetRoute.gz` 裡的每一條路線。設定裡掛在別的路線底下的成員路線，跟它的頁面路線一起算。
  - 每個路線日照 `derived:load` 的分析跑一次：編號階段、`mrt_overlap.sql`、兩端性質都給 `unknown` 的 `turnaround_facilities.sql`，再加上新的證據檔。
  - 結果寫到 `OUT`（預設 `tmp/end-natures/`），不寫資料庫，也不改任何頁面。
- **每一筆折返停留的證據**，照 `route-251-pages` 人工查證時量的：
  - 最長靜止：連續回報速度 0、相鄰兩筆相距 50 公尺內的那一段最長持續多久。
  - 最遠離站：GPS 離「本趟末站、下一趟起站」裡較近那一站的距離，取最大值。
  - 兩站距離：本趟末站到下一趟起站的直線距離。
- **每一端的配對排除數**：結束在這一端的配對各有幾組沒算成折返停留，也記下來，包括「兩趟之間跑了別的路線」。307 合成一頁的依據就是這種配對：分開算時大量配對被判成跑了別的路線，全是去跑 307西藏三民（2026-10-22 一天版量到 60 組，當時的 SQL 還沒去重，見 `02-route-307-page` 的 design）。這個數字可以標出哪些路線像 307 一樣要考慮合併。
- **事先定好的判斷規則**，門檻寫在 `analysis/params.sql`，數字取自 8 個人工查證過的端點：
  - 一筆折返停留的最長靜止「超過」2 分鐘，就算這一筆停下來過。
  - 每一端把調查的日子合起來算。有 GPS 的折返停留不到 20 筆，是待查證（樣本太少）。
  - 停下來過的比例不超過 5% 是直接折返，至少 50% 是停車，介於兩者之間是待查證（介於兩個門檻之間）。
- **報告**：一個 CSV，一端一列，列出證據、判斷、理由；有設定的路線另外列出設定值與是否相符。指令最後印摘要：三種判斷各幾端、設定裡每一個端點的設定與判斷、跑失敗的路線日。
- **用 2026-10-19 到 10-22 四個平日跑一次**，結果寫進 design 的「調查結果」。
  - 10-23 起的資料量明顯偏低：10-23 的 `bus_event` 約 15 MB，10-19 到 10-22 每天約 37 MB（量到的），所以不用。
  - 設定裡 8 個端點的判斷全部跟設定相同，才算規則通過。不同時先停下來，用 `/spectra-ingest` 改規則或門檻，不改設定。
- **小幅抽出共用的程式**：`derived:load` 找最新外部快照與檢查一天能不能算的程式抽出來給兩邊共用，訊息不變；`lib/analysis_run.rb` 多一個只跑 `params.sql` 與指定檔案的用法。
- **詞彙表**：`docs/spectra/LANGUAGE.md` 補「最長靜止」、「最遠離站」與「待查證」。

資料限制與假設：

- 車不等於人：最長靜止量的是車停了多久，不是駕駛休息了多久。這次判斷的是「車會不會在這一端停下來等」。
- GPS 有間隔：n-gear 每 10 秒抓一次，車機回報也有空檔，最長靜止從一段的第一筆量到最後一筆，會比實際少，最多少一個回報間隔。這會讓判斷偏向直接折返，正是代價最高的錯（把只停兩分鐘的端點標成直接折返，等於把問題藏起來），所以報告每一端都列最長靜止的中位數與最大值，不只列判斷。
- 漏站：折返停留要有本趟末站的到站與下一趟起站的離站，漏了就少一筆。班次少的路線會因此樣本太少，報告把它跟「介於兩個門檻之間」分開算。
- 跨小時重複：到離站與 GPS 都照既有規則用 `(BusID, DataTime)` 去重。
- 刷卡率：這次不用車上人數，跟刷卡率無關。

## Non-Goals

- 把判斷放上路線頁、寫進衍生表，或改 `config/route_page.yml` 的設定值。`zhongshan-turnaround-ends` 那條決定在這個 change 裡照舊有效，要不要推翻、怎麼推翻，由看過調查結果之後的下一個 change 決定。
- 決定哪些路線 Id 要合成一頁：這次只記下「兩趟之間跑了別的路線」的配對數，供之後判斷。
- 把 `gps_reports` 從 `turnaround_facilities.sql` 拆出來、把 `haversine_meters` 移到 `params.sql`。規格 `derived-tables` 寫明 `bus_data` 只由 `turnaround_facilities.sql` 讀，拆法留給要重排設施那一段的下一個 change。
- 讓全路網跑得更快（例如一天只讀一次原始檔、所有路線一起算）、排程、推到正式站。
- 為循環路線、預約公車、區間車另外定義規則：它們照同一條規則調查，有問題的會出現在報告裡。

## Capabilities

### New Capabilities

- `end-nature-survey`：全路網兩端性質的試跑。範圍包括 rake task 的用法與前置檢查、要調查哪些路線、每筆折返停留的證據、事先定好的判斷規則，以及報告與摘要。

### Modified Capabilities

（無：抽出共用的程式之後，載入衍生表那個指令的行為與訊息都不變。）

## Impact

- 新增 analysis/end_nature_evidence.sql、analysis/end_nature_export.sql、analysis/end_nature_survey.sql。
- 新增 app/models/end_nature_survey_command.rb、app/models/newest_snapshot.rb、app/models/raw_day_check.rb、lib/tasks/survey.rake。
- 修改 analysis/params.sql（判斷規則的門檻）、lib/analysis_run.rb（不跑編號階段的用法）、app/models/route_day_loader.rb（改用 NewestSnapshot）、app/models/derived_load_command.rb（改用 RawDayCheck）。
- 新增 spec/analysis/end_nature_evidence_spec.rb、spec/analysis/end_nature_export_spec.rb、spec/analysis/end_nature_survey_spec.rb、spec/models/end_nature_survey_command_spec.rb、spec/models/newest_snapshot_spec.rb、spec/models/raw_day_check_spec.rb。
- 修改 spec/analysis/params_spec.rb、spec/analysis/analysis_run_spec.rb。
- 修改 docs/spectra/LANGUAGE.md、analysis/README.md。
- 調查的輸出在 `tmp/end-natures/`，不進版控。不新增 gem、npm 相依或 migration；不需要重跑 `derived:load`，也不需要 `bin/push-derived`。
