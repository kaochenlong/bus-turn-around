<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
-->

## 1. 辦公日曆快照

- [x] 1.1 套用 design「下載器從出入口快照抽出來共用」：`MrtExitsSnapshot::HTTP_FETCHER` 搬成 `HttpFetcher` 模組（`call(url)` 回傳 `[狀態碼, 內容位元組]`，最多跟三次轉址），`MrtExitsSnapshot` 改用它當預設的 fetcher，行為不變。驗證：`spec/models/mrt_exits_snapshot_spec.rb` 不改，仍全綠；`bin/rubocop` 對改過的檔沒有 offense。
- [x] 1.2 實作 Office calendar snapshot 的下載，套用 design「每年的下載網址寫成程式裡的常數」「下載時檢查整年的日期、星期與代碼，存成 UTF-8、不帶 BOM、LF 換行」，以及「辦公日曆快照按年份存在資料根目錄，算的時候用那一年最新的一份並記下日期」的存檔部分。內容：
  - `OfficeCalendarSnapshot` 依 `DOWNLOAD_URLS`（2026 與 2027 兩年，照 data.gov.tw/dataset/14718 上的連結原樣抄錄）下載，檢查後寫入 `external/office-calendar/<年>/<台北日>.csv`。
  - rake task `external:office_calendar` 讀 `TURNAROUND_DATA` 與 `YEAR`。
  - 先新增 fixture `spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv`：把真的 115 年日曆去掉 BOM、換成 LF（365 列，假日 120 天）；`spec/fixtures/analysis/README.md` 寫出它的來源、格式與顯名。

  驗證：`spec/models/office_calendar_snapshot_spec.rb` 用假 fetcher 斷言下列 Scenario，測試不連網路：
  - 「Calendar written without the byte order mark and CRLF」，照 Example「the 2026 calendar」：寫出的檔跟 fixture 位元組相同，印出 365 天與 120 天。
  - 「Unusable calendar」表格裡的八種情況：每一種都結束碼非零、不寫檔、同一年既有的快照不變。
  - 「Year without a URL」：fetcher 沒被呼叫，訊息列出 2026 與 2027。
  - 「Usage without a data root」。

  另外 `spec/analysis/fixtures_spec.rb` 照捷運出入口 fixture 的寫法加一條：日曆 fixture 的表頭是 `西元日期,星期,是否放假,備註`、365 列、假日 120 天。
  [after: 1.1]
- [x] 1.3 實作 Day type of a Taipei day 的查詢，套用 design「日型別照辦公日曆的「是否放假」分兩類：0 是平日、2 是假日」，以及「辦公日曆快照按年份存在資料根目錄，算的時候用那一年最新的一份並記下日期」的讀取部分。內容：`OfficeCalendarSnapshot.entry(data_root:, day:)` 從那一年資料夾裡檔名日期最新的快照查那一天，回傳 `Entry`（`day_type` 是 `weekday` 或 `holiday`，`note` 是備註或 nil，`snapshot_day`）；沒有快照、或快照裡沒有那一天時，丟出帶著 design 所寫訊息的錯誤。驗證：`spec/models/office_calendar_snapshot_spec.rb` 斷言下列 Scenario：
  - 「Days around a substitute holiday」，用 fixture 讀 Example「the Retrocession Day weekend」的四天。
  - 「Newest snapshot of the year used」，暫存目錄放兩份。
  - 「No snapshot for the year」，訊息含 `bin/rails external:office_calendar YEAR=2027`。
  - 「Snapshot without the day」。
  [after: 1.2]

## 2. 路線日帶著日型別

