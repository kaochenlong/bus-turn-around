<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
design 決定的標題原文照抄，分析器靠字串比對。
這是 no-spec 的 change：區塊、順序、數字、data-* 屬性都不動，既有的 request 與元件測試除了載客剖面表那一則，不改就要綠。
對照的設計稿在 .spectra/design-cache/01-route-page-visual-refresh/（A-Desktop.dc.html、A-Phone.dc.html），數值見 design 的 Design Source。
開工前提：`day-types` 已 archive（它改頁首的涵蓋內容、資料限制的條目、ApplicationComponent 與多數元件測試的資料建法）。開工前跑 `/spectra-drift 01-route-page-visual-refresh`，確認下面提到的檔案、方法與測試例子還在。
-->

## 1. 量測與字級

- [x] 1.1 先寫會失敗的手機量測，套用 design「用系統測試量實際顯示的大小」：新增 `spec/system/route_page_layout_spec.rb`（`type: :system`、`:js`、`:duckdb`），用 `RouteDayLoader` 寫入 fixture 的 9001 台北日 2026-10-19，用 CDP 的 `Emulation.setDeviceMetricsOverride`（`width: 390`、`height: 844`、`deviceScaleFactor: 1`、`mobile: true`）把視窗模擬成 390×844 後打開 `route_path(9001, day: "2026-10-19")`，例子結束時用 `Emulation.clearDeviceMetricsOverride` 清掉（瀏覽器在例子之間共用）。不用 `resize_to(390, 844)`：headless Chrome 的視窗最小寬度是 500px，實測頁面寬 500；`mobile: true` 的捲軸不佔寬度，跟手機一樣，`mobile: false` 時捲軸會吃掉 15px。
  - 行為：五個例子各量一件事：`document.documentElement.scrollWidth` 不大於 390；`main` 的計算字級是 `17px`；分佈圖第一個組別標籤的實際大小（`getComputedStyle(text).fontSize` 乘上 SVG 的 `getBoundingClientRect().width` 除以 `viewBox.baseVal.width`）不小於 14；折返停留表、載客剖面表、沿線人數圖的 SVG 各自有一個祖先的 `overflow-x` 是 `auto`；`nav[data-range] a` 每個高度不小於 44。
  - 驗證：`bundle exec rspec spec/system/route_page_layout_spec.rb` 在改版前跑一次，字級、組別標籤、捲動框、按鈕高度那幾個例子失敗（這是預期的，代表測試量得到現況）；把當下量到的值記在這條任務下面。`bin/rubocop spec/system/route_page_layout_spec.rb`。
  - 改版前量到（2026-10-23，390×844、`mobile: true`）：`scrollWidth` 390（這個例子通過）；`main` 15px；分佈圖第一個組別標籤 9.34px（12px × 358 ÷ 460）；捲動框：折返停留表沒有，載客剖面表與沿線人數圖有；範圍切換兩個連結各 28px。`scrollWidth` 那個例子一開始就綠，另外做了反向驗證：暫時拿掉沿線人數圖外層的 `overflow-x-auto`，`scrollWidth` 變成 616、例子失敗，還原後轉綠。
- [x] 1.2 實作 design「字級集中定義在 application.css 的 @theme，路線頁與首頁共用」：`app/frontend/stylesheets/application.css` 的 `@theme` 加 design 表上的 12 個字級 token；`app/views/routes/show.html.erb` 與 `app/views/pages/home.html.erb` 的 `main` 從 `text-[15px]` 改成 `text-body`；`AttributionComponent` 的 footer 從 `text-xs` 改成 `text-label-sm`。[after: 1.1]
  - 行為：路線頁與首頁的 `main` 計算字級 17px，顯名聲明 footer 13px；其他元件還沒換 token，畫面只有內文變大。
  - 驗證：`spec/system/route_page_layout_spec.rb` 的「`main` 17px」例子轉綠；`bundle exec rspec spec/requests/pages_spec.rb spec/requests/site_layout_spec.rb spec/requests/routes_spec.rb` 不改仍綠；`yarn build` 成功，產出的 CSS 裡有 `.text-body`。
