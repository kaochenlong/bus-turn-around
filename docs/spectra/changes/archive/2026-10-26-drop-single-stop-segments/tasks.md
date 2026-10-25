<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
專案開了 tdd: true：每個行為先寫例子、跑一次確認它照預期失敗，再改程式讓它通過。
每個任務做完時 bundle exec rspec spec/analysis 要是綠的。既有的 fixture 斷言只有 1.3 那一格會改（兩端性質調查 fixture 報告的 9100 丑站），其他一個都不改。
例子照 RSpec/ExampleLength 不超過 5 行，灌入的事件放 let。
原始檔的根目錄只用環境變數 TURNAROUND_DATA 給，不寫進任何檔案；任務裡不寫車牌。
-->

## 1. 趟次的門檻

- [x] 1.1 定義常數 `min_trip_stops`，套用 design「一段至少觀測到 2 個不同的站才是一趟，門檻寫在參數檔」：`analysis/params.sql` 有 `min_trip_stops`，值是 2，註解寫一段至少觀測到這麼多個不同的站才是一趟、一個站不是行駛。先在 `spec/analysis/params_spec.rb` 的常數清單加上它、新增一例「一段至少要觀測到 2 個不同的站才是一趟」，確認它失敗，再加常數。驗證：`bundle exec rspec spec/analysis/params_spec.rb` 全綠，其中既有的「其他 SQL 檔不出現這些常數的字面數字」不改斷言仍綠。
- [x] 1.2 實作 Segments observing too few stops are not trips 與 Layover definition 新加的兩個情境，套用 design「過濾放在 trips，segmented_trips 照舊列出每一段」、「長休息照現有規則算成折返停留，不另外排除」與「測試用灌入的事件，fixture 不動」。行為：`trips` 只留起點在當天、`n_stops_observed` 不少於 `getvariable('min_trip_stops')` 的段；新 view `few_stop_segments` 列出起點在當天、觀測站數不到門檻的段，欄位同 `segmented_trips`；`segmented_trips` 不動；`analysis/20_trips.sql` 檔頭的 view 清單與 `segmented_trips` 的註解寫明它是每一段、不全是趟次。先寫下面的例子並確認失敗：
  - `spec/analysis/trips_spec.rb` 用 `replace_stop_events_sql` 灌 design 那張表的四組事件：「當天第一筆是補報」只剩 06:19 那趟、`few_stop_segments` 1 段；「隔一段時間的補報」是 07:59 與 13:14 兩趟、都完整、`few_stop_segments` 1 段；「2 站照舊是趟次」一趟 `missing_end`、2 站；「同一站先到後離」不是趟次、`few_stop_segments` 1 段。另一例斷言 Scenario「Fixture days have no such segment」：fixture 2026-10-19 與成員日 2026-10-23 的 `few_stop_segments` 都是空的。
  - `spec/analysis/layovers_spec.rb` 用同樣的事件、加 `replace_other_route_events_sql([])`，斷言 Scenario「Segment that is not a trip between two trips」：一筆 224.0 分鐘、結束在去程，沒有折返停留結束在 13:01；Scenario「Arrival reported before the first trip of the day」：沒有折返停留結束在 06:09。

  - `spec/analysis/trips_spec.rb` 的「切趟」那一組改讀 `segmented_trips`，預期的段數 1、2、2、2、1 不變，例子名稱的「切成 N 趟」改成「切成 N 段」，照 design「過濾放在 trips，segmented_trips 照舊列出每一段」：這一組每例只灌兩筆事件，四例切出來的都是只有一站的段，不改的話加了門檻會變紅。

  驗證：兩個 spec 的新例子在改 SQL 之前失敗、之後通過；「切趟」那一組改讀 `segmented_trips` 之後，改 SQL 之前與之後都綠；用 fixture 的既有例子（27 趟、跨日的三段、18 筆折返停留與四類排除計數）不改斷言仍綠；`bundle exec rspec spec/analysis` 全綠。
  [after: 1.1]
