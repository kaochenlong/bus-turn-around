## Context

這個 change 接在 `01-route-page-visual-refresh` 之後：那邊已經有字級 token（`text-body`、`text-section` 等）、`CardComponent` 包裝層，區塊元件本身不帶外框。路線頁 `app/views/routes/show.html.erb` 目前的順序是摘要、分佈圖、沿線人數圖、行駛時間、折返停留表、換休息試算、捷運重疊、載客剖面表、資料限制，`spec/requests/routes_spec.rb` 用 `data-section` 驗這個順序。

可以直接重用的物件：

- `RoutePage::LayoverStats#rows`：每個方向一列（`go_back`、`stop_name`、`n_layovers`、`percentiles` 三個值、`short_share`），沒有折返停留的方向也有一列。每次呼叫都會查一次資料庫，沒有記住結果。
- `RoutePage::Ends`：`stopping?(go_back)`、`stopping_go_backs`。
- `RoutePage::MrtOverlap`：`directions`（每個方向的 `shares`）與 `needs_reload?`，站牌查一次後記住。
- `RoutePage::Summary`：`trips`、`complete_trips`。

數字的格式散在各元件：`LayoverTableComponent#minutes` 是 `%.1f`、沒有值時是「—」，`#share` 是 `%.1f%%`；`MrtOverlapComponent#share` 也是 `%.1f%%`。

頁面互動只有 Alpine。`LoadChartComponent` 的 `section` 帶 `x-data="{ band: ... }"`，非預設時段的 `g[data-band]` 帶 `x-cloak`；`RunTimeTableComponent` 兩個方向各一個 `div[data-direction]`，640px 以上並排。

同時有兩個 change 在進行（2026-10-23 看到的）：

- `day-types`：頁首會標出涵蓋的日子是平日還是假日、每天的日曆備註、另一種日型別最近一天的連結；也改 `ApplicationComponent`。
- `layover-other-routes`：改 `app/components/layover_table_component.yml` 的折返停留說明。

這個 change 等它們與 `01-route-page-visual-refresh` 都 archive 之後才 apply，下面寫到的現況以那時的程式為準。

## Design Source

- 來源：Claude Design 畫布「路線頁改版方向」https://claude.ai/artifact/CmriGZNTTWaGtCyeMhryDK，畫板「B 手機優先・桌機」（1280 寬）與「B 手機優先・手機（可操作）」（390 寬），2026-10-23 取得。數字是中山幹線 2026-10-19 到 21 的實際值。
- 快取：`.spectra/design-cache/02-route-page-mobile-first/B-Desktop.dc.html`、`.spectra/design-cache/02-route-page-mobile-first/B-Phone.dc.html`（`.spectra/` 在 `.gitignore` 裡，只存在本機）。
- 字級、顏色、卡片沿用 `01-route-page-visual-refresh` 的 Design Source；下表只列這個 change 新增的部分（稿上的 hex，對應 Tailwind class）。

