## Context

- 路線頁頁首由 `RouteCoverageComponent` 畫，班表頁頁首由 `TimetableHeaderComponent` 畫，「涵蓋的日子」那一列兩邊是同一份寫法（班表頁模板的註解寫「寫法同路線頁」）：灰字的「涵蓋的日子」、一顆日型別標籤（`day_type_label`）、每個涵蓋的日子一顆 `li[data-day]` 標籤，內容是 `day_label` 直接接上 `day_note`。兩種標籤都是 `rounded-full border border-slate-200 bg-slate-50 px-3 py-0.75 text-slate-700`。路線頁那一列最後還有另一種日型別的連結，`text-teal-700` 加底線；班表頁沒有這個連結。
- `RoutePage::Coverage#route_days` 只涵蓋跟選的那一天同一類的日子，所以同一列的日期標籤日型別都一樣，也跟日型別標籤一樣。
- `day_note` 是辦公日曆的「備註」，由 `RouteDayLoader` 寫進 `route_days`（`day-types` 的決定「日型別照辦公日曆的「是否放假」分兩類：0 是平日、2 是假日」）。2026 年有備註的 22 天全部是「是否放假」2，長度見 proposal 的 Motivation。
- 網站用到的顏色（2026-10-26 grep `app/` 的 `text-`、`bg-`、`border-` class 數的）：teal 39 處，連結（teal-700，hover 換 teal-900）、focus 外框、eyebrow，以及行駛時間的橫條與圖上的標記；amber 18 處，全部是提醒框（`rounded border border-amber-300 bg-amber-50 p-4`）；sky 6 處，沿線人數圖的捷運重疊段；orange 4 處，樣本少的筆數與表格上方說明裡「橘色」那兩個字。green、emerald、red、rose 都沒有。首頁插圖的行道樹用 green-600 `#16a34a`（`app/frontend/hero/scene.js`）。
- Tailwind 4.3.3 的顏色換算成 sRGB（換算值，算法是 OKLCH 轉 OKLab 再轉線性 sRGB，WCAG 相對亮度）：

| 顏色 | sRGB | OKLCH 色相 | 對比 |
| --- | --- | --- | --- |
| green-800 字配 green-50 底 | `#016630` 配 `#f0fdf4` | 151.3 | 6.78:1 |
| green-700 字配 green-50 底 | `#008236` 配 `#f0fdf4` | 150.1 | 4.72:1 |
| slate-700 字配 slate-50 底（現在的標籤） | `#314158` 配 `#f8fafc` | 257.3 | 9.88:1 |
| teal-700（連結） | `#00786f` | 186.4 | — |
| emerald-700 | `#007a55` | 165.6 | — |

- 測試現況：`spec/components/route_coverage_component_spec.rb` 的「10-26 跟著它的備註」、`spec/requests/routes_spec.rb` 的「選 10-26、最近 7 天：…」與「沒帶參數時是最新的 10-26：…」斷言標籤文字是「2026-10-26（一）補假」；`spec/components/timetable_header_component_spec.rb` 只斷言 `data-day-type` 與每個 `data-day`。
- 列印：班表頁的 `@media print` 把頁首整塊藏起來；單子上的「資料依據」由 `TimetableSheetComponent#covered_days_text` 用 `day_label` 與 `day_type_label` 組，不讀 `day_note`。
- Tailwind 掃 class 的範圍：`app/frontend/stylesheets/application.css` 有 `@source "../../components"`，`app/components` 底下 `.rb` 裡寫的 class 也會編進 CSS（`nature_tag`、`eyebrow` 就寫在 `ApplicationComponent`）。

## Goals / Non-Goals

**Goals:**

- 日期標籤只寫日期與星期；有備註的日子，備註是那顆標籤的 `title`。
- 看假日時，日型別標籤與每個日期標籤用綠色；看平日時維持 slate。
- 路線頁與班表頁這一列的標籤樣式由同一個方法給，顏色規則只寫在一個地方。

**Non-Goals:**

- 手機點了才跳出來的提示；首頁路線卡；縮短備註或節日簡稱對照表；換掉 slate 與 teal-700；列印。理由見 proposal 的 Non-Goals。
- 不把整列抽成新的元件：見「標籤的 class 由 ApplicationComponent#day_tag_class 給，兩個頁首共用」。
- 不加只給螢幕報讀的備註文字：見 Risks。

## Decisions

### 日期標籤只寫日期，備註放進標籤的 title

**Supersedes**: 01-route-page-visual-refresh / 分段按鈕與小標籤

改掉的部分是原本那條的「備註接在那一天的標籤裡」。日期標籤的文字只有 `day_label`，例如「2026-10-25（日）」；`day_note` 有值時放進那個 `li[data-day]` 的 `title`，沒有值時不帶 `title`。滑鼠停在標籤上，瀏覽器顯示備註。手機沒有滑鼠停留，看不到備註，使用者 2026-10-26 同意接受：日型別標籤已經寫出平日或假日，路線頁的資料限制也寫了「平日跟假日是照人事行政總處的辦公日曆分的」。