- [x] 2.1 實作 Route day carries its day type 與 Day eligibility 的修改，套用 design「日型別在 derived:load 時由 Ruby 寫進 route_days，不經過 DuckDB」，以及「日型別必填：先加可以為空的欄位，重載之後再改成必填」的第一步。內容：
  - migration 在 `route_days` 加 `day_type`、`day_note`、`office_calendar_day`，三欄都可以為空，註解寫明下一個 migration 會改成必填。
  - `RouteDayLoader` 找完捷運出入口快照之後、跑 DuckDB 之前查日曆，跟路線日在同一個交易裡寫入這三個值；查不到時丟出 `RouteDayLoader::Error`。

  驗證：
  - `spec/models/route_day_loader_spec.rb` 斷言 Scenario「Fixture day is a weekday」與「Holiday from the calendar」（暫存資料根目錄放一份日曆，10-19 那列改成 `20261019,一,2,補假`）。
  - 同一個 spec 斷言 day-types 的 Scenario「Trip across midnight takes the departure day's type」：TEST-0002 23:40 發車那一趟，存在日型別是假日的 10-19 路線日底下。
  - `spec/models/derived_load_command_spec.rb` 斷言 Scenario「No calendar snapshot」：有出入口快照、沒有日曆，結束碼非零，訊息含 `bin/rails external:office_calendar YEAR=2026`，沒有寫入。
  - 既有的「No entrance snapshot」example 不改，仍然通過。
  - `spec/models/route_page/card_consistency_spec.rb` 與 `spec/requests/route_page_fixture_spec.rb` 仍全綠。
  - 跑完 migration 後執行 `bin/rails parallel:setup`，`make test` 全綠。
  [after: 1.3]

## 3. 測試改用 route_day factory

- [x] 3.1 套用 design「測試改用 route_day factory 建路線日」，第一批：新增 `spec/factories/route_days.rb`，預設值照 design；`spec/components/` 底下 10 個 spec 檔（buffer_trade、layover_chart、layover_table、load_chart、load_profile_table、mrt_overlap、route_coverage、route_list、route_summary、run_time_table）裡建路線日的 `RouteDay.create!` 改成 `create(:route_day, ...)`，只傳各自不同的欄位，斷言不改。驗證：`bundle exec rspec spec/components` 全綠；`bin/rubocop` 對改過的檔沒有 offense。 [after: 2.1]
- [x] 3.2 第二批：`spec/models/home_page/route_list_spec.rb`、`spec/models/route_page/` 底下的 buffer_trade、layover_distribution、layover_stats、load_profile、mrt_overlap、run_times 六個 spec，以及 `spec/models/route_day_spec.rb` 的 `described_class.create!`，都改用 factory，斷言不改。驗證：`bundle exec rspec spec/models` 全綠；`bin/rubocop` 對改過的檔沒有 offense。 [after: 3.1]
- [x] 3.3 第三批：`spec/requests/pages_spec.rb`、`spec/requests/routes_spec.rb`、`spec/system/home_hero_spec.rb` 改用 factory，斷言不改。驗證：`bundle exec rspec spec/requests spec/system` 全綠；`grep -rn "RouteDay.create!" spec` 沒有任何結果；`bin/rubocop` 對改過的檔沒有 offense。 [after: 3.1]

## 4. 日型別改成必填

- [x] 4.1 實作 design「日型別必填：先加可以為空的欄位，重載之後再改成必填」的第二步：第二個 migration 先檢查有沒有缺 `day_type` 或 `office_calendar_day` 的路線日。有的話就丟出錯誤，列出路線 Id、日期，以及要先跑的 `bin/rails external:office_calendar` 與 `bin/rails derived:load`，不改 schema；沒有才把這兩欄改成 NOT NULL。down 把兩欄改回可以為空。驗證：開發資料庫裡 2.1 之前寫入的 15373 那幾天還沒帶類型時，執行 `bin/rails db:migrate` 會停下來，訊息列出那幾天（人工確認），`db/schema.rb` 不變。如果開發資料庫已經全部重載過、看不到這一步，就用 `bin/rails dbconsole` 把其中一天的 `day_type` 設成 NULL 再試，試完重載那一天。 [after: 3.2, 3.3]
- [x] 4.2 重載已寫入的日子，然後完成必填的 migration：`TURNAROUND_DATA` 指到資料根目錄（不寫進任何檔案）。步驟：
  1. `bin/rails external:office_calendar YEAR=2026`，應印出 365 天、假日 120 天。
  2. `bin/rails derived:load ROUTE=15373 FROM=2026-10-19 TO=<讀檔視窗已經結束的最新一天>`。
  3. `bin/rails db:migrate`，這次應該通過。

  驗證：
  - rake 的輸出。
  - spec 斷言 Scenario「Day type required」：`create(:route_day, day_type: nil)` 丟出 `ActiveRecord::NotNullViolation`。
  - `bin/rails parallel:setup` 之後，`make test` 全綠。
  [after: 4.1]