| 元素 | 640px 以上 | 手機 |
| --- | --- | --- |
| 網站名稱列 | 白底、下框 1px `#e2e8f0` slate-200；內距 14px 32px（同 `main` 最寬 1080px）；連結 17px 600 `#0f766e` teal-700、無底線 | 內距 14px 16px |
| 頁首 | 不放卡片；路線名與起迄在左，範圍切換與涵蓋的日子靠右一欄；日子標籤白底 | 上下排列 |
| 重點數字卡 | 一列 4 張、間距 16px；白底、外框 slate-200、圓角 14px、內距 20px 22px；標籤 15px `#475569`；數字 Barlow Semi Condensed 44px 600 `#0f172a`；單位 17px `#64748b`；說明 15px `#64748b`；可點的卡右上角向下箭頭（stroke 圖示，path `M12 5v14M6 13l6 6 6-6`，18px，stroke 2，`#0f766e`） | 2×2、間距 12px；內距 16px；數字 36px；單位 16px；不畫箭頭 |
| 區塊導覽 | 黏在上方；底 `#f8fafc`、下框 1px slate-200；上下內距 12px；標籤之間 8px；每個標籤內距 7px 16px、外框 1px `#cbd5e1` slate-300、圓角 999px、白底、16px 500 `#334155` | 滿版寬、內距 10px 16px；標籤內距 8px 16px，不換行、橫向捲動 |
| 小標（指標名稱） | 14px 600、字距 0.04em、`#0f766e`，標題上方 6px | 同 |
| 卡內分隔線 | 1px slate-200，上 32px、下 20 到 24px | 上 28px、下 20px |
| 行駛時間橫條 | 欄寬 150px、左內距 18px；底軌高 12px、圓角 3px、`#f1f5f9`；p50 到 p95 的條 `#5eead4` teal-300；p85 直線寬 2px、上下各凸出 4px、`#115e59` teal-800；樣本少的條 `#cbd5e1`、直線 `#64748b`；表頭寫刻度兩端與中點，12px | 不畫 |
| 換休息試算對照 | 兩欄、間距 16px、最寬 760px；每欄外框 slate-200、圓角 12px、內距 20px 22px；欄名 16px 600 `#334155`；每列標籤 16px `#475569`、數字 Barlow Semi Condensed 36px 600；最忙的小時 14px `#64748b`；列間 1px `#f1f5f9`；下面兩個小數字塊 `#f8fafc` 底、圓角 12px、內距 14px 18px、數字 30px | 依指標分兩組，每組標題 17px 600，兩格並排（內距 12px 14px、圓角 10px、數字 32px）；小數字塊兩格並排、數字 28px |
| 手機的折返停留卡 | 不適用 | 內距 16px、外框 slate-200、圓角 12px；上方方向 15px `#64748b`、末站 18px 600、右側折返方式標籤；下方三欄格線、間距 12px 8px；欄名 14px `#64748b`；數字 Barlow Semi Condensed 26px 600、「分」14px；「不到 15 分鐘」占兩欄 |
| 方向切換 | 不顯示 | 跟時段切換同一個分段按鈕樣式，兩個按鈕平分寬度、高度至少 44px |
| 每站一列的長條 | 不顯示 | 表頭 13px `#64748b`（站名、0 到刻度頂端、人）；每列最小高 32px、左右內距 8px；站名欄 150px、15px、行高 1.25，可換行；底軌高 12px `#f1f5f9`、長條 `#0f766e`、圓角 3px；數字欄 38px、15px 靠右；重疊路段的列底色 `#e0f2fe` sky-100；路段第一列前一行標題，14px 500 `#075985` sky-800 |
| 逐站表的收合 | 外框 slate-200、圓角 12px、`#f8fafc` 底；標題列內距 16px 20px；標題 18px 600、說明 15px `#64748b` 同一行；右側向下 chevron（path `M6 9l6 6 6-6`，22px，stroke 2，`#475569`） | 標題列內距 14px 16px；標題 17px、說明 14px 換到第二行 |

## Goals / Non-Goals

**Goals:**

- 390px 寬的手機打開路線頁，第一個畫面就看到四張重點數字卡的數字。
- 同一個指標的圖與表在同一張卡裡；逐站表預設收起。
- 手機上每一個表格與圖都不用橫向捲動整頁，沿線人數每一站的名字都看得到。
- 每一頁都能回首頁。

**Non-Goals:**

- 指標定義、衍生表、`analysis/` 的任何改動。
- 重點數字以外的新彙總值；用顏色或門檻標示好壞。
- 區塊導覽標出目前位置（scroll spy）。
- 網站名稱列上的其他連結。

## Decisions

### 網站名稱列由 layout 輸出，每頁一條，只放回首頁的連結

新增 `SiteBarComponent`，layout 在 `<body>` 的第一個位置輸出：`<header data-site-bar>` 裡一個 `<a href="/">`，文字是 `t("site.name")`。它不帶 `data-section`，各頁的區塊順序測試不受影響。首頁 `HomeHeroComponent` 拿掉標題上方那行網站名稱，網站名稱在首頁的 body 裡只出現一次。

理由：路線頁現在沒有回首頁的路；之後的車牌查詢、回報表單也需要。放在 layout，每頁自動都有，跟 `site-layout` 的顯名聲明 footer 同一個做法。`home-page` 把「共用的頁首導覽」列為非目標，理由是「各自等有東西再開 change，不留空殼」；這是範圍上的限制，不是否決。現在有回首頁的需要，所以只加這一個連結。

替代方案：只在路線頁放（否決：下一個頁面還要再做一次，而且首頁與路線頁的頂部不一致）；首頁同時保留 hero 那行網站名稱（否決：網站名稱列的下面緊接同一個名字）。

### 區塊依指標分組：同一個指標的圖與表放進同一張卡

