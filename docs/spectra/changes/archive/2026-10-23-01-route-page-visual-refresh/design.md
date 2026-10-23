## Context

路線頁的樣式全寫在各元件的 Tailwind class 裡，沒有共用的字級：`app/views/routes/show.html.erb` 的 `main` 是 `text-[15px]`，表格是 `text-sm`（14px），兩張圖的 SVG 文字是 `text-[12px]` 與 `text-[11px]`，區塊標題 `text-[24px]`，路線名 `text-[32px]`。首頁 `app/views/pages/home.html.erb` 用同一個 `font-route` 與 `text-[15px]`。兩頁的 `main` 與 layout 輸出的顯名聲明 footer 各寫一份 `mx-auto max-w-5xl px-4`（最寬 1024px、左右 16px）。

兩張圖的大小靠 viewBox 加 CSS 寬度縮放：

- `LayoverChartComponent`：`WIDTH = 460`、`LABEL_WIDTH = 64`、`BAR_MAX = 300`、`ROW = 26`、`BAR_HEIGHT = 16`，SVG 是 `w-full max-w-[460px]`。390px 寬的手機上內容區 358px，縮放 0.78，12px 的字約 9.3px。
- `LoadChartComponent`：`WIDTH = 720`、`HEIGHT = 230`，SVG 是 `w-full min-w-[600px]`，外層 `overflow-x-auto`。手機上縮放 0.83，字約 10px。

這兩個數字是依模板換算，不是在瀏覽器量的。

樣本少的列整列 `text-slate-400`，趟數格後面接 `（樣本少）`。折返方式在折返停留表是純文字，在分佈圖是圖說句尾的括號 `（停車）`。載客剖面表每一列都重複方向欄。layout 的 `<body>` 沒有 class，顯名聲明 footer 由 layout 在頁面之後輸出。

改版方向在 2026-10-23 用設計稿討論（見下面的 Design Source），使用者看稿後說「字型有點太小」，字級整體放大；方向選「手機優先」並拆成兩個 change，這是第一個，只改外觀與字級。

這是 no-spec 的 change：能力層級的可觀察行為不變，區塊、順序、數字、文案（除了兩處括號，以及「涵蓋的日子（平日）：」拆成標題與日型別標籤）與 `data-*` 屬性都照舊。

## Goals / Non-Goals

**Goals:**

- 路線頁與首頁共用一套字級，內文 17px、圖上的字 14px。
- 390px 與 375px 寬的手機上，分佈圖的字實際顯示不小於 14px，頁面本身不會橫向捲動，寬表格在自己的框裡捲。
- 路線頁每個區塊一張卡，頂部一張卡收齊路線名、範圍切換、涵蓋的日子與趟次。
- 樣本少的列文字對比不低於 4.5:1。

**Non-Goals:**

- 區塊順序與內容、網站名稱列、重點數字、區塊導覽、收起逐站表、行駛時間的橫條、手機專用的圖與切換：都在 `02-route-page-mobile-first`。
- 換色票、換字型、深色模式。
- 首頁除了字級與頁面寬度以外的改動。

## Decisions

### 字級集中定義在 application.css 的 @theme，路線頁與首頁共用

在 `app/frontend/stylesheets/application.css` 既有的 `@theme` 裡加字級 token，元件改用 token 產生的 class，不再寫 `text-[15px]` 這類任意值：

