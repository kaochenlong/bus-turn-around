## Context

路線頁「載客」那張卡的沿線人數圖（`LoadChartComponent`，`[data-section=load-chart]`）每個方向一組：640 px 以上是 `<figure>` 裡的 SVG，以下改成每站一列。SVG 的 viewBox 是 840 × 250，常數 `LEFT` 40、`RIGHT` 16、`TOP` 30、`BOTTOM` 36；SVG 是 `w-full min-w-[720px]`，外層是 `overflow-x-auto`，再包一層 `@container relative`，右緣疊一條漸層。

已核對的事實（2026-10-24，對照 `app/components/load_chart_component.rb`、`.html.erb`、`app/models/route_page/mrt_overlap.rb` 與測試）：

- 重疊路段來自 `RoutePage::MrtOverlap#stretch_ranges`：每個方向一串 `first_seq..last_seq`，從照 `seq` 排好的站牌切出來，所以是站序；每段至少兩站（`runs` 只留兩站以上、`seq` 相鄰的）。相鄰兩段之間至少隔一個不靠近捷運的站，或隔一個 `seq` 缺口。
- 現在每段是一個 `<g data-span-from data-span-to data-first-stop data-last-stop>`，裡面一個 `rect.fill-sky-100` 與一個 `text.fill-sky-800.text-label`：文字以底色帶中點置中（`span_x + span_width / 2`），y 是 `TOP - 10`。單位「人」是 `text-label-sm`，在 x 4、同一個 y。
- 測試釘住的東西：`spec/components/load_chart_component_spec.rb` 只檢查 `<g>` 上的四個 `data-*` 屬性，沒有斷言畫面上的名字。`spec/system/route_page_layout_spec.rb` 的 `scroll_boxes` 要求 `[data-section=load-chart] svg` 的每一個都有 `overflow-x: auto` 的祖先。`spec/system/route_page_mobile_spec.rb` 量 `[data-section=load-chart] figure` 在 1400 寬是 `block`、在手機是 `none`。
- 量到的問題見 proposal 的表：中山幹線兩個方向各一段、正常；251 與 251區 的四張圖有重疊、被切或壓到「人」（名字寬度是估計的，251 那兩列跟截圖一致）。

加上連動時核對的事實（2026-10-24）：

- 元件的 `<section>` 已經有 Alpine 的 `x-data`，記住時段（`band`）與窄螢幕的方向（`direction`）。專案的 Alpine 是 3.17.4：`x-bind` 綁到一般屬性的值是 `false` 時會拿掉那個屬性（`aria-pressed` 這類例外）。
- 網站既有的 hover：首頁路線卡（`route_list_component`）與起點區塊（`origin_story_component`）用 `transition-colors` 換顏色。Tailwind 是 4.3.3，`transition-colors` 的屬性清單含 `fill`。
- system spec 用的 9001 fixture 每個方向只有一段重疊路段（去程第 1 到 3 站、返程第 6 到 8 站，`spec/fixtures/analysis/README.md`）。`route_day` 的 factory 預設就是 9001 的 2026-10-19，`spec/requests/routes_spec.rb` 用 factory 造的資料渲染整個路線頁；既有的 `:duckdb` system spec 也是在例子裡寫入資料再開頁面。

相關而且仍然有效的決定：

- route-page-charts「圖由伺服器輸出成內嵌 SVG，不用圖表套件」：編號的位置由伺服器算好，不靠 JavaScript。
- route-page-charts「重疊段用 `MrtOverlap#stretch_ranges`，不查車上人數」：照用，不改。
- 01-route-page-visual-refresh「沿線人數圖改成 840 寬的 viewBox，手機上最小 720px 寬」：viewBox、最小寬度、站名與刻度的字級都不變。那條決定寫的「底色帶標題 `text-label`（14）」，這次移到圖下方的清單，字級 token 仍是 `text-label`。
- 02-route-page-mobile-first「窄螢幕的沿線人數改成每站一列，跟 SVG 一起由伺服器輸出」：每站一列與它的路段名稱不動。

詞彙照 `docs/spectra/LANGUAGE.md`：重疊路段、路線頁。這個 change 不新增詞。