- [x] 1.3 實作 design「路線頁的底色經由 layout 的 body class 帶到 footer」：`app/views/layouts/application.html.erb` 的 `<body>` 讀 `content_for(:body_class)`，`app/views/routes/show.html.erb` 設成 `bg-slate-50`。[after: 1.2]
  - 行為：路線頁的 `<body>` 有 `bg-slate-50`，顯名聲明 footer 跟頁面同一個底色；首頁的 `<body>` 沒有底色 class。
  - 驗證：`spec/requests/site_layout_spec.rb` 加一個例子：`GET /routes/9001`（沒有資料也可以）的 `body` class 含 `bg-slate-50`，`GET /` 的 `body` class 不含。`bin/rubocop spec/requests/site_layout_spec.rb`。

## 2. 頂部與卡片

- [x] 2.1 實作 design「卡片外框放在 show.html.erb 的包裝層（CardComponent），區塊元件不帶外框」與頂部那張卡：用 `bin/rails g view_component:component Card` 產生 `CardComponent`（收內容 block 與選用的 `id:`）；`app/views/routes/show.html.erb` 用一個 `CardComponent` 包住 `RouteCoverageComponent` 與 `RouteSummaryComponent`，640px 以上兩欄（趟次摘要靠右），手機上趟次摘要在下方。同時套用 design「分段按鈕與小標籤」：`RouteCoverageComponent` 的路線名用 `text-page-sm sm:text-page`，範圍切換改成分段按鈕、選中的連結加 `aria-current="true"`，涵蓋的日子每一天一個圓角小標籤；`app/components/route_coverage_component.yml` 的 `covered` 拆成只寫「涵蓋的日子」（en: Days covered），日型別另外做成同樣的標籤；`RouteSummaryComponent` 的數字用 `text-stat-sm sm:text-stat`。[after: 1.3]
  - 行為：頂部一張卡收齊路線名、起迄、範圍切換、涵蓋的日子（含 `day-types` 加上的日型別、日曆備註與另一種日型別的連結，排法見 design「分段按鈕與小標籤」）與趟次；`nav[data-range]`、`[data-covered-days] [data-day]`、`[data-trips]`、`[data-complete-trips]` 與 `section[data-section=summary]` 都照舊；選中的範圍連結有 `aria-current="true"`；沒有資料的日子，黃色提示框照舊出現在卡裡；`CardComponent` 輸出的 `div` 沒有 `data-section`。
  - 驗證：新增 `spec/components/card_component_spec.rb`（`type: :component`）：內容出現在帶指定 `id` 的 `div` 裡，`div` 沒有 `data-section`。`spec/components/route_coverage_component_spec.rb` 加一個例子：`range: "7d"` 時只有「最近 7 天」那個連結帶 `aria-current="true"`。`spec/components/route_summary_component_spec.rb`、`spec/requests/routes_spec.rb` 不改仍綠；`spec/system/route_page_layout_spec.rb` 的按鈕高度例子轉綠。
- [x] 2.2 其他區塊各包一個 `CardComponent`：`app/views/routes/show.html.erb` 把分佈圖、沿線人數圖、行駛時間、折返停留表、換休息試算、捷運重疊、載客剖面表各包進一個 `CardComponent`，區塊間距手機 16px、640px 以上 24px；這些元件最外層 `section` 拿掉 `mb-10` 這類外距，區塊標題改 `text-section-sm sm:text-section`，說明 `text-body` slate-600，小標題 `text-subsection` teal-800。[after: 2.1]
  - 行為：路線頁每個區塊是一張卡，`data-section` 與順序不變；`BufferTradeComponent` 外層的 `turbo-frame#buffer-trade` 照舊，卡片外框在 frame 外面，拉滑桿仍只換這一塊。
  - 驗證：`spec/requests/routes_spec.rb` 的區塊順序例子與 `spec/components/buffer_trade_component_spec.rb` 不改仍綠；`bin/dev` 開 `/routes/15373?range=7d`，在 1280 與 390 寬對照 `.spectra/design-cache/01-route-page-visual-refresh/` 的兩張稿。
  - 對照時調整：`[data-covered-days]` 的 `ul` 改成 `display: contents`，每一天的標籤跟「涵蓋的日子」、日型別在同一列接著排；原本整串日子會被擠到下一行。另在開發伺服器實測拉滑桿：只換 turbo-frame（window 上的記號還在），網址帶上新的 `buffer`。

