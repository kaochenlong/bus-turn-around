<!--
每條任務寫兩件事：做完之後哪個行為看得到、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
前置：01-pass-through-wording 要先 apply 並 archive。這個 change 的摘要文字與詞彙表用它定的「直接折返」，兩個 change 也都改詞彙表的「起站、末站、折返點、調度站」那一條。
同一個工作目錄可能有別的 session 在 apply（ui-touchups、buffer-trade-cost-curve）：標任務完成時用 `spectra task done <任務> --change 02-end-nature-survey --file <檔>` 列出這條任務改的檔。
-->

## 1. 共用的程式（行為不變）

- [x] 1.1 套用 design「找快照與檢查日子的程式抽出來共用」的快照那一半：新增 `NewestSnapshot.find(data_root:, directory:, label:, task:)`，回傳 `NewestSnapshot::Snapshot`（`path`、`day`），找不到時丟 `NewestSnapshot::Missing`，訊息是「沒有…快照：先跑 …」；`RouteDayLoader` 找捷運出入口與公廁快照改用它，接住後照舊丟自己的 `Error`，訊息一字不改。先寫 `spec/models/newest_snapshot_spec.rb`：檔名日期最新的那一份被選中、不是 `YYYY-MM-DD.csv` 的檔不算、目錄空的或不存在時丟 `Missing` 並帶標籤與指令，這些例子要在新增類別之前失敗。驗證：`bundle exec rspec spec/models/newest_snapshot_spec.rb spec/models/route_day_loader_spec.rb` 全綠，後者一個例子都不用改。
- [x] 1.2 套用 design「找快照與檢查日子的程式抽出來共用」的檢查日子那一半：新增 `RawDayCheck.check!(data_root:, day:)`，照 `DerivedLoadCommand` 現在的順序與訊息檢查那一天的 `bus_event` 小時檔、隔天的 01 時檔、那一天的 `bus_data` 小時檔、靜態快照的 `GetRoute.gz`、`GetStop.gz`、`GetPathDetail.gz`，不符時丟 `RawDayCheck::Failure`；`DerivedLoadCommand` 改用它。先寫 `spec/models/raw_day_check_spec.rb`，用 fixture 的資料根目錄：2026-10-19 通過；2026-10-20 失敗，訊息說隔天沒有 01 時檔。驗證：`bundle exec rspec spec/models/raw_day_check_spec.rb spec/models/derived_load_command_spec.rb` 全綠，後者一個例子都不用改。
- [x] 1.3 套用 design「AnalysisRun 多一個不跑編號階段的用法」：`AnalysisRun.sql` 與 `AnalysisRun.run` 多一個關鍵字參數 `stages:`，預設 `true`，組出的 SQL 跟現在逐字相同；`stages: false` 時只有變數設定、`params.sql` 與 `extra_files`。先在 `spec/analysis/analysis_run_spec.rb` 加兩個例子，一個斷言預設時 SQL 不變，一個斷言 `stages: false` 時沒有任何編號階段檔的內容；第二個要在改程式之前失敗。驗證：`bundle exec rspec spec/analysis/analysis_run_spec.rb spec/analysis/cli_spec.rb` 全綠。

## 2. 證據與判斷的 SQL