**Supersedes**: route-page-charts / 兩張圖放在摘要後面，表格順序不變

`show.html.erb` 的順序與分卡：

1. 頁首（`RouteCoverageComponent`，不放卡片）。
2. 重點數字（`RouteSummaryComponent`，`section[data-section=summary]`）。
3. 區塊導覽（`SectionNavComponent`）。
4. `CardComponent(id: "layovers")`：`LayoverChartComponent`、分隔線、`LayoverTableComponent`。
5. `CardComponent(id: "buffer")`：`BufferTradeComponent`。
6. `CardComponent(id: "runtimes")`：`RunTimeTableComponent`。
7. `CardComponent(id: "load")`：`LoadChartComponent`、分隔線、`MrtOverlapComponent`（它的 `section` 帶 `id="mrt"`）、分隔線、`LoadProfileTableComponent`。
8. `CardComponent(id: "limits")`：`DataLimitationsComponent`。

`data-section` 的順序變成 `summary layover-chart layovers buffer-trade run-times load-chart mrt-overlap load-profile limitations`。每張卡加 `scroll-margin-top`，從導覽跳過去時標題不會被黏住的導覽蓋住。

被推翻的決定，理由是「第一次打開路線頁的人，在摘要下面先看到兩張圖」。分佈圖仍然是摘要之後的第一張圖；沿線人數圖移到行駛時間之後。駕駛（`docs/use-cases.md` 第 11 節）與站長（第 1 節）要的都是行駛時間、折返停留與試算，捷運重疊主要是公運處與審議會在看。使用者 2026-10-23 看過設計稿後同意。

替代方案：順序不動，只加導覽與重點數字（否決：圖與表仍隔著兩三個區塊，手機上來回捲動的問題沒解）。

### 重點數字取自表格用的同一批物件與同一個格式

`RouteSummaryComponent.new(summary:, layover_stats:, ends:, mrt_overlap:)`。`show.html.erb` 只建一次 `RoutePage::LayoverStats`，傳給摘要與 `LayoverTableComponent`；`LayoverStats#rows` 改成記住結果，兩個元件共用一次查詢。數字格式搬到 `ApplicationComponent`：`minutes(value)`（`%.1f`，nil 時「—」）、`share(value)`（`%.1f%%`，nil 時「—」）。`LayoverTableComponent`、`MrtOverlapComponent` 與 `RouteSummaryComponent` 都用它們，所以卡上的字與表上的字一定一樣。

四張卡：

1. 趟次：`summary.trips`，說明「完整趟次 N 趟」。`data-trips`、`data-complete-trips` 照舊。
2. 停車端折返停留 p50：`ends.stopping_go_backs` 的每一端一行，數字是那一列的 `percentiles[1]`，說明是「末站名・休息的上限」。
3. 停車端不到 15 分鐘：同樣每一端一行，數字是那一列的 `short_share`，說明「共 N 筆」（`n_layovers`）。
4. 捷運重疊（500 公尺內）：去程的 `shares[500]` 當主數字，說明寫返程的值；`needs_reload?` 時兩個都是「—」。

沒有停車端時，第 2、3 張合成一張，寫「兩端都是開過去就走，沒有停車的一端」，不放數字。第 2 到 4 張整張是連結，分別連到 `#layovers`、`#layovers`、`#mrt`。測試用的掛勾：`[data-key-number=layover-p50]`、`[data-key-number=short-share]`、`[data-key-number=mrt-share]`，每一行帶 `data-end=<go_back>` 或 `data-direction=<go_back>`。

折返停留表裡被重點數字引用的格子（停車端那一列的 p50 與不到 15 分鐘）`font-semibold`，讀者在表上找得到摘要的來源；只用字重。

理由：`route-page-charts` 的目標「不會出現第二套定義」與 `home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」。後者的理由是數字旁邊要有定義與資料限制；重點數字在同一頁、帶「休息的上限」這類限定詞，點了就到定義那一區。同一批物件、同一個格式，從程式上保證不會出現第二套數字。

替代方案：另寫一個 `RoutePage::KeyNumbers` 重新查詢（否決：多一次查詢，也多一個數字可能對不上的地方）；兩個停車端合併成一個 p50（否決：表上沒有這個值）。

### 區塊導覽只用錨點連結，CSS 讓它停在畫面上方

新增 `SectionNavComponent`：`<nav aria-label="本頁區塊" data-section-nav>` 裡六個連結，依序是 `#layovers`、`#buffer`、`#runtimes`、`#load`、`#mrt`、`#limits`，文字是折返停留、換休息試算、行駛時間、載客剖面、捷運重疊、資料限制。`sticky top-0`，手機上滿版寬、橫向捲動。沒有資料的日子不輸出（`show.html.erb` 只在 `@coverage.data?` 時 render）。不帶 `data-section`。