## 3. 表格

- [x] 3.1 實作 design「樣本少：整列 slate-500，趟數旁加標籤」：`RunTimeTableComponent` 的樣本少列改成 `text-slate-500`，`（樣本少）` 改成標籤；p85 的表頭與格子 `font-semibold` slate-900；表格格子手機 `text-note`、640px 以上 `text-table`，表頭 `text-label-sm sm:text-label`，格子加內距與 slate-100 列線。[after: 2.2]
  - 行為：樣本少的列字是 slate-500，趟數後面有「樣本少」標籤，`tr[data-small-sample]` 照舊；非樣本少的列沒有標籤。
  - 驗證：`spec/components/run_time_table_component_spec.rb` 加一個例子：`tr[data-small-sample]` 的文字含「樣本少」，沒有 `data-small-sample` 的列不含；既有三個例子不改仍綠。apply 時用 DevTools 量 slate-500 對白底的對比，結果記在這條任務下面，低於 4.5:1 就改用 slate-600。
  - 對比實測（2026-10-23，headless Chrome，`/routes/15373?range=7d`）：樣本少那一列格子的計算顏色 `oklch(0.554 0.046 257.417)`，canvas 畫出 rgb(98, 116, 142)，對卡片白底 4.76:1，高於 4.5:1，維持 slate-500（slate-600 量到 7.58:1）。新例子在改版前的標記上就通過，另做反向驗證：讓每一列都輸出標籤，新例子與既有的格子例子都失敗，還原後轉綠。表格的格子樣式定義在 `application.css` 的 `.data-table`（components 層），3.2、3.3 的表格共用；行駛時間表兩欄改在 `lg` 才並排（字放大後一張表約 367px 寬，`md` 時每欄只有約 303px）。
- [x] 3.2 實作 design「折返方式改成標籤，兩種同一個樣式」的表格那一半，並整理折返停留表、試算表、捷運重疊表的樣式：`LayoverTableComponent` 的折返方式改成標籤，整張表包進可以橫向捲動的框（`overflow-x-auto`、表格最小寬 660px、右緣 36px 的白色漸層，漸層 `aria-hidden`）；`BufferTradeComponent` 的滑桿區改成 slate-50 底、圓角 12px 的面板；`MrtOverlapComponent` 的表格套用跟行駛時間表一樣的格子樣式，500 公尺那欄維持 `font-semibold`。[after: 2.2]
  - 行為：「停車」「開過去就走」兩個標籤長得一樣、只有字不同；`tr[data-direction][data-end-nature]` 照舊；手機上折返停留表在自己的框裡橫向捲動，頁面本身不捲。
  - 驗證：`spec/components/layover_table_component_spec.rb`、`spec/components/buffer_trade_component_spec.rb`、`spec/components/mrt_overlap_component_spec.rb` 不改仍綠（格子文字仍是「開過去就走」「停車」）；`spec/system/route_page_layout_spec.rb` 的捲動框例子轉綠（沿線人數圖與載客剖面表原本就在 `overflow-x-auto` 裡，缺的是折返停留表）。