- [x] 1.3 兩端性質調查的 fixture 報告照新的趟次規則，即 Survey report 的 Example 改的那一格，套用 design「測試用灌入的事件，fixture 不動」：`bin/rails survey:end_natures` 對 fixture 2026-10-19 的報告裡，9100 丑站的折返停留是 5 筆，其他格不變。原因是 TEST-0002 在 9100 的第三筆（14:30、返程起站）自成一段、只觀測到一站，照 Segments observing too few stops are not trips 不是趟次，14:10–14:20 那趟就沒有下一趟可配。`spec/models/end_nature_survey_command_spec.rb` 的「報告四列，數字照規格的 Example 表」把 9100 丑站那一列的預期值從 6 改成 5，fixture 不動。驗證：改之前這一例在現在的程式上失敗、只差這一格（2026-10-26 看過：預期 6、實際 5）；改之後 `bundle exec rspec spec/models/end_nature_survey_command_spec.rb` 全綠；把 `min_trip_stops` 暫時改成 1 時這一例要失敗（回到 6 筆），改回 2 之後通過。 [after: 1.2]

## 2. 健檢卡的資料品質一節

- [x] 2.1 實作 Data quality section 的段數，套用 design「不算趟次的段數只在健檢卡的資料品質一節報」：`analysis/50_quality.sql` 的 `quality` 多一列 metric `few_stop_segments`、subject 空字串、value 是 `few_stop_segments` 的列數，檔頭的讀取清單補上它；`analysis/60_export.sql` 卡的 JSON 在 `quality` 底下多 `few_stop_segments`（整數）與 `min_trip_stops`（整數）。先在 `spec/analysis/quality_spec.rb` 寫兩例並確認失敗：灌「當天第一筆是補報」那組事件時，Scenario「Segments that are not trips」的 `few_stop_segments` 是 1、`completeness_counts` 是 complete 1、其他三類 0；fixture 2026-10-19 的 `few_stop_segments` 是 0。驗證：`bundle exec rspec spec/analysis/quality_spec.rb` 全綠；`bundle exec rspec spec/analysis` 全綠。 [after: 1.2]
- [x] 2.2 實作卡上的那一行，套用 design「健檢卡的文案」：`bin/health-card` 資料品質一節在完整性的表格之後、漏站率那一行之前，印 design 的說明句與「- 觀測到的站少於 {min_trip_stops} 站、不算趟次的段：{few_stop_segments} 段」，兩個數都讀 JSON。先在 `spec/analysis/card_spec.rb` 的「讀檔視窗、對不到站序的事件⋯」那一例的標籤清單加上「觀測到的站少於 2 站、不算趟次的段」、預期值「0 段」，確認失敗，即 Scenario「Fixture day reports no such segment」。驗證：`bundle exec rspec spec/analysis/card_spec.rb` 全綠；說明句是固定文案，做內容審查對照 design；`make test` 全綠；`bin/rubocop bin/health-card` 與這個 change 改到的 spec 檔沒有 offense。 [after: 2.1, 1.3]

## 3. 文件與設定註解

- [x] 3.1 詞彙表與分析說明寫出新的趟次規則，套用 design「一段至少觀測到 2 個不同的站才是一趟，門檻寫在參數檔」：`docs/spectra/LANGUAGE.md`「趟次與班次」的邊界加一句：切出來的段至少要觀測到 2 個不同的站才算一趟，只觀測到一個站的段（例如 307 的車上線時在端點站補報的一筆到站）不算，段數在健檢卡的資料品質一節；`analysis/README.md` 第 20 階段那一列的「建立」補 `few_stop_segments`、說明 `trips` 的門檻，資料品質的說明補 `few_stop_segments` 這個 metric。驗證：內容審查對照 design 的 Implementation Contract；只改這兩條，`timetable-sheet-touchups` 正在改的條目不動。
- [x] 3.2 307 兩端的查證註解寫出 change 之後的數字，套用 design「307 兩端的查證註解補一句 change 之後的數字」：用 `bin/health-card --route 16111 --also-route 19108 --day 2026-10-22`（`TURNAROUND_DATA` 指到原始檔根目錄）讀兩端的折返停留筆數與中位數，在 `config/route_page.yml` 16111 兩端的註解各補一句英文：這個 change 之後同一天是幾筆、中位數幾分鐘，去掉的是從只觀測到一站的段開始的短配對，所以結論不變；原本的查證句子不動。驗證：句子裡的數字等於那次健檢卡的數字（預期莊敬里 188 筆、16.4 分鐘，臺北客運板橋前站(藝文) 185 筆、17.8 分鐘），內容審查；`bin/rails runner 'p RoutePage.member_route_ids(16111)'` 印出 `[16111, 19108]`，證明設定照舊讀得到。 [after: 1.2]