## Goals / Non-Goals

**Goals:**

- 每段重疊路段在圖上有一個不會跟別段、圖的左右邊、單位「人」重疊的編號，名字在圖下方讀得到。
- 編號的位置由伺服器算好，跟底色帶同一套座標；沒有 JavaScript 時頁面一樣完整。
- 補上會抓到這類問題的測試：編號的順序、位置，以及清單。
- 滑鼠指到某一段或清單某一列時，兩邊一起變深，讀的人不用自己拿編號往下對。

**Non-Goals:**

- 名字留在底色帶上方、靠估字寬疊層或往內推；拿掉「靠近捷運：」就好；用 JavaScript 排位置。理由寫在 proposal 的 Non-Goals 與下面的決定。
- 窄螢幕每站一列、「與捷運重疊」區塊、重疊路段的定義與資料、其他圖。
- 統一圖上與「與捷運重疊」區塊連接兩個站名的符號（「–」與「－」）。
- 滑過時的提示框、其他段變淡、只放大編號圓、鍵盤移到時也變深。理由寫在 proposal 的 Non-Goals 與下面的決定。

## Decisions

### 底色帶上方畫編號圓，名字移到圖下方的清單

每段底色帶上方畫一個天藍實心圓，裡面是白色數字，同一個方向從 1 起照站序編；每個方向的圖下方列出同樣的圓加上「靠近捷運：首站–末站」。SVG 裡不再有寫出路段名字的文字。

理由：名字連「靠近捷運：」有 13 到 23 個字（數過的），寬約 175 到 276；短的路段只有 34 到 109 寬（寬度是估計）。只要名字還在圖裡、還要待在自己那段上方，就一定得估字寬並且疊層。編號的寬度固定，可以保證落在自己那段裡；名字放進 HTML 就能換行。這是使用者 2026-10-24 在討論裡選的做法。

替代方案：

- 名字留在上方、撞到就往上疊一層、碰到邊就往內推：要在 Ruby 估 Barlow 與 Noto Sans TC 的字寬，估錯就又疊回去；251區 返程要疊三層，被往內推的名字也不在自己那段上方。否決。
- 只拿掉「靠近捷運：」：省約 70，量到的重疊是 101 到 140。否決。
- 只在滑過時顯示名字（SVG 的 `<title>`）：觸控裝置沒有滑過，規格也要求名字看得到。否決。
- 用 JavaScript 量字寬再排位置：違反「圖由伺服器輸出成內嵌 SVG，不用圖表套件」，頁面要等 JavaScript 才完整。否決。

### 編號圓的大小與位置：直徑 16、圓心在底色帶中點、TOP 往上 12

`LoadChartComponent` 新增 `MARKER_RADIUS = 8` 與 `MARKER_Y = TOP - 12`（等於 18），以及算底色帶中點的方法（`span_x + span_width / 2`，取到小數一位，跟其他座標同一套 `round(1)`）。圓的 `cx` 是那個中點，`cy` 是 `MARKER_Y`，`r` 是 `MARKER_RADIUS`，class `fill-sky-800`。數字是 `text-label-sm`（13）、`fill-white`、`font-semibold`、`text-anchor="middle"`，垂直置中照刻度文字的做法用基線位移（刻度是 `y + 5`），不引入新的屬性。

為什麼一定擺得下（算出來的）：

- 在自己那段裡：兩站的路段寬是 2 × 784 ÷（站數 − 1），一個方向在 99 站以內都不小於直徑 16。現在最多是 251 的 55 站（2026-10-22）。
- 不會跟別段重疊：相鄰兩段之間至少隔一站的寬度（`seq` 缺口時兩段的底色帶相接、不重疊），每個圓都在自己那段的寬度裡。
- 不會超出左右邊、不會壓到「人」：第一段的中點至少在 `LEFT` 加半站，圓的左緣至少 32；「人」在 4 到約 17。最後一段的中點至多在 `WIDTH - RIGHT` 減半站，圓的右緣至多 832。
- 圓佔的高度是 10 到 26，跟現在名字佔的那一條差不多，`TOP` 不用改，繪圖區不會移動。