| token | 大小 | 用在 |
| --- | --- | --- |
| `--text-body` | 17px（行高 1.65） | 內文、區塊說明、圖說 |
| `--text-note` | 15px | 表下註記、涵蓋的日子、手機的表格格子 |
| `--text-table` | 16px | 表格格子（640px 以上） |
| `--text-label` | 14px | 表頭（640px 以上）、折返方式標籤、圖上的字 |
| `--text-label-sm` | 13px | 手機的表頭、樣本少標籤、圖的刻度、顯名聲明 footer |
| `--text-subsection` | 20px | 區塊內的小標題（去程、返程、重疊路段） |
| `--text-section` | 26px | 區塊標題（640px 以上） |
| `--text-section-sm` | 23px | 區塊標題（手機） |
| `--text-page` | 40px | 路線名、首頁標題（640px 以上） |
| `--text-page-sm` | 30px | 路線名、首頁標題（手機） |
| `--text-stat` | 60px | 摘要的趟次數字（640px 以上） |
| `--text-stat-sm` | 44px | 摘要的趟次數字（手機） |

手機與桌機的分界用 Tailwind 的 `sm`（640px）。SVG 裡的文字也用這些 class：SVG 文字的 px 是使用者座標單位，實際大小等於字級乘上 SVG 的縮放比例。

理由：使用者的意見是整體字太小，集中定義才改得乾淨，`02-route-page-mobile-first` 也用同一套。

替代方案：每個元件各自改任意值（否決：十幾個元件各寫一份，下一次調整又要全改一遍）。

### 路線頁的底色經由 layout 的 body class 帶到 footer

`app/views/layouts/application.html.erb` 的 `<body>` 加 `class="<%= content_for(:body_class) %>"`，`app/views/routes/show.html.erb` 設 `content_for :body_class, "bg-slate-50"`。首頁不設，維持白底。

理由：顯名聲明 footer 是 layout 在 `yield` 之後輸出的，只在 `main` 上設底色，footer 會留在白底上，接縫很明顯。首頁的插圖 WebP 是配白底畫的，底色不能跟著換。

替代方案：整站改 slate-50 底（否決：首頁插圖會出現白色方框）；路線頁維持白底只靠卡片外框區分（否決：卡片在白底上幾乎看不出邊界，設計稿就是用 slate-50 底襯白卡）。

### 頁面最寬 1152px，首頁、路線頁與 footer 同一組寬度

路線頁與首頁的 `main`、`AttributionComponent` 的 footer 改用 `app/frontend/stylesheets/application.css` 裡新增的 `.page-column`（components 層，內容是 `mx-auto max-w-6xl px-4 sm:px-8`）：最寬 1152px，640px 以上左右內距 32px，手機維持 16px。三處用同一個定義，卡片與 footer 的左右邊界對齊，首頁與路線頁之間切換時版面不會跳。

Supersedes：Design Source 的「`main` 最寬 1080px」，以及 tasks 6.1 記下的「`main` 維持 `max-w-5xl`」。2026-10-23 apply 之後使用者要求加寬，在 1080px（設計稿）、1152px、1080px 但左右內距維持 16px 三個選項中選了 1152px，並選擇首頁一起改。

換算（還沒在瀏覽器量，由 tasks 7.1 實測）：桌機內容 1088px（原 992px），卡片內容約 1006px（原 910px）；沿線人數圖縮放約 1.20，圖上的字約 16.8px（原約 15.2px）；分佈圖最寬仍是 340px，字約 15.9px 不變。

理由：1080px 只比原本多 24px 內容寬，看不太出來；超過約 1150px，沿線人數圖的字會接近 18px，回到「沿線人數圖改成 840 寬的 viewBox，手機上最小 720px 寬」想避開的大小。footer 由 layout 在頁面之後輸出、兩頁共用，跟兩頁的 `main` 用同一個定義才對得齊。

替代方案：

- 1080px（設計稿）：否決，內容只多 24px。
- 只加寬路線頁：否決，footer 得依頁面換寬度，要多一個由頁面告訴 layout 寬度的機制，兩頁之間切換時版面也會跳。
- 三處各自改成 `max-w-6xl px-4 sm:px-8`：否決，三個檔案裡的同一串 class 沒有東西綁在一起，下次改寬度漏改一處就對不齊。
- 比 1152px 更寬：否決，沿線人數圖的字會接近或超過 18px，得另外限制圖寬。