替代方案：用 JS 做捲動位置高亮（否決：列為非目標，連結本身不需要 JS）。

### 逐站表收進預設關閉的 details

`LoadProfileTableComponent` 的 `section[data-section=load-profile]` 裡放一個不帶 `open` 的 `<details data-load-profile>`。`<summary>` 寫「逐站數字：載客剖面表」與「N 站 × 4 個時段，每格是中位數 / p90（趟數）」，N 是表上的站列數。表格本身與 `01-route-page-visual-refresh` 的分組相同，整張在伺服器輸出裡。原本的區塊標題「載客剖面」改當這張卡的小標，由 `LoadChartComponent` 輸出。

替代方案：用 Alpine 切換顯示（否決：`<details>` 不需要 JS，鍵盤與螢幕報讀都原生支援）。

### 行駛時間的橫條用 HTML 定位，刻度兩個方向共用

`RunTimeTableComponent` 從兩個方向的所有列算刻度：下界是最小 p50 往下取到 10 的倍數，上界是最大 p95 往上取到 10 的倍數，兩者相同時上界再加 10。只有一個方向有列時，刻度只看那個方向；兩個方向都沒有列時不算刻度，不輸出橫條、說明那一行與 `data-scale-*`，每個方向照舊寫「沒有可算的趟次。」每一列多一格（`hidden sm:table-cell`），裡面一條底軌、一段從 p50 到 p95 的條、一條 p85 的直線，位置用百分比的 `left` 與 `width`。格子帶 `data-bar-from`、`data-bar-to`、`data-bar-mark`（分鐘），表格帶 `data-scale-from`、`data-scale-to`。表上方一行說明「每列右邊的橫條從 p50 畫到 p95，中間的直線是 p85，刻度 A 到 B 分鐘」。

用 HTML 而不用 SVG：每格只是一條橫條，HTML 定位比較簡單；`route-page-charts` 選伺服器輸出 SVG 的三個理由（不加 npm 相依、數字在 `data-*` 上測得到、不用等 JS）在這裡同樣成立。

替代方案：每個方向各自的刻度（否決：去程、返程的長短就不能直接比）；手機也畫（否決：390px 寬的表格已經放不下第六欄）。

### 窄螢幕的方向切換用 Alpine，沒有 JS 時兩個方向都在

- 行駛時間：`section` 帶 `x-data="{ direction: 0 }"`；兩個 `div[data-direction]` 各帶 `x-bind:class`，不是目前方向時加 `max-sm:hidden`；切換按鈕帶 `x-cloak` 與 `sm:hidden`。
- 每站一列的長條：在 `LoadChartComponent` 既有的 `x-data` 加 `direction: 0`；每個方向一組列，帶 `x-show="direction === N"`，不帶 `x-cloak`；整組列放在 `sm:hidden` 的容器裡。
- 切換不改網址、不重新載入。

沒有 JS 時 `x-bind` 與 `x-show` 都不作用，伺服器輸出的兩個方向都沒有隱藏的 class 或 style；切換按鈕帶 `x-cloak`，不會出現。640px 以上 `max-sm:hidden` 不作用，行駛時間兩個方向並排。

替代方案：純 CSS 的 radio 切換（否決：專案的頁面互動都用 Alpine，`load_chart_component` 已經是這個做法）。

### 窄螢幕的沿線人數改成每站一列，跟 SVG 一起由伺服器輸出

`LoadChartComponent` 在每個方向的 SVG 之外，再輸出一組每站一列的長條，SVG 那份 `figure` 加 `max-sm:hidden`。列的資料來自同一個 `charts`：站序取最新一天的 `LoadProfile#stops`，中位數取同一個 `medians`，長條長度是中位數除以同一個 `scale_top`。