理由：直接用現在名字的那一條高度，圖的版面不變；有圓的數字不會被看成縱軸的人數。

替代方案：

- 字型裡的圈號字（①②③）：長相取決於字型堆疊裡哪一個字型有這些字，網頁字型還沒載入時會退到系統字，因平台而異；圓畫在 SVG 裡就不受字型影響。否決。
- 圓放在底色帶裡面的頂端：中位數高的時候會跟線疊在一起。否決。
- 沒有圓的數字：旁邊就是縱軸的 0、25、50。否決。

### 清單用 HTML、放在橫向捲動那一層外面、不含 svg

每個方向的 `<figure>` 裡，在 `@container relative` 那一層（裡面是橫向捲動的那一層與右緣漸層）之後，放一個 `ol[data-span-legend]`。每一段一個 `li`，帶 `data-span-number`、`data-first-stop`、`data-last-stop`，內容依序是：

- 一個 `span[aria-hidden="true"]` 畫的圓：`inline-flex size-5 shrink-0 items-center justify-center rounded-full bg-sky-800 text-label-sm font-semibold text-white`，裡面是編號。
- 「靠近捷運：首站–末站」，沿用 `t(".span", first:, last:)`，樣式照窄螢幕路段名稱那一行（`data-row-span`）的文字部分：`text-label leading-[1.4] font-medium text-sky-800`，不加它的淺底色。

清單本身 `mt-2.5 flex flex-wrap gap-x-5 gap-y-1.5`，寬度不夠就換行。沒有路段的方向不輸出清單。

理由：

- 清單裡不能有 `<svg>`：`route_page_layout_spec.rb` 的 `scroll_boxes` 要求載客那一塊裡每一個 `svg` 都在 `overflow-x: auto` 的那一層裡，清單在那一層外面，用 svg 畫圓會讓那個例子失敗。
- `<figure>` 在 640 px 以下是 `max-sm:hidden`，清單放在裡面就跟著圖出現與隱藏，窄螢幕仍是每站一列。
- 編號 `aria-hidden`：圖是 `role="img"`，圖上的編號不給輔助科技，清單前面唸出「1」也對不到任何東西。路段名稱現在只在 `role="img"` 的 SVG 裡，放進清單後才讀得到。
- 圓的樣子跟 SVG 裡的圓同一個顏色，讀的人一眼對得上；天藍色現在只有這個元件在用，不多花一個顏色。

替代方案：

- 清單放在橫向捲動那一層裡面：會跟著圖捲走，也不會照卡片寬度換行。否決。
- 在 SVG 底部畫清單：又要估字寬。否決。
- 不另外列，靠下面「與捷運重疊」區塊的路段清單：中間隔著分隔線與一張表，規格也要求圖要讀得出每一段的名字。否決。

### 測試鎖住編號順序、位置與清單，不鎖樣式

`spec/components/load_chart_component_spec.rb` 用方向 0 第 0 到 4 站距離 400、450、900、250、300 公尺的資料（兩段：第 0 到 1 站、第 3 到 4 站），斷言：

- `[data-span-number]` 的 `<g>` 依序是 1、2，各自的 `data-span-from`、`data-span-to` 是 0、1 與 3、4。
- 每個圓（`circle[data-span-marker]`）的 `cx` 等於同一個 `<g>` 裡 `rect` 的 `x + width / 2`（取到小數一位），`cy` 是 18，`r` 是 8。
- 每個 `<g>` 裡的文字只有編號；SVG 裡沒有任何文字含「靠近捷運」，也沒有任何文字含乙站或丁站。橫軸兩端的站名（甲站、戊站）是方向的首末站，照舊畫在 SVG 裡，所以不拿它們當判斷。
- `ol[data-span-legend]` 的 `li` 依序是 1、2，文字分別以「甲站–乙站」與「丁站–戊站」結尾，`data-first-stop`、`data-last-stop` 對得上。名字前面的「靠近捷運：」是 `load_chart_component.yml` 寫死的字，不寫斷言：那種斷言只在有人改那幾個字時才失敗。（2026-10-24 apply 1.1 時改；原本寫的是以「靠近捷運：甲站–乙站」結尾。）
- 站牌沒有距離時，沒有 `[data-span-number]`，也沒有 `[data-span-legend]`。