### 卡片外框放在 show.html.erb 的包裝層（CardComponent），區塊元件不帶外框

新增 `CardComponent`（`bin/rails g view_component:component Card` 產生），收一個內容 block 與選用的 `id:`，輸出白底、slate-200 外框、圓角 16px、內距手機 24px 20px、640px 以上 36px 40px 的 `div`，不帶 `data-section`。`app/views/routes/show.html.erb` 用它包住每個區塊元件；頂部那張卡包住 `RouteCoverageComponent` 與 `RouteSummaryComponent`。區塊元件本身只管內部的字級與排版，最外層的 `section[data-section]` 不帶外框、底色與內距。

理由：`02-route-page-mobile-first` 要把同一個指標的圖與表放進同一張卡（分佈圖＋折返停留表、沿線人數圖＋捷運重疊＋逐站表）。外框在包裝層，下一個 change 只要把兩個元件放進同一個 `CardComponent`，不用回頭拆元件的 class。

替代方案：每個區塊元件的最外層 `section` 自己帶卡片 class（否決：下一個 change 合併時要把外框從元件拿掉，元件也就不能在別處重用）；`show.html.erb` 直接寫一長串 Tailwind class（否決：八個地方重複同一串 class）。

### 分佈圖改成一張 300 寬的 SVG，手機與桌機共用

`LayoverChartComponent` 的常數改成 `WIDTH = 300`、`LABEL_WIDTH = 40`、`BAR_MAX = 190`、`ROW = 30`、`BAR_HEIGHT = 18`，長條從 x = 48 開始，文字 `text-label`（14），分隔線的字 `text-label-sm`（13）。SVG 是 `w-full max-w-[340px]`。每根長條後面加一條同長度 `BAR_MAX` 的淺色底軌（slate-100），筆數為 0 的組也看得出刻度。

換算：390px 寬的手機內容區 318px（`main` 左右 16px、卡片左右 20px），縮放 1.06，字約 14.8px；375px 寬時內容區 303px，字約 14.1px；桌機最寬 340px，字約 15.9px。都是換算值，由新的系統測試在 390px 寬時實際量。

這延續 `route-page-charts` 的決定「圖由伺服器輸出成內嵌 SVG，不用圖表套件」：仍然是伺服器輸出的 SVG、`data-bin`、`data-count` 與長條的 `width` 照舊，元件測試不用改。改的只是那個決定裡「`viewBox` 加 `width: 100%`，手機寬度會跟著縮放」的尺寸，不推翻它。

替代方案：

- 桌機與手機各一張 SVG，用 CSS 切換（否決：`data-bin` 會出現兩份，`spec/components/layover_chart_component_spec.rb` 數長條的測試會數到 12 根；DOM 也多一份）。
- 改用 HTML 長條（否決：離開 SVG 的決定，長條的 `width` 屬性測試要重寫，而一張窄 SVG 已經達到目標）。

設計稿桌機版的分佈圖畫的是 460 寬；實作用 300 寬，桌機上的長條比稿短，這是刻意的取捨。

### 沿線人數圖改成 840 寬的 viewBox，手機上最小 720px 寬

`LoadChartComponent` 的常數改成 `WIDTH = 840`、`HEIGHT = 250`、`LEFT = 40`、`RIGHT = 16`、`TOP = 30`、`BOTTOM = 36`；站名、底色帶標題 `text-label`（14），刻度與「人」`text-label-sm`（13）。SVG 是 `w-full min-w-[720px]`，外層仍是 `overflow-x-auto`，再包一層 `relative`，右緣疊一條 36px 的白色漸層提示還有內容。

換算：桌機卡片內容約 1006px（頁面最寬 1152px，見「頁面最寬 1152px，首頁、路線頁與 footer 同一組寬度」；原本照設計稿的 1080px 算是 936px、字約 15.6px），縮放約 1.20，字約 16.8px；手機 720px 寬，縮放 0.86，字約 12px。