照舊的部分（原本那條決定的其他內容）：

- 範圍切換：`nav[data-range]` 照舊，兩個連結做成分段按鈕，選中的那個加 `aria-current="true"`。手機上兩個按鈕平分寬度、高度至少 44px。
- 時段切換：Alpine 的 `x-on:click`、`x-bind:aria-pressed`、`x-cloak` 照舊，只換 `x-bind:class` 裡的兩組 class。手機上四個按鈕平分寬度、高度至少 44px。
- 涵蓋的日子：`[data-covered-days] [data-day]` 照舊，每一天是一個圓角小標籤。
- 日型別放在涵蓋的日子前面，用同一個小標籤樣式；`app/components/route_coverage_component.yml` 的 `covered` 只寫「涵蓋的日子」（en: Days covered），後面沒有冒號，日型別由 `day_type_label` 另外輸出；另一種日型別的連結放在標籤列的最後，teal-700 文字連結、有底線。

理由：備註大多兩三個字，但 10-25 的 15 個字讓那顆標籤比同一列其他東西都長；備註補充的是這天為什麼放假，日型別已經由日型別標籤講了。

替代方案：

- 備註截短加省略號（否決：「2026-10-25（日）臺灣光復暨…」仍然長，也看不出截掉什麼）。
- 備註另起一行寫在標籤列下面（否決：多一行字，使用者要的是短）。
- 手機點了才跳出來的提示（否決：網站目前沒有任何 tooltip 或 popover，使用者接受手機看不到備註）。

### 標籤顏色跟著日型別：假日用 green，平日維持 slate

日型別標籤照 `RoutePage::Coverage#day_type`，每顆日期標籤照自己那個 route day 的 `day_type`（同一列兩者一樣）：

- `holiday`：`border-green-200 bg-green-50 text-green-800`。
- `weekday`：`border-slate-200 bg-slate-50 text-slate-700`，跟現在一樣。

圓角、內距（`rounded-full border px-3 py-0.75`）兩種都一樣。整列一起換色，日型別標籤寫著「假日」，就是綠色的圖例，手機上不用提示也看得懂。字用 green-800：換算 6.78:1；green-700 只有 4.72:1，離 4.5:1 太近。確切色號做出來看截圖由使用者決定，換色號只改這兩組 class。

`01-route-page-visual-refresh` 的非目標「換色票：維持 slate 與 teal-700，amber 只給提醒框。…」限的是那個 change 的範圍，理由是首頁插圖的色票綁在路線頁那套、換色票要重出插圖。這次 slate 與 teal-700 都不換，只加一個假日用的綠色；後來的 change 已經加過 orange（樣本少）與 sky（捷運重疊段），首頁插圖也已經有 green-600 的行道樹（`home-hero-turnaround-loop` 的「路邊種三棵行道樹與兩個花台，調色盤多一個綠色」，當時否決 teal 的理由也是讀起來不像植物、使用者選了綠色）。

替代方案：

- emerald 或 teal 這類偏藍的綠（否決：emerald-700 的色相 165.6 離連結的 teal-700（186.4）只差 21，green-800 差 35；同一列就有「看平日」連結，太近會讓標籤像連結）。
- 只把有備註的日子染綠（否決：手機看不到提示，會出現一顆綠色的日期卻不知道為什麼綠）。
- 只有日型別標籤變綠、日期標籤維持灰色（否決：使用者要的是日期本身看得出是假日）。
- 紅色，台灣日曆的「紅字」（否決：跟樣本少的 orange-700 同一個暖色系，容易讀成這天的資料有問題）。

### 標籤的 class 由 ApplicationComponent#day_tag_class 給，兩個頁首共用

`ApplicationComponent` 加 `day_tag_class(day_type)`，回傳整串 class：共用的 `rounded-full border px-3 py-0.75` 加上 `DAY_TAG_COLORS.fetch(day_type)` 的顏色。`DAY_TAG_COLORS` 是凍結的 Hash，只有 `"weekday"` 與 `"holiday"` 兩個鍵；其他值（`nil`、空字串、`"typhoon"`）讓 `fetch` 丟 `KeyError`，跟 `day_type_label` 遇到沒有的日型別就丟錯一致，不默默畫成灰色。兩個模板的日型別標籤與日期標籤都改用它；日期標籤改用 `tag.li`，帶 `data: { day: … }`、`title: covered_day.day_note.presence` 與這個 class。

替代方案：

- 兩個模板各寫一次條件（否決：同一條顏色規則在兩個檔案寫四次，兩個頁首本來就是複製的寫法）。
- 整列抽成新的 `CoveredDaysComponent`（否決：路線頁那一列最後有另一種日型別的連結、班表頁沒有，要為一個連結開 slot；兩邊真正共用的只有標籤樣式）。
- 照 `nature_tag` 寫一個畫出整顆標籤的方法（否決：日型別標籤是 `span`、日期標籤是帶 `data-day` 與 `title` 的 `li`，方法得把標籤名與屬性原樣傳下去，沒有藏住什麼）。