既有的例子不改。class 名稱與樣式不寫斷言。

理由：這次的問題能上線，就是因為測試只看 `data-*` 屬性；位置（圓心對準底色帶中點）是「不會重疊」這個保證的前提，所以要鎖。

替代方案：在 system spec 量每個圓的實際位置（`getBoundingClientRect`）：fixture 的 9001 路線只有五站，量不出擠的情形；保證是算出來的，元件測試鎖住前提就夠。否決。

### 指到某一段或清單某一列時，兩邊一起變深

滑鼠指到圖上某一段（那段的底色帶、編號圓或數字），或圖下方清單的某一列，那一段的底色帶從 `fill-sky-100` 變成 `fill-sky-200`，清單同一列加上 `bg-sky-100` 淺底色；滑鼠離開就恢復。其他段與另一個方向都不變。

做法：

- 每個方向的 `div[data-direction]` 帶 `x-data="{ hoveredSpan: null }"`，兩個方向各記各的；它在 `<section>` 的 `x-data` 裡面，`band`、`direction` 照樣讀得到。
- 每段的 `g[data-span-number]` 與清單每一列 `li[data-span-number]` 都帶 `x-on:mouseenter`（把 `hoveredSpan` 設成自己的編號）、`x-on:mouseleave`（設回 `null`）與 `x-bind:data-active="hoveredSpan === <編號>"`：只有指到的那一段與那一列有 `data-active`。
- 樣式由 `data-active` 決定：`<g>` 加 `group`，底色帶的 `rect` 是 `fill-sky-100 group-data-active:fill-sky-200 transition-colors`；清單的列加 `data-active:bg-sky-100 rounded-md transition-colors`，以及內距與等量的負外距（`px-1.5 py-0.5 -mx-1.5 -my-0.5`），沒指到時字的位置跟現在一樣。
- `svg` 加 `pointer-events-none`，每段的 `<g>` 加 `pointer-events-auto`：折線、點、格線、刻度與站名都畫在底色帶上面，不讓它們接收滑鼠，指在線上時底色帶才不會以為滑鼠離開了而一閃一閃。

理由：

- 改成編號的代價是讀的人要自己拿編號往下對清單（見 Risks）。指到哪一段就亮清單哪一列、指到清單就亮圖上那一段，直接幫他對；251區 返程有 4 段、清單會換行時最有用。這是使用者 2026-10-24 看過畫面後要的「hover 時有一點效果」。
- 用元件既有的 Alpine：時段切換已經靠它，不加新相依。沒有 JavaScript 時沒有這個效果，圖與清單照舊完整，名字不靠它才看得到，跟 02-route-page-mobile-first「窄螢幕的方向切換用 Alpine，沒有 JS 時兩個方向都在」同一個做法。route-page-charts「圖由伺服器輸出成內嵌 SVG，不用圖表套件」照舊：SVG 與每段的位置仍由伺服器算好，JavaScript 只切換 `data-active`。
- 狀態放在 `data-active`，不用 `x-bind:class` 換 class：`rect` 沒有 JavaScript 時也要有 `fill-sky-100`，兩個 fill class 同時在時，誰贏取決於產生出來的 CSS 順序；`data-active` 的變體選擇器比較具體，一定蓋過去。
- `transition-colors` 照首頁路線卡與起點區塊的 hover。這是 hover 的換色，不是 route-page-charts 非目標裡的圖表動畫。
- 顏色留在天藍：這個色系只有這張圖在用，不花頁面主色 teal。清單的淺底色照窄螢幕路段名稱那一行（`data-row-span`）的 `bg-sky-100`。

替代方案：

- 純 CSS（`:has()`）：不需要 JavaScript，但 CSS 比不出兩個元素的編號相同，每個編號都要寫一條自己的選擇器，還得改 `application.css`。否決。
- 指到一段時其他段變淡：對比較強，但整張圖跟著變，超過使用者要的「一點」。否決。
- 滑過時跳出寫著名字的提示框：名字已經在清單上；route-page-charts 的非目標「互動提示框、縮放、動畫，或任何 JS 圖表套件」，01-route-page-visual-refresh、02-route-page-mobile-first 都沿用。否決。
- 只讓編號圓放大或變色：沒有帶出任何資訊，還會讓人以為可以點。否決。