理由：維持 720 的 viewBox，桌機上字會被放大到約 19.6px（卡片內容 1006px 時）；改成 960，手機要 823px 寬才能讓字到 12px。840 是兩邊的折衷。手機上要更大的字，等 `02-route-page-mobile-first` 改成每站一列的長條。

### 樣本少：整列 slate-500，趟數旁加標籤

樣本少的列從 `text-slate-400` 改成 `text-slate-500`，趟數格的 `（樣本少）` 改成標籤：`text-label-sm`、slate-100 底、slate-600 字、圓角 5px。`tr[data-small-sample]` 與門檻 5 都不變，照 `zhongshan-route-page` 的決定「樣本少的格子用趟數門檻標出來」。p85 那一欄（表頭與格子）`font-semibold`、slate-900。

對比（依 Tailwind v3 色碼換算）：slate-400 在白底 2.56:1，slate-500 4.76:1。Tailwind v4 的色值是 oklch，apply 時用瀏覽器的 DevTools 實際量一次。

### 折返方式改成標籤，兩種同一個樣式

折返停留表與分佈圖圖說的「停車」「開過去就走」都改成同一個標籤樣式：`text-label`、slate-300 外框、slate-50 底、slate-700 字、圓角 6px。`app/components/layover_chart_component.yml` 的 `stops_html` 拿掉 `%{nature}` 兩側的括號，tw、zh-TW、en 三份一起改；`data-end-nature` 照舊。

理由：照 `zhongshan-turnaround-ends` 的決定「頁面上每一端標出性質：文案用「停車」與「開過去就走」，程式用 stop 與 pass_through」，不用顏色、不標合不合規，所以兩種標籤長得一樣，只有字不同。

### 載客剖面表依方向分組

`LoadProfileTableComponent` 每個方向輸出一個 `<tbody data-direction="0|1">`，第一列是 `<th scope="rowgroup" colspan="6">` 寫「去程」或「返程」，之後每站一列：站序、站名、四個時段。表頭拿掉「方向」欄。每格拆成三段：中位數 `font-semibold` slate-900、` / p90` slate-600、`（趟數）` `text-label` slate-500；`text.squish` 之後仍是 `12.0 / 18.4（3）`。

`spec/components/load_profile_table_component_spec.rb` 跟著改：方向從每列的第一格移到分組標題列。

### 資料限制的卡片樣式只給路線頁

`DataLimitationsComponent` 已經依 `scope:` 選標題與條目（`KEYS`）；樣式也依 scope 分：`:route` 不帶上框線與上邊距，由 `show.html.erb` 包進 `CardComponent`，`:home` 維持現在的上框線樣式，只放大字級。`data-section="limitations"` 照舊。

### 分段按鈕與小標籤

- 範圍切換：`nav[data-range]` 照舊，兩個連結做成分段按鈕，選中的那個加 `aria-current="true"`。手機上兩個按鈕平分寬度、高度至少 44px。
- 時段切換：Alpine 的 `x-on:click`、`x-bind:aria-pressed`、`x-cloak` 照舊，只換 `x-bind:class` 裡的兩組 class。手機上四個按鈕平分寬度、高度至少 44px。
- 涵蓋的日子：`[data-covered-days] [data-day]` 照舊，每一天是一個圓角小標籤。
- `day-types` archive 之後，頁首多了日型別（平日或假日）、每天的日曆備註（例如「補假」）與另一種日型別最近一天的連結，「沒有分平日與假日」那句不再出現。排法：日型別放在涵蓋的日子前面，用同一個小標籤樣式，所以 `app/components/route_coverage_component.yml` 的 `covered` 拿掉 `（%{day_type}）`、只寫「涵蓋的日子」（en: Days covered），後面的冒號也拿掉，日型別由 `day_type_label` 另外輸出（2026-10-23 apply 時與使用者確認）；備註接在那一天的標籤裡；另一種日型別的連結放在標籤列的最後，teal-700 文字連結、有底線。設計稿上那句「沒有分平日與假日。」與資料限制裡的同一條，是 `day-types` 之前的內容，照 archive 後的文案顯示。