## 4. 真資料驗證與重算

- [x] 4.1 真資料的數字等於原型，驗證 design「一段至少觀測到 2 個不同的站才是一趟，門檻寫在參數檔」在四條路線上的效果：對 15373、10712、11764 與 16111（加 `--also-route 19108`）各跑 `bin/health-card`，日子是 2026-10-19 到 10-22 與 10-25，`--inspect-dir` 放在 `tmp/` 底下。驗證：手動比對，每個路線日的趟次數、兩端折返停留的筆數、中位數、不到 15 分鐘的比例都等於 proposal 的兩張表與其他三條路線那一段；307 的資料品質一節 10-25 是 112 段、10-22 是 149 段；20 個路線日的完整趟次都跟改之前一樣；班次串除了中山幹線 10-20 從 11 串變 12 串（原因在 proposal 的 Problem 與 design 的 Risks），其他 19 個路線日都跟改之前一樣。改之前的 20 張卡是 2026-10-26 用改之前的程式跑的，放在本機 `tmp/drop-single-stop-segments/before/`，`ruby tmp/drop-single-stop-segments/summarize_cards.rb <目錄>` 每個路線日印一行，兩邊逐行比對；那個目錄不在時，用這個 change 之前的 commit 重跑。有任何一格不同，先停下來查原因、回報，不改 proposal 的數字湊答案。 [after: 2.2]
- [x] 4.2 筆電的開發資料庫用新定義重算，套用 design「正式站四條路線全部重算」裡筆電那一部分：四條頁面路線各跑一次 `bin/rails derived:load ROUTE=<路線 Id> FROM=2026-10-19 TO=2026-10-22`（`TURNAROUND_DATA` 指到原始檔根目錄）。驗證：每個路線日印出的「趟次」等於 4.1 的健檢卡；`bin/rails runner` 查 16111 的 2026-10-22，`RoutePage::Summary` 的趟次與完整趟次是 494 與 445，`Layover` 按 `go_back` 數是 188 與 185。 [after: 4.1]
- [x] 4.3 正式站四條路線的 20 個路線日用新定義重算，套用 design「正式站四條路線全部重算」：這一步由使用者在 Mac mini 上做。使用者 commit、push 這個 change 之後，在 Mac mini 的 website checkout 拉到新程式，用排程同一套環境變數先跑 `bin/nightly-load --recompute`，確認計畫要載入 20 個路線日（15373、10712、11764、16111 × 10-19 到 10-22、10-25），再跑 `bin/nightly-load --recompute --load`。驗證：輸出裡「2026-10-25 16111 寫入：」那一行是「趟次 372」開頭，結尾那一行是「載入 20 個路線日、失敗 0 個」開頭、exit 0；`curl -s 'https://bus.5xcamp.us/routes/16111?day=2026-10-25'` 的趟次卡有 `data-trips="372"` 與 `data-complete-trips="331"`，兩端的中位數是 14.5 與 27.4；把這次的秒數記在這個任務後面。2026-10-26 實測：`bin/nightly-load --recompute --load` 在 Mac mini 上 190 秒，載入 20 個路線日、失敗 0 個、exit 0；正式站那一頁 372 趟、完整趟次 331，兩端中位數 14.5 與 27.4、不到 15 分鐘 50.7% 與 28.5%。 [after: 3.1, 3.2, 4.2]