### 連動用瀏覽器測，資料用 factory 造兩段

連動是 Alpine 在瀏覽器裡做的，元件測試看不到，所以新增 `spec/system/load_chart_hover_spec.rb`（`:js`，不用 DuckDB）。資料用 factory 造 9001 的 2026-10-19：去程第 0 到 4 站（甲站到戊站）距離 400、450、900、250、300 公尺，兩段（1 是第 0 到 1 站，2 是第 3 到 4 站）；返程第 5 到 9 站距離 300、350、900、900、900 公尺，一段（1 是第 5 到 6 站）。等 Alpine 啟動（時段切換按鈕出現）之後，斷言有 `data-active` 的元素（方向、`g` 或 `li`、編號）：

- 指到去程清單第 2 列：只有去程的 `g` 2 與 `li` 2。
- 指到去程第 1 段的編號圓：只有去程的 `g` 1 與 `li` 1，返程的第 1 段沒有。
- 指到之後移到這一區的標題上：沒有任何元素有 `data-active`。

顏色、淡入與清單的內距是寫死的樣式，不寫斷言，留給目視驗收。

理由：斷言 `data-active` 而不是顏色，它是 Alpine 依指到哪裡切換的狀態，顏色是寫死的樣式。同一個方向要有兩段，才測得出「指到任何一段就全亮」這種錯。

替代方案：

- 用 9001 fixture：每個方向只有一段，測不到同一個方向裡只亮指到的那一段。否決。
- 在 fixture 加第二段：要改 `spec/fixtures/analysis/` 的資料與 README 的數字，牽動其他依賴 fixture 的測試。否決。
- 只靠目視：連動是「指到哪一個就亮哪一個」的分支，照專案的測試規則要有測試。否決。

## Implementation Contract

**行為**：

- 640 px 以上：每個方向的沿線人數圖，每段重疊路段是一條底色帶，上方一個天藍實心圓、白色數字，同一個方向從 1 起照站序編；圖下方列出「編號 靠近捷運：首站–末站」，順序相同、寬度不夠就換行。SVG 裡沒有寫出路段名字的文字。
- 沒有重疊路段的方向（或站牌沒有距離）：沒有底色帶、沒有編號，也沒有清單。
- 640 px 以下：照舊是每站一列，路段名稱照舊寫在每段第一列之前。
- 編號、底色帶與清單全部在伺服器回應裡，不需要 JavaScript。
- 640 px 以上、有 JavaScript：滑鼠指到某一段（底色帶、編號圓或數字）或清單某一列時，那一段的底色帶變深、清單同一列加上淺底色；其他段與另一個方向不變；移開就恢復。指在折線、點、格線、刻度或站名上時，算指到底下那一段。沒有 JavaScript 時沒有連動，其他照舊。

**介面與資料形狀**：

- `LoadChartComponent` 新增常數 `MARKER_RADIUS = 8`、`MARKER_Y = TOP - 12`，以及回傳底色帶中點 x 的方法；編號是 `chart.ranges` 的索引加 1。
- SVG：每段 `<g data-span-from data-span-to data-first-stop data-last-stop data-span-number>`，裡面是原本的 `rect.fill-sky-100`、`circle[data-span-marker]`（`cx` 底色帶中點、`cy` `MARKER_Y`、`r` `MARKER_RADIUS`、`fill-sky-800`）與編號的 `text`（`fill-white`、`text-label-sm`、`font-semibold`、置中）。
- 清單：`figure` 裡、`@container relative` 那一層之後的 `ol[data-span-legend]`；每段一個 `li[data-span-number][data-first-stop][data-last-stop]`，內容是 `span[aria-hidden="true"]` 畫的圓加上 `t(".span", first:, last:)`。清單裡沒有 `svg`。
- 連動：`div[data-direction]` 帶 `x-data="{ hoveredSpan: null }"`；`g[data-span-number]` 與 `li[data-span-number]` 指到時帶 `data-active`，沒指到時沒有這個屬性；`svg` 有 `pointer-events-none`，`g[data-span-number]` 有 `pointer-events-auto` 與 `group`。
- 文案：`app/components/load_chart_component.yml` 不改。