- 每列帶 `data-row-seq`、`data-row-median`（沒有人數時不帶 `data-row-median`，顯示「—」、不畫長條）。屬性名跟 SVG 的 `data-seq`、`data-median` 分開，`spec/components/load_chart_component_spec.rb` 數點的例子不會數到兩份。
- 重疊路段的列帶 `data-row-near` 與 sky-100 底色；路段第一列前一行標題「靠近捷運：起站名–迄站名」。沒有距離時沒有底色也沒有標題。
- 四個時段各一組列，用同一個 `band` 狀態切換；非預設時段帶 `x-cloak`，跟 SVG 一樣。

替代方案：SVG 在手機上改畫直式（否決：站名在 SVG 裡要自己算換行，HTML 列自然換行）；只輸出一份，用 CSS 把 SVG 變直式（做不到）。

### 窄螢幕的折返停留表用 CSS 改成卡片，不另外輸出一份

`LayoverTableComponent` 的表格在 640px 以下用 `max-sm:` 樣式把 `thead` 藏起來，每個 `tr` 變成一張卡（`display: grid`），前三格（方向、末站、折返方式）當卡頭，後五格每格用 `data-label` 加 `before:content-[attr(data-label)]` 顯示欄名。偽元素不在 DOM 文字裡，`spec/components/layover_table_component_spec.rb` 取的格子文字不變。

替代方案：手機另外輸出一份卡片（否決：同一批數字出現兩份，測試要分兩邊驗）。

### 文案

tw 與 zh-TW 用同一份（照既有的 `<<: *tw`），en 另寫。

- `LayoverChartComponent`：小標「折返停留」；標題不變；說明最後一句改成「每根長條旁是筆數，精確的百分位數在下面的表。」
- `LayoverTableComponent`：拿掉自己的標題與說明，改帶 `sr-only` 的 `caption`「折返停留」給螢幕報讀；表下一句「只算本趟有到末站、下一趟從起站出發的配對，另一端漏站不影響。」；開過去就走那句不變。`layover-other-routes` 會改這份 `.yml` 的說明（加上兩趟之間跑了別條路線不算），表下那一句要包含它 archive 後的說法，不能把它刪掉。
- `BufferTradeComponent`：小標「換休息試算」，標題「每趟加緩衝」，說明不變；兩欄對照沿用既有的 `lower`、`upper`、`vehicle_hours`、`peak_vehicles` 文案。
- `RunTimeTableComponent`：小標「行駛時間」，標題「一趟從起站到末站要跑多久？」，說明不變，加上橫條那一行說明。
- `LoadChartComponent`：小標「載客剖面」；標題不變；說明改成「圖上是每一站車上人數的中位數，依趟次起點的小時分時段；底色是 500 公尺內有捷運出入口的連續站。靠近捷運不等於可以被捷運取代。一站在這個時段沒有人數時，那一站留空。精確數字在下面的逐站表。」；每站一列的表頭「站名」「人」，下面一句「同一個方向四個時段用同一個刻度。」
- `MrtOverlapComponent`：標題「與捷運重疊」改成卡內的小標題層級，文字不變。
- `LoadProfileTableComponent`：收合列的兩句（見上面的決定），收合裡一句「車上人數取每站的離站記錄，沒有離站記錄時取到站記錄。時段依趟次起點的小時。」
- `RouteSummaryComponent`：「趟次」「完整趟次 %{count} 趟」「停車端折返停留 p50」「%{stop}・休息的上限」「停車端不到 15 分鐘」「共 %{count} 筆」「捷運重疊（500 公尺內）」「去程」「返程 %{share}」「兩端都是開過去就走，沒有停車的一端」。
- `SectionNavComponent`：六個連結文字與 `aria-label`「本頁區塊」。

理由：小標用 `docs/spectra/LANGUAGE.md` 裡的正式名稱，讀者能對回詞彙表。標題是問句、不寫斷言，跟 `route-page-charts` 的「兩張圖的標題各是一句問題」一致。

### 手機的第一個畫面放得下四個重點數字

在 390×844 的視窗，網站名稱列、頁首與重點數字卡的高度合起來，要讓四張卡的數字（不只卡的頂端）都在 844px 以內。頁首在手機上：路線名 30px、起迄一行、範圍切換 44px、涵蓋的日子小標籤換行；`day-types` 之後還多了日型別、日曆備註與另一種日型別的連結，跟涵蓋的日子放在同一組標籤裡。