### 用系統測試量實際顯示的大小

新增 `spec/system/route_page_layout_spec.rb`（`:js`、`:duckdb`），用 `RouteDayLoader` 寫入 fixture 的 9001 台北日 2026-10-19，視窗設成 390×844 後打開路線頁，用 `evaluate_script` 量。視窗用 CDP 的 `Emulation.setDeviceMetricsOverride`（`mobile: true`）模擬：headless Chrome 的視窗最小寬度是 500px，`resize_to(390, 844)` 實測頁面寬 500（2026-10-23 apply 時實測）。量的項目：

- `document.documentElement.scrollWidth` 不大於 390（頁面本身不橫向捲動）。
- `main` 的計算字級是 17px。
- 分佈圖每個組別標籤的實際大小（計算字級乘上 SVG 寬度除以 viewBox 寬度）不小於 14px。
- 折返停留表、載客剖面表、沿線人數圖的 SVG 各自在 `overflow-x` 為 `auto` 的框裡。
- 範圍切換的每個連結高度不小於 44px。

理由：這個 change 的目標都是畫面上的大小，只有在真的瀏覽器裡量才算數；元件測試看不到 CSS。

## Design Source

- 來源：Claude Design 畫布「路線頁改版方向」https://claude.ai/artifact/CmriGZNTTWaGtCyeMhryDK，畫板「A 視覺整理・桌機」（1280 寬）與「A 視覺整理・手機」（390 寬）。數字是中山幹線 2026-10-19 到 21 的實際值。
- 快取：`.spectra/design-cache/01-route-page-visual-refresh/A-Desktop.dc.html`、`.spectra/design-cache/01-route-page-visual-refresh/A-Phone.dc.html`（`.spectra/` 在 `.gitignore` 裡，只存在本機）。
- 字型：拉丁字與數字 Barlow 400/500/600（`font-route`），數字大字 Barlow Semi Condensed 500/600（`font-route-figure`），中文 Noto Sans TC 400/500/700；數字一律 tabular-nums。
- 顏色（稿上的 hex，對應 Tailwind class）：頁面底 `#f8fafc` slate-50；卡片 `#ffffff`；外框 `#e2e8f0` slate-200；表格列線 `#f1f5f9` slate-100；標籤外框 `#cbd5e1` slate-300；內文 `#1e293b` slate-800；標題 `#0f172a` slate-900；說明 `#475569` slate-600；註記與表頭 `#64748b` slate-500；資料色 `#0f766e` teal-700；小標題與站名強調 `#115e59` teal-800；捷運底色帶 `#e0f2fe` sky-100、標題 `#075985` sky-800；分隔線與基線 `#94a3b8` slate-400；選中的分段陰影 `0 1px 2px rgba(15, 23, 42, 0.14)`。
- 圓角：卡片 16px；分段按鈕外框 10px、單一按鈕 8px；試算的滑桿區 12px；折返方式標籤 6px；樣本少標籤 5px；涵蓋的日子 999px；長條 3px。
- 間距（640px 以上）：`main` 最寬 1080px（實作改成 1152px，見「頁面最寬 1152px，首頁、路線頁與 footer 同一組寬度」）、上 40px 左右 32px；卡片之間 24px；卡片內距 36px 40px；頂部卡片內兩欄間距 48px；表格格子 10px 12px；區塊標題下 8px、說明下 24 到 28px。
- 間距（手機）：`main` 上 20px 左右 16px；卡片之間 16px；卡片內距 24px 20px；表格格子 8px 6px；頂部卡片的趟次摘要改到下方，上面一條 slate-100 分隔線。
- 字級：見上面「字級集中定義在 application.css 的 @theme」的表。分段按鈕 16px，選中 600、其他 500。
- 圖示：無。