- [x] 3.3 實作 design「載客剖面表依方向分組」：先改 `spec/components/load_profile_table_component_spec.rb`，再改 `LoadProfileTableComponent`。每個方向一個 `tbody[data-direction]`，第一列 `th[scope=rowgroup]` 寫方向，之後每站一列：站序、站名、四個時段；表頭拿掉「方向」；每格拆成中位數、` / p90`、`（趟數）` 三段；整張表包進可以橫向捲動的框（最小寬 680px、右緣漸層）。[after: 2.2]
  - 行為：載客剖面表依方向分組，每格文字 `squish` 之後仍是「中位數 / p90（趟數）」；手機上表在自己的框裡捲。
  - 驗證：改寫後的元件測試斷言 `tbody[data-direction='0'] th` 的文字是「去程」，同一個 `tbody` 裡那一站的格子是 `[ "3", "丁站", "12.0 / 18.4（3）", "—", "—", "—" ]`；改測試後、改元件前跑一次，確認新測試失敗。`spec/requests/route_page_fixture_spec.rb` 不改仍綠；`spec/system/route_page_layout_spec.rb` 的捲動框例子保持綠。
  - 表頭拿掉「方向」後，`app/components/load_profile_table_component.yml` 的 `direction`（tw、en）沒有人用，一併刪掉。

## 4. 兩張圖

- [x] 4.1 實作 design「分佈圖改成一張 300 寬的 SVG，手機與桌機共用」與「折返方式改成標籤，兩種同一個樣式」的圖說那一半：`LayoverChartComponent` 換成 design 的常數，每組加一條長 `BAR_MAX` 的 slate-100 底軌，文字 `text-label`、分隔線的字 `text-label-sm`，SVG `w-full max-w-[340px]`；`app/components/layover_chart_component.yml` 的 `stops_html` 在 tw、zh-TW、en 拿掉 `%{nature}` 兩側的括號，性質改成標籤。[after: 2.2]
  - 行為：分佈圖的 viewBox 是 `0 0 300 184`；`data-bin`、`data-count`、長條的 `width`、`data-divider`、`figcaption[data-end-nature]` 照舊，長條長度仍按同一個方向的最大筆數比例；圖說寫成「…出發」後面接一個性質標籤，不再有括號。
  - 驗證：`spec/components/layover_chart_component_spec.rb` 不改仍綠；`spec/system/route_page_layout_spec.rb` 的組別標籤不小於 14 的例子轉綠。
  - 實測（2026-10-23，`/routes/15373?range=7d`）：組別標籤 375 寬 14.05px、390 寬 14.75px、1280 寬 15.87px，viewBox `0 0 300 184`。兩張圖並排從 `md` 改到 `lg`：`md`（768 寬）時每張圖只剩約 296px，字掉到 13.79px，改成 `lg` 後 768 寬是單欄，字 15.87px。
- [x] 4.2 實作 design「沿線人數圖改成 840 寬的 viewBox，手機上最小 720px 寬」：`LoadChartComponent` 換成 design 的常數，站名與底色帶標題 `text-label`、刻度與「人」`text-label-sm`，SVG `w-full min-w-[720px]`，外層 `overflow-x-auto` 外再包 `relative` 並疊右緣漸層；時段切換套用 design「分段按鈕與小標籤」，只換 `x-bind:class` 的兩組 class，手機上四個按鈕平分寬度、高度至少 44px。[after: 2.2]
  - 行為：沿線人數圖的 viewBox 是 `0 0 840 250`；`data-band`、`data-seq`、`data-median`、`data-segment`、`data-scale-top`、`data-span-from` 與 `x-cloak` 照舊；切換時段仍不重新載入頁面。
  - 驗證：`spec/components/load_chart_component_spec.rb` 不改仍綠；`spec/system/route_page_layout_spec.rb` 的捲動框例子保持綠；`bin/dev` 開頁面點四個時段，線跟著換。

## 5. 資料限制、footer 與首頁