- [x] 2.1 套用 design「判斷規則與門檻事先寫進 params.sql」：`analysis/params.sql` 加 `nature_still_minutes`（2）、`nature_min_layovers`（20）、`nature_pass_through_max_share`（0.05）、`nature_stop_min_share`（0.5），註解寫出 design 那四點根據。先在 `spec/analysis/params_spec.rb` 加一個例子斷言四個值，看到它失敗再改。驗證：`bundle exec rspec spec/analysis/params_spec.rb` 全綠，包括「其他 SQL 檔不出現這些常數的字面數字」那個例子。
- [x] 2.2 [after: 2.1] 實作 Layover evidence，套用 design「一筆折返停留的證據沿用人工查證的量法」與「每一端另外記配對的排除數」：新增 `analysis/end_nature_evidence.sql`，建 view `layover_evidence`（每筆折返停留一列，欄位照 design Implementation Contract 的 `layovers.csv`，去掉 `route_id` 與 `day`）與 `end_pair_counts`（頁面路線每個方向一列，五種 category 的配對數）。先寫 `spec/analysis/end_nature_evidence_spec.rb`，在 `mrt_overlap.sql` 與 `turnaround_facilities.sql`（兩端 `unknown`）之後跑這個檔，斷言規格的 Scenario「Stopping end of the fixture day」（Example 那張表的四列與另外 6 筆沒有回報）、「Other end of the fixture day」、「Moving reports split a standstill」、「A jump beyond the radius splits a standstill」（照 `spec/analysis/turnaround_facilities_spec.rb` 的寫法換掉 `trips` 與 `gps_reports`）、「Trip pairs counted per end」，另加「有回報但沒有速度 0 時最長靜止是 0.0」。這些例子要在新增 SQL 檔之前失敗。驗證：`bundle exec rspec spec/analysis/end_nature_evidence_spec.rb` 全綠。
- [x] 2.3 [after: 2.2] 證據寫成檔：新增 `analysis/end_nature_export.sql`，把 `layover_evidence` 與 `end_pair_counts` 寫成 `survey_dir` 底下的 `layovers.csv` 與 `ends.csv`，欄位、排序、時間格式照 design Implementation Contract。先寫 `spec/analysis/end_nature_export_spec.rb`：fixture 日 2026-10-19 的 9001（成員 9050）寫出 `layovers.csv` 18 列（方向 0 有 10 列、方向 1 有 8 列）、`ends.csv` 2 列（`route_ids` 是「9001・9050」、`route_name` 是測試幹線、末站是戊站與甲站），兩個檔的表頭照 design 的欄位順序，跑兩次的位元組相同，而且健檢卡的檢查用 CSV 不變。驗證：`bundle exec rspec spec/analysis/end_nature_export_spec.rb` 全綠。
- [x] 2.4 [after: 1.3, 2.1] 實作 Inferred end nature 與報告的 CSV，套用 design「報告與摘要的欄位與文字」的報告那一半：新增 `analysis/end_nature_survey.sql`，讀變數給的 `layovers.csv` 清單、`ends.csv` 清單與 `configured.csv`，合併所有日子，照 `params.sql` 的四個常數判斷，寫出報告，欄位與順序照 design。用 `AnalysisRun.run(…, stages: false)` 跑。先寫 `spec/analysis/end_nature_survey_spec.rb`，在測試的暫存目錄寫證據 CSV，斷言規格 Scenario「Shares against the thresholds」Example 那張表的六列、「Days pooled」、「Layovers without reports left out」、設定相符時 `agrees` 是 `true`、不符時（包括待查證）是 `false`、沒有設定時是空的、百分位數線性內插（例如 1、2、3、4 分鐘的 p50 是 2.5）、沒有回報時比例與最遠離站是空的。這些例子要在新增 SQL 檔之前失敗。驗證：`bundle exec rspec spec/analysis/end_nature_survey_spec.rb` 全綠。

## 3. 指令