## Implementation Contract

完成時可以觀察到：

- 路線頁與首頁的 `main` 計算字級 17px；路線頁的區塊標題 640px 以上 26px、手機 23px；表格格子 640px 以上 16px、手機 15px。
- 390×844 的視窗打開 fixture 的路線頁：頁面不橫向捲動；分佈圖的組別標籤實際顯示不小於 14px；折返停留表、載客剖面表、沿線人數圖在各自可橫向捲動的框裡；範圍切換的連結高度不小於 44px。這幾條由 `spec/system/route_page_layout_spec.rb` 驗證。
- 樣本少的列文字是 slate-500，趟數旁有「樣本少」標籤；`tr[data-small-sample]` 照舊。
- 載客剖面表每個方向一個 `tbody[data-direction]`，分組標題列寫方向；每格文字仍是「中位數 / p90（趟數）」。
- `spec/requests/routes_spec.rb` 的區塊順序 `summary layover-chart load-chart run-times layovers buffer-trade mrt-overlap load-profile limitations` 不變；`spec/requests/pages_spec.rb` 的首頁區塊順序不變；`spec/requests/site_layout_spec.rb` 的 footer 斷言不變。
- 除了 `spec/components/load_profile_table_component_spec.rb`，既有的例子不改就要綠；`spec/components/run_time_table_component_spec.rb`、`spec/components/route_coverage_component_spec.rb`、`spec/requests/site_layout_spec.rb` 另外加新例子。
- 640px 以上，路線頁與首頁的 `main` 與顯名聲明 footer 最寬 1152px、左右內距 32px，三者左右邊界對齊；手機左右內距 16px；兩頁在 640px 寬時不橫向捲動。由 tasks 7.1 在瀏覽器量。

範圍內：上面列的樣式、字級、`CardComponent`、兩張圖的尺寸常數、載客剖面表的分組、`stops_html` 的括號、layout 的 body class、頁面寬度（`.page-column`）、新的系統測試。

範圍外：任何 `app/models/` 與 `analysis/` 的程式、衍生表、路由與控制器、區塊順序、`data-*` 屬性的名稱與值、首頁除了頁面寬度以外的版面與插圖。

能力層級的可觀察行為不變：頁面呈現的區塊、順序、數字與定義，和改版前一樣。

## Risks / Trade-offs

- [Tailwind v4 的色值是 oklch，4.76:1 是用 v3 的 hex 換算的] → apply 時用 DevTools 量 slate-500 對白底的實際對比，低於 4.5:1 就改用 slate-600。
- [一張 300 寬的分佈圖在桌機上比設計稿窄] → 接受；換來一份 DOM、測試不用改，桌機最寬 340px、字約 15.9px。
- [沿線人數圖在手機上的字只有約 12px，仍要橫向捲] → 這個 change 只處理到這裡，`02-route-page-mobile-first` 改成每站一列的長條。
- [系統測試要 headless Chrome 與 `yarn build`，跑得比元件測試慢] → 只開一個測試檔、一次載入 fixture，量的項目都在同一頁。
- [首頁字級變大，hero 標題在窄手機上可能換行] → 標題用 `text-page-sm`（30px），跟路線名同一級；apply 時在 375px 寬看一次。
- [頁面加寬到 1152px，沿線人數圖在桌機上的字約 16.8px（換算），比照設計稿 1080px 算的 15.6px 大] → 7.1 在 1280 寬實測；超過 18px 就停下來，回頭限制圖寬或調整 viewBox。
- [640px 以上左右內距從 16px 加到 32px，640 到 1023px 寬的內容反而少 32px] → 7.1 在 640 寬確認兩頁都不橫向捲動。

## Migration Plan

沒有資料或設定要遷移，照一般部署；要撤回就 revert 這個 change 的 commit。

## Open Questions

（無）
