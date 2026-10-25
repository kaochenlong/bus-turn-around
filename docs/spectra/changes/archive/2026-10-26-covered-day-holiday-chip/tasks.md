<!--
每條任務寫兩件事：做完之後哪個行為看得到、用什麼驗證。
design 的決定標題原文照抄，分析器靠字串比對。
照 .spectra.yaml 的 tdd: true，每條改程式的任務先寫例子、看它失敗，再改程式。RSpec/ExampleLength 上限 5 行。
-->

## 1. 標籤的 class

- [x] 1.1 照 design「標籤的 class 由 ApplicationComponent#day_tag_class 給，兩個頁首共用」與「標籤顏色跟著日型別：假日用 green，平日維持 slate」，`ApplicationComponent` 加凍結的 `DAY_TAG_COLORS`（鍵只有 `"weekday"` 與 `"holiday"`）與 `day_tag_class(day_type)`：回傳 `rounded-full border px-3 py-0.75` 加上那個日型別的顏色，`"holiday"` 是 `border-green-200 bg-green-50 text-green-800`，`"weekday"` 是 `border-slate-200 bg-slate-50 text-slate-700`，其他值（`nil`、`""`、`"typhoon"`）丟 `KeyError`。先在 `spec/components/application_component_spec.rb` 加例子並看它失敗：`"holiday"` 的 class 含 `bg-green-50`、不含 `bg-slate-50`；`"weekday"` 含 `bg-slate-50`、不含任何 `green-`；三個未知值都丟 `KeyError`。驗證：`bundle exec rspec spec/components/application_component_spec.rb` 改程式之前新例子失敗、改完全綠；`bin/rubocop app/components/application_component.rb spec/components/application_component_spec.rb` 沒有 offense。

## 2. 路線頁

- [x] 2.1 [after: 1.1] 照 design「日期標籤只寫日期，備註放進標籤的 title」與「分支用例子斷言，色號與提示在瀏覽器驗」，把 route-page 規格 Day coverage 改過的部分做到 `RouteCoverageComponent`：每個 `[data-covered-days] [data-day]` 的文字只有 `day_label`；`day_note` 有值時是那個元素的 `title`，沒有值時不帶 `title`；日型別標籤（用 coverage 的 `day_type`）與日期標籤（用自己那個 route day 的 `day_type`）的 class 都來自 `day_tag_class`。「涵蓋的日子」那幾個字、另一種日型別的連結、`data-day-type`、`data-covered-days`、`data-day` 都不變。先改測試並看它失敗：`spec/components/route_coverage_component_spec.rb` 的「10-26 跟著它的備註」改成文字是「2026-10-26（一）」、`title` 是「補假」，標題跟著改；加例子對應規格的 Scenario「Tag colour follows the day type」：選 10-26 最近 7 天時，日型別標籤（`[data-day-type]` 裡文字是 `I18n.t("day_types.holiday")` 的那個 `span`）與每個日期標籤的 class 都含 `bg-green-50`；選 10-23 最近 7 天時，日型別標籤（文字是 `I18n.t("day_types.weekday")` 的那個 `span`）與每個日期標籤都不含 `green-`，而且沒有備註的日期標籤沒有 `title`；`spec/requests/routes_spec.rb` 的「選 10-26、最近 7 天：…」與「沒帶參數時是最新的 10-26：…」把期待的標籤文字改成「2026-10-26（一）」，並斷言 10-26 的 `title` 是「補假」、10-24 與 10-25 沒有 `title`（規格的 Example「the Retrocession Day weekend」與 Scenario「One day states its type」），標題裡的「帶著補假」照新的意思改寫。驗證：`bundle exec rspec spec/components/route_coverage_component_spec.rb spec/requests/routes_spec.rb` 改程式之前這些例子失敗、改完全綠；`bin/rubocop spec/components/route_coverage_component_spec.rb spec/requests/routes_spec.rb` 沒有 offense。

## 3. 班表頁

- [x] 3.1 [after: 1.1] 照 design「日期標籤只寫日期，備註放進標籤的 title」與「標籤顏色跟著日型別：假日用 green，平日維持 slate」，`TimetableHeaderComponent` 的「涵蓋的日子」那一列做到跟路線頁一樣（班表規格寫的是涵蓋的日子與日型別「as the route page states them」）：日期標籤的文字只有 `day_label`、備註是 `title`，日型別標籤與日期標籤的 class 來自 `day_tag_class`；列印時頁首照舊整塊不印。先在 `spec/components/timetable_header_component_spec.rb` 加例子並看它失敗：在一個 describe 裡把既有的 `route_day` 改成 `day_type: "holiday"`、`day_note: "補假"`，日期標籤的文字是「2026-10-19（一）」、`title` 是「補假」，日型別標籤與日期標籤的 class 都含 `bg-green-50`；既有的「路線名、起訖、涵蓋的日子與日型別」照舊通過。驗證：`bundle exec rspec spec/components/timetable_header_component_spec.rb` 改程式之前新例子失敗、改完全綠；`bin/rubocop spec/components/timetable_header_component_spec.rb` 沒有 offense。