## 5. 路線頁

- [x] 5.1 實作 Day coverage 的範圍部分，套用 design「路線頁的網址、日期與範圍：最近 7 天只留跟選的那一天同類型的日子」與「跳到另一類的連結找選的那一天以前最近的另一類日子」：`RoutePage::Coverage#route_days` 在 7d 時只回同類型的日子；`#day_type` 與 `#other_type_day` 照 design 的介面；已寫入的日子與它們的類型用同一次查詢取得。驗證：新增 `spec/models/route_page/coverage_spec.rb`，用 factory 建 10-19 到 10-23 的平日、10-24 到 10-26 的假日，斷言：
  - `day: "2026-10-26", range: "7d"` 涵蓋 10-24 到 10-26，`other_type_day` 是 10-23。
  - `day: "2026-10-23", range: "7d"` 涵蓋 10-19 到 10-23，`other_type_day` 是 nil。
  - `range` 是 `day` 時只涵蓋選的那一天。
  - 選的那一天沒有資料時，`day_type` 是 nil。
  [after: 4.2]
- [x] 5.2 實作 Day coverage 的顯示部分與 Data limitations on the page 的修改，套用 design「平日與假日的顯示名稱放共用的 locale」與「颱風停班日照日曆算，寫進資料限制」。內容：
  - `config/locales/tw.yml` 與 `en.yml` 加 `day_types`，`ApplicationComponent#day_type_label` 提供顯示名稱。
  - `RouteCoverageComponent` 顯示「涵蓋的日子（平日）」或「（假日）」、每一天的備註，以及另一類的連結（`data-other-day-type`）。
  - 拿掉 `no_day_type` 與它的文案。
  - 資料限制元件 `items` 裡那一條，換成日曆與颱風停班的說明。

  驗證：
  - `spec/components/route_coverage_component_spec.rb` 裡兩個斷言 `data-no-day-type` 的 example，改成斷言：同類型的標示、10-26 的備註、另一類連結的網址，以及沒有另一類時不放連結。
  - `spec/requests/routes_spec.rb` 斷言 Scenario「Seven days keep the selected day's type」（照 Example「the Retrocession Day weekend」）、「No day of the other type before the selected day」、「One day states its type」、改寫後的「Seven days with gaps」，以及「No statement that days are mixed」：兩種範圍的頁面都沒有「沒有分平日與假日」這句。
  - 資料限制與標示的固定文案，用內容審查對照 design 確認。
  [after: 5.1]

變更記錄（2026-10-23）：5.2 驗證列的「No statement that days are mixed」沒有寫成 `spec/requests/routes_spec.rb` 的斷言。被拿掉的那句話是固定文案，產生它的分支（`no_day_type`）已經整個刪除，再斷言它不存在只會在有人把那句話加回來時失敗，照專案的測試範圍規則不寫測試。改用內容審查：`app/`、`spec/`、`config/` 裡都找不到「沒有分平日與假日」、`no_day_type` 與 `data-no-day-type`。

## 6. 首頁與顯名聲明

- [x] 6.1 實作 Route list 的修改：首頁卡上的最新資料日後面接日型別（`day_type_label`），例如「最新資料 2026-10-20（二）平日」。驗證：`spec/components/route_list_component_spec.rb` 斷言 Example「entry of a route with data」的 2026-10-20（二）平日，以及 Scenario「Latest day is a holiday」的 2026-10-26（一）假日；`spec/models/home_page/route_list_spec.rb` 那個「只發一次 SELECT」的 example 仍通過；`spec/requests/pages_spec.rb` 的卡片 example 用 `include` 比對「2026-10-20（二）」，後面多了「平日」也不用改，仍通過。 [after: 5.2]
- [x] 6.2 實作 Attribution footer on every page 的修改，套用 design「顯名聲明加一行辦公日曆」：footer 在北捷那一行之後多一行「行政院人事行政總處 中華民國政府行政機關辦公日曆表（data.gov.tw/dataset/14718），依政府資料開放授權條款第 1 版釋出」，en 用同一段原文。驗證：`spec/requests/site_layout_spec.rb` 斷言 Scenario「Office calendar line in the footer」：footer 裡恰好有一行同時含行政院人事行政總處、中華民國政府行政機關辦公日曆表與 data.gov.tw/dataset/14718；既有兩個 example 仍通過；那一行的文字用內容審查對照 design。

