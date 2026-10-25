## Summary

這個 change 服務第一樣交付物「路線健檢卡」在網站上的呈現：路線頁 `/routes/:route_id` 與班表頁 `/routes/:route_id/timetable` 頁首「涵蓋的日子」那一列。不新增資料，讀的仍是衍生表 `route_days` 的 `day_type` 與 `day_note`（人事行政總處辦公日曆的「是否放假」與「備註」，由 `bin/rails external:office_calendar` 下載），不牽涉指標定義。日期標籤只寫日期，日曆的備註改成滑鼠停在標籤上才出現的提示（`title`）；看假日時，「假日」標籤與每個日期標籤改用綠色。

## Motivation

2026-10-26 02:36，Mac mini 的每晚載入第一次自動把 2026-10-25 寫進正式站，路線頁預設顯示這一天，日期標籤變成「2026-10-25（日）臺灣光復暨金門古寧頭大捷紀念日」，比同一列其他東西都長。使用者看了畫面，問標籤一定要這麼長嗎：如果只是要表示假日，可以用顏色，備註放提示就好。

- 現在的排法來自 `01-route-page-visual-refresh` 的決定「分段按鈕與小標籤」裡的「備註接在那一天的標籤裡」，當時的例子是兩個字的「補假」。
- 2026 年的辦公日曆有備註的 22 天全是放假日，大多 2 到 5 個字；長的只有 10-25（15 字）與 9-28「孔子誕辰紀念日/教師節」（11 字）。這是 2026-10-26 讀筆電上的 2026 年日曆快照（`2026-10-23.csv`）數的。
- 同一列已經有「假日」標籤寫出日型別；備註補充的是這天為什麼放假。

## Proposed Solution

- 日期標籤只寫日期與星期，例如「2026-10-25（日）」。有備註的日子，備註放進那個標籤的 `title`，滑鼠停上去才看得到。手機沒有滑鼠停留，看不到備註，使用者 2026-10-26 同意接受。
- 顏色跟著日型別走：看假日時，「假日」標籤與每個日期標籤一起用 Tailwind 的 green（淺綠底、綠框、深綠字）；看平日時維持現在的 slate。整列一起換色，「假日」那顆標籤就是綠色的圖例，手機上也看得懂。確切色號做出來看截圖由使用者決定。
- 路線頁（`RouteCoverageComponent`）與班表頁（`TimetableHeaderComponent`）一起改：兩個模板是同一份寫法，班表頁的規格寫的是涵蓋的日子與日型別「as the route page states them」。
- 改寫路線頁規格的 Day coverage：日期標籤只寫日期，備註是標籤的提示，標籤顏色跟著日型別。

## Non-Goals

- 不做手機點了才跳出來的提示：網站目前沒有任何 tooltip 或 popover，使用者接受手機看不到備註。
- 首頁路線卡的「最新資料 …（日）假日」不改色、不加備註。
- 不縮短備註、不維護節日簡稱對照表；日型別的分法、`day_note` 的內容與存法都不動。
- 不換掉 slate 與 teal-700，只加一個假日用的綠色。`01-route-page-visual-refresh` 的非目標「換色票：維持 slate 與 teal-700，amber 只給提醒框」限的是那個 change 的範圍，理由是換色票就要重出首頁插圖；這次不換、只加，首頁插圖的行道樹已經用 green-600（`home-hero-turnaround-loop` 的「路邊種三棵行道樹與兩個花台，調色盤多一個綠色」）。
- 列印不變：班表頁列印時頁首整塊不印，單子上「資料依據」那一行本來就只寫日期與日型別。

## Alternatives Considered

- 備註截短加省略號：「2026-10-25（日）臺灣光復暨…」仍然長，也看不出截掉了什麼。
- 備註移到標籤列下面另起一行：手機看得到，但多一行字，使用者要的是短。
- 只把有備註的日子染綠：手機看不到提示，會出現一顆綠色的日期卻不知道為什麼綠。
- emerald 或 teal 這類偏藍的綠：全站連結是 teal-700，同一列就有「看平日」連結，綠色標籤會像連結。
- 紅色（台灣日曆的「紅字」）：跟路線頁標樣本少的 orange-700 同一個暖色系，容易讀成這天的資料有問題。

## Impact

- Affected specs: route-page
- Affected code:
  - Modified: app/components/application_component.rb, app/components/route_coverage_component.html.erb, app/components/timetable_header_component.html.erb, spec/components/application_component_spec.rb, spec/components/route_coverage_component_spec.rb, spec/components/timetable_header_component_spec.rb, spec/requests/routes_spec.rb
  - New: (none)
  - Removed: (none)