- [x] 5.1 實作 design「資料限制的卡片樣式只給路線頁」：`DataLimitationsComponent` 依 `scope:` 選樣式，`:route` 不帶上框線與上邊距、標題 `text-subsection`、條目 `text-table`，`:home` 維持上框線樣式、條目 `text-note`；`app/views/routes/show.html.erb` 把資料限制包進一個 `CardComponent`。[after: 2.2]
  - 行為：路線頁的資料限制是一張卡，首頁的資料限制版面不變、字變大；兩邊都還是 `section[data-section=limitations]`，條目文字不變。
  - 驗證：`spec/components/data_limitations_component_spec.rb` 不改仍綠；`spec/requests/pages_spec.rb` 與 `spec/requests/routes_spec.rb` 的區塊順序不變。
  - 樣式由 `scope:` 這個分支選，照 TDD 的分支規則在 `spec/components/data_limitations_component_spec.rb` 加了一個例子：首頁那份帶 `border-t`、路線頁那份不帶（改元件前先跑過，失敗）；既有的例子沒改。
- [x] 5.2 首頁只換字級：`HomeHeroComponent` 的標題 `text-page-sm sm:text-page`；`RouteListComponent` 的標題 `text-section-sm sm:text-section`、卡片上的路線名 `text-subsection`、最新資料日與清單下的說明 `text-note`；`DataSourcesComponent` 的內文 `text-note`。版面、插圖、文案不動。[after: 1.2]
  - 行為：首頁的字級跟路線頁同一套；區塊、順序、插圖與動畫行為不變。
  - 驗證：`spec/requests/pages_spec.rb`、`spec/components/home_hero_component_spec.rb`、`spec/components/route_list_component_spec.rb`、`spec/components/data_sources_component_spec.rb`、`spec/system/home_hero_spec.rb` 不改仍綠；`bin/dev` 在 375 寬看首頁標題，換行不超過兩行。

## 6. 收尾

- [x] 6.1 全部跑一次：`bin/rubocop` 對這個 change 新增或修改的檔案，`bin/rails parallel:spec` 全綠（含 `spec/system/route_page_layout_spec.rb` 五個例子）；`bin/dev` 開 `/routes/15373?range=7d` 與 `/`，在 1280 與 390 寬各對照一次 `.spectra/design-cache/01-route-page-visual-refresh/` 的兩張稿，差異記在這條任務下面（分佈圖在桌機上比稿窄是 design 裡說好的取捨）。[after: 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2]
  - 行為：路線頁與首頁照 design 的字級與樣式呈現，區塊、順序、數字跟改版前一樣。
  - 驗證：上面兩個指令的輸出全綠、沒有 RuboCop 警告；對照結果寫在任務下面。
  - 結果（2026-10-23）：`bin/rubocop` 對這個 change 新增或修改的 13 個 Ruby 檔沒有警告；`bin/rails parallel:spec` 474 個例子 0 失敗、0 略過（含 `spec/system/route_page_layout_spec.rb` 五個例子）。
  - Implementation Contract 的字級實測（fixture 的 9001 路線頁，headless Chrome）：390 寬 `main` 17px、區塊標題 23px、表格格子 15px、表頭 13px、路線名 30px、趟次 44px；1280 寬 `main` 17px、區塊標題 26px、格子 16px、表頭 14px、路線名 40px、趟次 60px；兩種寬度的小標題 20px、顯名聲明 footer 13px。首頁 `main` 在 320 到 1280 寬都是 17px，hero 標題 375 寬一行、320 寬兩行。
  - 跟稿的差異（`bin/dev` 開 `/routes/15373?range=7d` 與 `/`，1280 與 390 寬）：
    - 分佈圖桌機最寬 340px，比稿的 460 窄（design 說好的取捨）；沿線人數圖桌機用 840 的 viewBox（稿 960），手機最小 720px 寬（稿是 720 的 viewBox），都照 design 的常數；線寬維持 2（稿 2.5、圓頭）。
    - `main` 維持 `max-w-5xl`（1024px）、左右 16px、上下 32px，沒有照稿改成最寬 1080px、桌機左右 32px：顯名聲明 footer 由 layout 輸出、跟首頁共用同一組寬度，改 `main` 會讓 footer 跟卡片對不齊。
    - 稿上 18px 的字（起迄那行、趟次的「趟」、沿線人數圖的「去程／返程」）都用內文 17px：字級表沒有 18px 的 token；試算滑桿標籤裡放大成 28／30px 的分鐘數也維持標籤的字級。
    - 分段按鈕在桌機也維持至少 44px 高（稿約 42px）；手機版的時段按鈕照稿不帶左右內距，四個字以內放得下一行。
    - 捷運重疊的兩個重疊路段表在稿上桌機左右並排，實作維持上下排（任務沒有要求改這一段的版面）。
    - 資料限制那張卡的內距跟其他卡一樣是 36px 40px（稿 32px 40px）。
    - 右緣的漸層只在框比表格或圖窄、需要捲動時才出現（container query）；稿只畫了手機版，桌機不出現才不會蓋到最右欄。
    - 涵蓋的日子照 `day-types` archive 後的內容排：日型別、每天的標籤、日曆備註與另一種日型別的連結；稿上「沒有分平日與假日。」是 `day-types` 之前的文案。
    - 待決定：分佈圖 10–15 那組剛好是該方向最多、而且筆數有兩位數以上時，筆數會跟右上角「15 分鐘」重疊幾個 px（`BAR_MAX = 190` 加上筆數最右到約 x = 261，「15 分鐘」約從 x = 256 起；稿的手機版也一樣，只是資料沒碰到）。這要改 design 的常數或標籤位置，沒有在這個 change 裡改。