變更記錄（2026-10-23）：6.2 驗證列的「Office calendar line in the footer」沒有寫成 `spec/requests/site_layout_spec.rb` 的斷言，那支 spec 沒有修改。footer 那一行是固定文案，沒有分支選它，也沒有輸入填它；它也不必跟另一個檔案逐字一致（`docs/data-sources.md` 只逐字記了公車資料那三行），照專案的測試範圍規則不寫測試。改用內容審查：渲染出來的 footer 在北捷那一行之後就是 design 的那段文字，一字不差；既有兩個 footer 的 example 仍通過。

## 7. 文件與真資料驗收

- [x] 7.1 更新文件：
  - `docs/spectra/LANGUAGE.md` 改寫「日型別」一條：
    - 在資料或程式碼裡：`route_days.day_type` 的 weekday 與 holiday、`day_note`、`office_calendar_day`、快照路徑與 `bin/rails external:office_calendar`。
    - `GetTimeTable.gz` 的 `DateType` 全是 0；`GetSemiTimeTable.gz` 的 `DateValue` 看起來是星期幾（1 是日、7 是六，只在中山幹線上看過）。
    - 邊界：補假算假日（2026-10-26），補班算平日（2026 與 2027 都沒有補班日），颱風停班照日曆算，跨午夜的趟次帶發車那一天的類型。
    - 拿掉「還沒抓」。
  - `docs/data-sources.md` 辦公日曆那一列改成已抓，寫明下載方式、存放位置、原檔是 UTF-8 帶 BOM，以及日曆可能在年中改版。

  驗證：內容審查，對照 design 與 `day-types` spec。
  [after: 5.2, 6.1, 6.2]
- [x] 7.2 用真資料驗收交件前做得到的部分。步驟：
  1. 用開發資料庫裡的平日真資料（15373 的 10-19 到 10-22），請求 `/routes/15373`、`/routes/15373?day=2026-10-22&range=7d` 與 `/`，人工確認 Implementation Contract 跟平日有關的行為：涵蓋的日子標成平日、7 天範圍是 10-19 到 10-22、資料庫裡還沒有假日所以沒有另一類的連結、首頁卡寫「最新資料 2026-10-22（四）平日」、footer 有辦公日曆那一行。
  2. 對這個 change 新增與修改的 Ruby 檔跑 `bin/rubocop`，並跑 `bin/brakeman`。

  驗證：三頁的人工審查；`bin/rubocop` 沒有 offense、`bin/brakeman` 沒有警告。
  [after: 7.1]

變更記錄（2026-10-23）：原本 7.2 的另一半移出這個 change，因為活動 2026-10-24 交件，早於 10-26 的資料。移出去的是：2026-10-27 02:00 之後載入 15373 的 10-22 到 10-26、用 design「用 10-26 的發車數驗證補假日跑的是假日班距」附的 SQL 數一整天的趟數並照判準判定、在真資料上看 10-24 到 10-26 的頁面。這幾步沒有做，改由 7.3 記在詞彙表「日型別」邊界的待確認，交件後照著做。

- [x] 7.3 在 `docs/spectra/LANGUAGE.md`「日型別」的邊界加一條待確認：補假日公車是不是跑假日班距，還沒有用真資料驗過，因為交件期限早於 10-26 的資料。內容寫明：
  - 方法：2026-10-27 02:00 之後載入 15373 的 10-22 到 10-26，數 10-19 到 10-26 每一天、每個方向一整天的趟數；查詢在 day-types 的 design「用 10-26 的發車數驗證補假日跑的是假日班距」（`spectra decisions "10-26"` 找得到）。
  - 判準：兩個方向的 10-26 都離 10-24、10-25 的平均，比離 10-19 到 10-23 的平均近。
  - 結果：成立就寫下六個數字並拿掉這條待確認；不成立就另開 change 修正分法，在那之前 10-26 在頁面上被標成假日。

  驗證：內容審查，對照 design 那一條。
  [after: 7.1]