## 4. 驗收

- [x] 4.1 [after: 2.1, 3.1] 照 design Implementation Contract 的「驗收」看畫面，色號是否合適由使用者決定（design「標籤顏色跟著日型別：假日用 green，平日維持 slate」）。開發資料庫沒有假日的路線日時，先用筆電的鏡射資料載入 2026-10-25 的中山幹線，只寫開發資料庫：`TURNAROUND_DATA=~/toy/TurnAround/backup/mini-data bin/rails derived:load ROUTE=15373 DAY=2026-10-25`。在 `bin/dev` 開 `/routes/15373?day=2026-10-25`、`/routes/15373?day=2026-10-22&range=7d` 與 `/routes/15373/timetable?day=2026-10-25`，1280 寬與 390 寬（390 用 CDP 模擬）各截一張。驗證（手動，結果記在這條任務下面）：兩個假日頁面的日型別標籤與日期標籤，計算後的字色與底色用 canvas 換成 rgb，對比不低於 4.5:1（換算 6.78:1；量到低於 4.5:1 就停下來回報）；平日那頁的標籤計算顏色跟改之前一樣（slate-700 字、slate-50 底）；2026-10-25 的日期標籤文字是「2026-10-25（日）」、DOM 上的 `title` 是「臺灣光復暨金門古寧頭大捷紀念日」。截圖的完整路徑交給使用者，使用者看過、說綠色看得出是假日、跟「看平日」連結分得開，才標完成；使用者要換色號，就回 design 改那一條，不自己換。
  - 結果（2026-10-26）：開發資料庫先照上面的指令載入 15373 的 2026-10-25（趟次 118、折返停留 81，跟 mini 寫進正式站的一樣）。3000 埠是別的專案的 server，所以這個專案另開 Rails 3100、Vite 5173（加 `--cors`，讓 3100 載得到 module script），量完就關。headless Chrome，1280 與 390 都用 CDP `Emulation.setDeviceMetricsOverride`，390 帶 `mobile: true`：
    - 兩個假日頁面（路線頁與班表頁的 `?day=2026-10-25`）、兩種寬度：日型別標籤「假日」與日期標籤「2026-10-25（日）」的字是 rgb(1, 102, 48)、底 rgb(240, 253, 244)、框 rgb(185, 248, 207)，對比 6.81:1。
    - 2026-10-25 的日期標籤文字是「2026-10-25（日）」，`title` 是「臺灣光復暨金門古寧頭大捷紀念日」；日型別標籤沒有 `title`。
    - 平日那頁（`?day=2026-10-22&range=7d`）：「平日」與 10-19 到 10-22 四個日期標籤的字是 rgb(49, 65, 88)、底 rgb(248, 250, 252)、框 rgb(226, 232, 240)，就是 slate-700、slate-50、slate-200，跟改之前同一組；都沒有 `title`。
    - 「看平日」連結 rgb(0, 120, 111)（teal-700）；390 寬的 `scrollWidth` 是 390；Vite 輸出的 CSS 含 `.bg-green-50`、`.border-green-200`、`.text-green-800`。
    - 截圖 6 張（路線頁假日、路線頁平日最近 7 天、班表頁假日，各 1280 與 390）已交給使用者，等使用者判斷綠色看不看得出是假日、跟「看平日」連結分不分得開。
- [x] 4.2 [after: 2.1, 3.1] 整套測試與 change 的檢查：`bin/rails parallel:spec` 全綠；`spectra validate covered-day-holiday-chip` 通過；1.1 到 3.1 改到的 `.rb` 檔過 `bin/rubocop`（這個專案的 RuboCop 不檢查 `.erb`，兩個模板不交給它）。驗證：三個指令的輸出。
  - 結果（2026-10-26）：`bin/rails parallel:spec` 1453 個例子 0 失敗（105 秒）；`bin/rubocop` 對 `app/components/application_component.rb` 與四個 spec 檔，5 個檔沒有 offense；`spectra validate covered-day-holiday-chip` 通過。