### 分支用例子斷言，色號與提示在瀏覽器驗

照 `.spectra.yaml` 的 `tdd: true`，先寫會失敗的例子再改程式。斷言的是會分岔的地方：`day_tag_class` 依日型別給哪一組顏色（以 `bg-green-50` 與 `bg-slate-50` 區分）、未知的日型別丟錯；兩個頁首在假日時日型別標籤與日期標籤都是綠的、在平日時都不是；有備註的日期標籤 `title` 是備註、文字只有日期，沒有備註的不帶 `title`。整串 class 的其他部分（圓角、內距、框線深淺）是寫死的內容，不寫斷言，在瀏覽器量；綠色看不看得出是假日、跟連結分不分得開，截圖交給使用者判斷。

## Implementation Contract

**行為**（路線頁 `/routes/:route_id` 與班表頁 `/routes/:route_id/timetable` 頁首的「涵蓋的日子」那一列）：

- 每個 `[data-covered-days] [data-day]` 的文字正好是 `day_label`，例如 `2026-10-26（一）`，不接備註。
- `day_note` 有值的那一天，`[data-day]` 帶 `title`，值就是 `day_note`，例如 `補假`；`day_note` 是 `nil` 或空字串的那一天，元素沒有 `title` 屬性。
- `data-day-type`（路線頁掛在那一列的 `div`，班表頁掛在頁首的 `header`）是 `holiday` 時，日型別標籤與每個日期標籤的 class 含 `border-green-200 bg-green-50 text-green-800`，不含 `bg-slate-50`；是 `weekday` 時含 `border-slate-200 bg-slate-50 text-slate-700`，不含任何 `green-` class。
- 不變的：「涵蓋的日子」那幾個字（`text-slate-500`）、另一種日型別的連結（teal-700、底線、`data-other-day-type`）、`data-day-type`、`data-covered-days`、`data-day`、範圍切換、沒有資料時的提醒框、首頁路線卡、班表單子的「資料依據」與列印。

**介面**：`ApplicationComponent#day_tag_class(day_type)` 收 `"weekday"` 或 `"holiday"`，回傳 String；常數 `ApplicationComponent::DAY_TAG_COLORS` 是這兩個鍵對應顏色 class 的凍結 Hash。

**失敗的樣子**：`day_type` 不是這兩個鍵時 `day_tag_class` 丟 `KeyError`，頁面畫不出來，跟 `day_type_label` 一樣不留預設值。

**驗收**：

- 新例子在改程式之前失敗、改完之後通過；`bundle exec rspec spec/components/application_component_spec.rb spec/components/route_coverage_component_spec.rb spec/components/timetable_header_component_spec.rb spec/requests/routes_spec.rb` 綠。
- `bin/rubocop` 對改到的 `.rb` 檔沒有 offense（這個專案的 RuboCop 不檢查 `.erb`）；`bin/rails parallel:spec` 全綠。
- 瀏覽器（`bin/dev`、開發資料庫）：路線頁看假日與看平日、班表頁看假日，1280 寬與 390 寬（390 用 CDP 模擬）；量綠色標籤計算後的字色與底色、換成 rgb 的對比不低於 4.5:1，平日標籤的計算顏色跟改之前一樣；有備註的日期標籤 DOM 上有 `title`；截圖的完整路徑交給使用者，使用者看過才算驗收。

**範圍**：做的是兩個頁首那一列的標籤、`day_tag_class` 與上面列的測試、`route-page` 規格的 Day coverage。不做的是首頁、列印、`day_note` 的內容、詞彙表（`docs/spectra/LANGUAGE.md` 的「日型別」只描述 `day_note` 這個欄位，沒寫它怎麼顯示）。

## Risks / Trade-offs

- [手機看不到備註，例如 10-26 這種週一的補假，只看得到一顆綠色的週一] → 日型別標籤寫出「假日」，資料限制寫明照辦公日曆分；使用者 2026-10-26 接受。
- [`title` 鍵盤使用者叫不出來，螢幕報讀器唸不唸要看瀏覽器] → 備註是補充，平日或假日由日型別標籤的文字講，顏色不是唯一的線索；不另加只給螢幕報讀的文字，否則頁面文字又會含備註，跟「標籤只寫日期」的規格對不上。
- [綠色標籤緊鄰 teal 連結，讀起來像同一組或像連結] → 用色相離 teal 較遠的 green；標籤有底色與框、連結是有底線的字；截圖交給使用者判斷。
- [Tailwind 沒把 `.rb` 裡的 class 編進 CSS，標籤沒有顏色] → `@source "../../components"` 涵蓋 `app/components/application_component.rb`；瀏覽器驗收量的是計算後的顏色，沒編進去會直接量到。
- [開發資料庫沒有假日的路線日，畫面驗不到綠色] → 驗收前用筆電的鏡射資料載入一天假日（任務裡寫明指令），只寫開發資料庫。