## 7. 頁面寬度

- [x] 7.1 實作 design「頁面最寬 1152px，首頁、路線頁與 footer 同一組寬度」：`app/frontend/stylesheets/application.css` 的 components 層加 `.page-column`（`mx-auto max-w-6xl px-4 sm:px-8`），`app/views/routes/show.html.erb` 與 `app/views/pages/home.html.erb` 的 `main`、`AttributionComponent` 的 footer 拿掉各自的 `mx-auto max-w-5xl px-4`，改用 `.page-column`。取代 6.1 記下的「`main` 維持 `max-w-5xl`」那條差異。[after: 6.1]
  - 行為：640px 以上，兩頁的 `main` 與顯名聲明 footer 最寬 1152px、左右內距 32px，左右邊界對齊；手機上左右內距仍是 16px，`spec/system/route_page_layout_spec.rb` 量的 390 寬數值不變；兩頁在 640px 寬時都不橫向捲動。
  - 驗證：寬度與內距是三處共用的同一個定義、沒有分支，照測試範圍規則不另寫測試，改在瀏覽器量：`bin/dev` 開 `/routes/15373?range=7d` 與 `/`，1280 寬時 `main` 與 `footer[data-attribution]` 的寬度都是 1152px、左緣相同，並量沿線人數圖站名的實際字級（換算約 16.8px，超過 18px 就停下來回頭討論）；640 寬時 `document.documentElement.scrollWidth` 不大於 `clientWidth`；量到的值記在這條任務下面。`yarn build` 產出的 CSS 有 `.page-column`；`bin/rails parallel:spec` 全綠。
  - 結果（2026-10-23，開發伺服器）：`yarn build` 產出 `.page-column{max-width:var(--container-6xl);padding-inline:calc(var(--spacing) * 4);margin-inline:auto}`，640px 以上的 media query 裡 `padding-inline` 是 `calc(var(--spacing) * 8)`，`--container-6xl` 是 72rem。兩頁量到的 `main` 與 footer 完全相同：1280 寬 1152px、左緣都是 57、內距 32px；1440 寬 1152px、左緣都是 137；1024 寬 1009px、內距 32px；640 寬 625px、內距 32px、頁面不橫向捲動；390 寬內距 16px、不橫向捲動。沿線人數圖站名在 1280 與 1440 寬 16.77px（換算 16.8px），1024 寬 14.38px。`bin/rails parallel:spec` 474 個例子 0 失敗、0 略過。測試範圍的排除理由：寬度與內距由同一個 `.page-column` 定義、三處共用、沒有分支，屬於寫死的 class，不另寫測試，以上面的瀏覽器量測確認。