量法：`spec/system/route_page_mobile_spec.rb` 用 fixture 的 9001（兩端都停車，第 2、3 張卡各兩行，比中山幹線高），量每張卡數字元素的 `getBoundingClientRect().bottom`。放不下時先把頁首的範圍切換與涵蓋的日子併成一列，不縮小數字。

## Implementation Contract

完成時可以觀察到：

- 每一頁 `<body>` 的第一個元素是 `header[data-site-bar]`，裡面的連結指向 `/`、文字是網站名稱；首頁 body 裡「折返點 TurnAround」只出現一次。
- 有資料的路線頁，`data-section` 依序是 `summary layover-chart layovers buffer-trade run-times load-chart mrt-overlap load-profile limitations`；摘要之後有 `nav[data-section-nav]` 六個連結，每個 fragment 都對得到頁面上包住那一區的元素。沒有資料的日子沒有導覽。
- 重點數字：`[data-key-number=layover-p50] [data-end=N]` 與 `[data-key-number=short-share] [data-end=N]` 的數字文字，等於折返停留表 `tr[data-direction=N]` 對應格子的文字；`[data-key-number=mrt-share]` 的數字等於捷運重疊表 500 公尺那一欄。沒有停車端、沒有折返停留、距離沒有載入三種情況照 spec。
- 逐站表在 `details[data-load-profile]` 裡，沒有 `open` 屬性，每一站的列都在回應裡。
- 行駛時間每一列有 `data-bar-from`、`data-bar-to`、`data-bar-mark`，表格有 `data-scale-from`、`data-scale-to`，刻度照 spec 的例子。
- 390×844：四張卡的數字都在第一個畫面；行駛時間預設只顯示去程，按「返程」只顯示返程，網址不變；沿線人數顯示每站一列、SVG 不顯示，切換時段時列的數字跟著換；行駛時間沒有橫條；捲到行駛時間那一區時導覽的上緣是 0。1400×1400：行駛時間兩個方向都顯示，沒有方向切換。
- 沒有 JS（`rack_test`）時：兩個方向的行駛時間表與每站一列都在回應裡，都沒有 `max-sm:hidden`、`hidden` 或 `display: none`。

驗收：`spec/requests/routes_spec.rb`、`spec/requests/site_layout_spec.rb`、`spec/requests/pages_spec.rb`、相關元件測試與新的 `spec/system/route_page_mobile_spec.rb` 全綠；`bin/rails parallel:spec` 全綠；`bin/dev` 在 390 與 1280 寬對照 `.spectra/design-cache/02-route-page-mobile-first/` 的兩張稿。

範圍內：上面列的元件、`show.html.erb` 的順序與分卡、layout 的網站名稱列、首頁 hero 那一行、`LayoverStats#rows` 記住結果、`ApplicationComponent` 的數字格式、三個語系的文案、測試。

範圍外：`app/models/` 除了 `LayoverStats#rows` 記住結果以外的任何程式、`analysis/`、衍生表、路由與控制器、`bin/health-card`、指標定義、首頁 hero 那一行以外的內容。

## Risks / Trade-offs

- [沿線人數多一份每站一列的 HTML，回應變大] → 估計值：中山幹線兩個方向 91 站 × 4 個時段 = 364 列，每列約 350 bytes，未壓縮約 130 KB，壓縮後應該只剩一成左右（重複的 class 很多）。apply 時量改版前後 `/routes/15373?range=7d` 用 gzip 的回應大小，記在任務下面；壓縮後多出超過 30 KB 就把列的 class 收到父元素的選擇器上。
- [黏住的導覽擋住錨點跳過去的標題] → 卡片加 `scroll-margin-top`，系統測試量跳轉後標題的位置在導覽下面。
- [兩端都停車的路線，重點數字卡變高，手機第一個畫面放不下] → 系統測試用兩端都停車的 fixture 量；放不下時先壓縮頁首，不縮小數字。
- [`max-sm:hidden` 由 Alpine 綁定，Turbo 換頁或 morph 後狀態重置] → 方向狀態不放網址，換頁回到預設去程，跟時段切換一樣。
- [被推翻的「兩張圖放在摘要後面」：第一次來的人要捲過試算與行駛時間才看到沿線人數圖] → 導覽與重點數字卡都連得到；這是使用者看稿後的取捨。

## Migration Plan

沒有資料或設定要遷移，照一般部署；要撤回就 revert 這個 change 的 commit。apply 要等 `01-route-page-visual-refresh` archive 之後開始。

## Open Questions

（無）