**失敗模式**：

- `stretch_ranges` 是空的（沒有路段，或 `needs_reload?`）：不畫圓、不輸出清單。
- 一個方向超過 99 站：兩站的路段寬小於 16，相鄰兩段的圓可能相接或重疊。現在最多 55 站，接受，寫在 Risks。
- 一個方向有 10 段以上：兩位數在直徑 16 的圓裡偏擠。現在最多 4 段（251區 返程，2026-10-22），接受，寫在 Risks。
- Alpine 沒啟動（JavaScript 被擋、載入失敗）：沒有 `data-active`，圖與清單照舊。
- 640 px 以上的觸控平板：點一下會亮，點別的地方才恢復。接受，寫在 Risks。

**驗收**：

- `bundle exec rspec spec/components/load_chart_component_spec.rb`：上面「測試鎖住編號順序、位置與清單，不鎖樣式」的斷言全過，既有例子照舊通過。
- `bundle exec rspec spec/system/load_chart_hover_spec.rb`：上面「連動用瀏覽器測，資料用 factory 造兩段」的三個例子全過。
- `bundle exec rspec spec/system/route_page_layout_spec.rb spec/system/route_page_mobile_spec.rb`：照舊全過，尤其是「折返停留表、載客剖面表與沿線人數圖各自在可以橫向捲動的框裡」與「1400 寬時沿線人數顯示 SVG 的圖，不顯示每站一列」。
- `bin/rubocop app/components/load_chart_component.rb spec/components/load_chart_component_spec.rb` 沒有 offense。
- 真資料：`bin/dev` 開 10712 與 11764 的 `?day=2026-10-22`，在 1280 px 與 720 px 寬各看一次，每個編號都在自己那段底色帶上方、沒有被切、沒有壓到「人」，圖下方的清單跟編號對得上；15373 一段的情形照樣看得懂；滑鼠逐一指每一段與清單每一列，兩邊一起變深、其他段不變，指在線上不會閃。

**範圍邊界**：範圍內是 `LoadChartComponent` 的 `.rb`、`.html.erb`、它的元件測試，以及新的 `spec/system/load_chart_hover_spec.rb`。範圍外是 `load_chart_component.yml` 的文案、窄螢幕每站一列、`MrtOverlapComponent` 與 `RoutePage::MrtOverlap`、衍生表、`app/frontend/stylesheets/application.css`、其他圖、首頁。

## Risks / Trade-offs

- [讀的人要從編號往下看清單] → 清單就在圖的正下方，順序相同、圓的樣子相同。
- [720 px 寬時字變小] → 圓的直徑約 13.7 px、數字約 11 px（算出來的，720 ÷ 840 的縮放），跟現在刻度數字的大小一樣。清單的圓固定 20 px（`size-5`），所以 720 寬時兩個圓看起來不一樣大，顏色與形狀相同。
- [640 px 以上的觸控平板點一下會亮，要點別的地方才恢復] → 接受：亮著的是對的那一段與那一列；手機（640 px 以下）不顯示這張圖。
- [用鍵盤的人沒有連動] → 清單本來就列出每一段的名字；不為了這個效果把清單的列加進 Tab 順序。
- [一個方向超過 99 站] → 兩站的路段比圓窄。現在最多 55 站；加入超過 99 站的路線時再看。
- [一個方向 10 段以上] → 兩位數偏擠。現在最多 4 段；真的出現時再放大圓。
- [底色帶上方原本的名字是最直接的讀法] → 接受，換來不管路段多短、多近都不會重疊。

## Migration Plan

- 沒有 migration，不重載資料，照常部署。
- 回退：還原 `LoadChartComponent` 的 `.rb`、`.html.erb` 與元件測試，刪掉 `spec/system/load_chart_hover_spec.rb`，圖回到名字畫在底色帶上方的樣子。