- [x] 3.1 [after: 1.1, 1.2] 實作 Survey task invocation：新增 `lib/tasks/survey.rake` 的 `survey:end_natures`，交給 `EndNatureSurveyCommand.new(ENV.to_h).run`。前置檢查的順序、用法說明與訊息照 design Implementation Contract 與「報告與摘要的欄位與文字」。先寫 `spec/models/end_nature_survey_command_spec.rb`，資料根目錄用 `spec/fixtures/analysis`，`OUT` 用測試自己的暫存目錄，斷言規格的 Scenario「Usage error」、「Day whose read window is not over」、「Member route given」、「DuckDB missing」。驗證：`bundle exec rspec spec/models/end_nature_survey_command_spec.rb` 全綠。
- [x] 3.2 [after: 2.3, 3.1] 實作 Routes surveyed，套用 design「每個路線日照 derived:load 的分析跑一次，再接證據檔」與「證據按路線日存檔，分析沒變就沿用」：每一天的路線清單、成員路線跟頁面路線一起跑、兩端 `unknown`、暫存目錄成功才換名、`fingerprint`、沿用與重跑、失敗記下並繼續、每天一行進度。在 `spec/models/end_nature_survey_command_spec.rb` 先加例子，斷言規格的 Scenario「Fixture day」、「Second run reuses the route days」（第二次沒有任何一次路線日的 DuckDB 呼叫，數 `AnalysisRun.run` 帶 `end_nature_export.sql` 的呼叫）、「Changed analysis runs again」（改掉 9100 的 `fingerprint`）、「Failing route day」（`ROUTES=9001,9999`）、「Database untouched」（`RouteDay` 與其他衍生表 model 的筆數前後相同）。驗證：`bundle exec rspec spec/models/end_nature_survey_command_spec.rb` 全綠。
- [x] 3.3 [after: 2.4, 3.2] 實作 Survey report 的指令那一半，套用 design「報告與摘要的欄位與文字」與「試跑只寫檔，不寫衍生表、不改頁面與設定」：寫 `<OUT>/configured.csv`、跑報告、照 design 的文字印摘要（性質寫停車、直接折返、待查證）、結束碼。在 `spec/models/end_nature_survey_command_spec.rb` 先加例子，斷言規格的 Scenario「Fixture report」（Example 那張表的四列）、「Summary printed」（逐行比對 design 的文字）、「Nothing surveyed」，以及 `config/route_page.yml` 的內容前後相同。驗證：`bundle exec rspec spec/models/end_nature_survey_command_spec.rb` 全綠；`bin/rubocop` 對這一組改到的檔沒有 offense。

## 4. 真資料試跑與紀錄

- [x] 4.1 [after: 3.3] 套用 design「用 2026-10-19 到 10-22 試跑，八個查證過的端點全對才算通過」：`TURNAROUND_DATA` 指向本機備份（路徑不寫進 repo），用 `time` 跑 `bin/rails survey:end_natures FROM=2026-10-19 TO=2026-10-22`。看摘要裡「設定裡的端點」那 8 行：全部「判斷」等於「設定」才往下；任何一端不同就停下來，把那一端的報告列與證據回報給使用者，用 `/spectra-ingest 02-end-nature-survey` 改規則或門檻並寫明理由，不改設定。驗證：指令的結束碼是 0；摘要的 8 行與 `report-2026-10-19_2026-10-22.csv` 裡 8 列的 `agrees` 都是 `true`；在任務完成的說明裡記下實際時間與失敗的路線日數。
- [x] 4.2 [after: 4.1] 在這個 change 的 design 新增一節「調查結果」，內容照 design「用 2026-10-19 到 10-22 試跑，八個查證過的端點全對才算通過」列的六項，每個數字標明是量到的，並附上從報告 CSV 算出那些數字的 DuckDB 查詢。驗證：內容檢查，用附上的查詢對報告 CSV 重跑，得到同樣的數字；`spectra validate 02-end-nature-survey` 通過。

## 5. 文件與收尾

- [x] 5.1 [after: 2.2] 套用 design「詞彙表補「最長靜止」、「最遠離站」與「待查證」」：前置是 `01-pass-through-wording` 已經 archive；動手前重讀 `docs/spectra/LANGUAGE.md`，照 design 那一節加兩條、補一句。驗證：內容檢查，`git diff docs/spectra/LANGUAGE.md` 只有新的兩條（定義、在資料或程式碼裡、邊界、不要用四行）與「起站、末站、折返點、調度站」邊界的那一句。
- [x] 5.2 [after: 3.3] `analysis/README.md` 寫明三個新的 SQL 檔：各讀什麼、建什麼、寫什麼，只由 `bin/rails survey:end_natures` 跑，`bin/health-card` 與 `derived:load` 都不跑它們；以及 `params.sql` 的四個新常數。驗證：內容檢查，跟 design 的 Implementation Contract 一致。
- [x] 5.3 [after: 4.2, 5.1, 5.2] 收尾：`bin/ci` 全部通過（RuboCop、bundler-audit、Brakeman、平行 RSpec、seeds）；`spectra validate 02-end-nature-survey` 通過。驗證：兩個指令的輸出。
