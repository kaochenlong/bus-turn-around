<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
開工前提：01-route-page-visual-refresh、day-types、layover-other-routes 都已 archive（字級 token 與 CardComponent 都在；頁首已有日型別；折返停留表的說明已改）。開工前跑 `/spectra-drift 02-route-page-mobile-first`，確認下面提到的檔案、方法與測試例子還在。
對照的設計稿在 .spectra/design-cache/02-route-page-mobile-first/（B-Desktop.dc.html、B-Phone.dc.html），數值見 design 的 Design Source。
-->

## 1. 網站名稱列

- [x] 1.1 實作 Site name bar on every page 與 Home page content and order 的修改，套用 design「網站名稱列由 layout 輸出，每頁一條，只放回首頁的連結」：用 `bin/rails g view_component:component SiteBar` 產生 `SiteBarComponent`，`app/views/layouts/application.html.erb` 在 `<body>` 的第一個位置 render 它；`HomeHeroComponent` 拿掉標題上方那行網站名稱。
  - 行為：每一頁 `<body>` 的第一個元素是 `header[data-site-bar]`，裡面一個 `a[href="/"]`，文字是 `t("site.name")`；它與裡面都沒有 `data-section`。首頁 hero 不再有網站名稱，body 裡「折返點 TurnAround」只出現一次。
  - 驗證：`spec/requests/site_layout_spec.rb` 斷言 Scenario「Bar on the home page」與「Bar on a route page」；`spec/requests/pages_spec.rb` 斷言 Scenario「Site name once」（數 body 文字裡的出現次數）；新增 `spec/components/site_bar_component_spec.rb`（連結與文字）；`spec/components/home_hero_component_spec.rb` 加一個例子：hero 的文字不含網站名稱。`spec/requests/pages_spec.rb` 的區塊順序與 `spec/requests/routes_spec.rb` 不改仍綠。`bin/rubocop` 對新增與修改的檔案。
  - 結果（2026-10-23）：三個 request 例子改元件前先跑過，失敗在沒有 `[data-site-bar]`；實作後轉綠，`routes_spec.rb`、`home_hero_component_spec.rb` 不改仍綠。測試範圍的排除理由：`site_bar_component_spec.rb` 與 hero 的那個例子沒有寫。網站名稱列的連結與文字是寫死的內容（沒有輸入、沒有分支），兩支 request 例子已經經過 layout 在首頁與路線頁上量到同一份輸出；hero 不含站名是 hero 與網站名稱列兩個元件之間的約定，由「Site name once」在整頁上數。反向驗證：暫時把站名加回 hero，「Site name once」數到 2 次而失敗，還原後轉綠。產生器建的 pending 佔位 spec 刪掉。

## 2. 區塊重排、重點數字與導覽

- [x] 2.1 實作 Page content 的新順序，套用 design「區塊依指標分組：同一個指標的圖與表放進同一張卡」：先把 `spec/requests/routes_spec.rb` 的區塊順序改成 Scenario「Overlap block in place」的新順序並確認它失敗，再改 `app/views/routes/show.html.erb`：頁首不放卡片；`CardComponent(id: "layovers")` 放分佈圖與折返停留表，`id: "buffer"` 放試算，`id: "runtimes"` 放行駛時間，`id: "load"` 放沿線人數圖、捷運重疊、載客剖面表，`id: "limits"` 放資料限制；同一張卡裡的區塊之間一條分隔線。`MrtOverlapComponent` 的 `section` 加 `id="mrt"`；`CardComponent` 加 `scroll-margin-top`。
  - 行為：`data-section` 依序是 `summary layover-chart layovers buffer-trade run-times load-chart mrt-overlap load-profile limitations`；頁面上有 `#layovers`、`#buffer`、`#runtimes`、`#load`、`#mrt`、`#limits` 六個元素，各自包住對應的區塊。
  - 驗證：改過的 `spec/requests/routes_spec.rb` 轉綠；`spec/requests/route_page_fixture_spec.rb`、`spec/components/card_component_spec.rb` 與各區塊的元件測試不改仍綠。
  - 結果（2026-10-23）：順序例子改完先跑，失敗在舊順序；改 `show.html.erb` 後轉綠，`spec/requests/` 與 `spec/components/` 95 個例子全綠。分隔線在 `show.html.erb` 定義一次（手機上 28px、下 20px，640px 以上上 32px、下 24px），三處共用。`#mrt` 不是卡片，但區塊導覽與重點數字也連過去，跟卡片一樣加 `scroll-mt-20`。頁首只移出卡片，桌機「靠右一欄、日子標籤白底」沒有改（不在這條任務），對照差異記在 5.2。
- [x] 2.2 準備重點數字要用的共用部分，套用 design「重點數字取自表格用的同一批物件與同一個格式」：`RoutePage::LayoverStats#rows` 改成記住結果；`ApplicationComponent` 加 `minutes(value)`（`%.1f`，nil 時「—」）與 `share(value)`（`%.1f%%`，nil 時「—」），`LayoverTableComponent` 與 `MrtOverlapComponent` 改用它們，刪掉各自的同名方法。
  - 行為：同一個 `LayoverStats` 呼叫兩次 `rows` 只查一次資料庫；折返停留表與捷運重疊表的文字不變。
  - 驗證：`spec/models/route_page/layover_stats_spec.rb` 加一個例子：訂閱 `sql.active_record`，連續呼叫兩次 `rows`，對 `layovers` 的 SELECT 恰好一次；`spec/components/layover_table_component_spec.rb`、`spec/components/mrt_overlap_component_spec.rb`、`spec/models/route_page/card_consistency_spec.rb` 不改仍綠。
  - 結果（2026-10-23）：記住結果的例子改前先跑，查了 2 次而失敗，改後轉綠。共用的格式依 TDD 的分支規則在 `spec/components/application_component_spec.rb` 加兩個例子（有值與 nil），改前失敗在方法不存在。兩個方法從元件搬到 `ApplicationComponent` 是在綠燈下重構，反向驗證：暫時把共用的 nil 寫法改成「-」、比例改成兩位小數，折返停留表與捷運重疊表的既有例子各失敗一個，還原後轉綠。同樣的寫法還有三處沒改（不在這條任務列的元件）：`RunTimeTableComponent#minutes`、`BufferTradeComponent#share` 會蓋掉共用的方法，有值時輸出相同；`LoadProfileTableComponent::NONE` 與共用的 `NONE` 同值。
- [x] 2.3 實作 Key numbers in the summary，套用 design「重點數字取自表格用的同一批物件與同一個格式」：`RouteSummaryComponent.new(summary:, layover_stats:, ends:, mrt_overlap:)` 輸出四張卡（趟次、停車端折返停留 p50、停車端不到 15 分鐘、捷運重疊 500 公尺內），掛勾照 design；`app/views/routes/show.html.erb` 只建一個 `RoutePage::LayoverStats`，傳給摘要與 `LayoverTableComponent`；`LayoverTableComponent` 把停車端那一列的 p50 與不到 15 分鐘格子加粗。先寫元件測試再改元件。[after: 2.1, 2.2]
  - 行為：每個停車端一行、帶末站名；沒有停車端時寫「兩端都是開過去就走，沒有停車的一端」；表格是「—」時卡上也是「—」；`needs_reload?` 時捷運重疊是「—」；第 2、3 張卡連到 `#layovers`，第 4 張連到 `#mrt`；`data-trips`、`data-complete-trips` 照舊。
  - 驗證：`spec/components/route_summary_component_spec.rb` 用 `RoutePage::Ends.from_config` 斷言 Scenario「One stopping end」（停車端 10、20、30 分鐘：p50 20.0、不到 15 分鐘 33.3%）、「Both ends stopping」、「No stopping end」、「Stopping end without layovers」、「Distances missing in the summary」、「Key numbers link to their blocks」；`spec/requests/routes_spec.rb` 加一個例子：fixture 的 9001（兩端都停車）每一行 `[data-key-number] [data-end=N]` 的數字文字等於 `tr[data-direction=N]` 對應格子的文字。`spec/requests/route_page_fixture_spec.rb` 不改仍綠，Bullet 不報錯。
  - 結果（2026-10-23）：新例子改元件前先跑，失敗在建構參數與沒有重點數字卡、表格沒有加粗。fixture 的 9001 量到的格子是 p50 13.5／19.0、不到 15 分鐘 60.0%／37.5%、捷運重疊 60.0%／60.0%，相等的比對不是兩邊都「—」。除了點名的 Scenario，照 TDD 的分支規則多測四個分支：p50 是「—」時不帶單位、最新一天沒有站牌時沒有任何一端的行、兩個方向都有距離時的重疊度、最新一天只有去程站牌時返程是「—」；捷運重疊與折返停留表的相等也在 fixture 上比。反向驗證：摘要改拿 p10、表格改成每列都加粗，對應的四個例子失敗，還原後轉綠。`spec/components/`、`spec/requests/`、`spec/models/route_page/` 171 個例子全綠。
  - 測試範圍的排除理由：「Key numbers link to their blocks」不在元件測試裡斷言 `href` 的字面值；連結的 fragment 要對得到另一個檔案（`show.html.erb` 的卡片、`MrtOverlapComponent`）的 `id`，改在 `spec/requests/routes_spec.rb` 比對：每張卡的 fragment 指到的元素包住哪些 `data-section`。
  - 跟 design 的出入：第 3 張卡的說明寫「末站・共 N 筆」，不是文案一節的「共 N 筆」，因為 spec 要求兩個折返停留重點數字的每一行都標出那一端的末站，兩端都停車時才分得出哪一行是哪一端。字級沿用同一套 token：`--text-stat`／`--text-stat-sm` 只有摘要在用，照新稿從 60／44 改成 44／36。一列 4 張卡從 `lg`（1024px）開始，640 到 1023px 是 2×2：640px 寬時一張卡只剩約 120px，放不下「17.2 分鐘」。
- [x] 2.4 實作 Section links，套用 design「區塊導覽只用錨點連結，CSS 讓它停在畫面上方」：用 `bin/rails g view_component:component SectionNav --locale` 產生 `SectionNavComponent`，`app/views/routes/show.html.erb` 只在有資料時把它 render 在摘要後面。[after: 2.3]
  - 行為：`nav[data-section-nav]` 裡六個連結依序指向 `#layovers`、`#buffer`、`#runtimes`、`#load`、`#mrt`、`#limits`，文字是 design 文案一節的六個名稱；`sticky top-0`；沒有 `data-section`；沒有資料的日子不輸出。
  - 驗證：新增 `spec/components/section_nav_component_spec.rb`（六個 `href` 的順序）；`spec/requests/routes_spec.rb` 斷言 Scenario「Links in page order」（每個 fragment 在頁面上都有同 id 的元素，且那個元素包住對應的 `data-section`）與「No links without data」（`?day=2026-10-25` 回 200、沒有 `nav[data-section-nav]`）。
  - 結果（2026-10-23）：「Links in page order」改前先跑，失敗在沒有導覽；「No links without data」一開始就綠（導覽還不存在），實作後做反向驗證：把導覽移到 `if @coverage.data?` 外面，它失敗，還原後轉綠。`spec/requests/` 與 `spec/components/` 112 個例子全綠；`.yml` 的 tw 與 en 鍵相同。測試範圍的排除理由：`section_nav_component_spec.rb` 沒有寫，六個 `href` 與順序是寫死的字面值，要對得到的是另一個檔案的 `id` 與頁面上的區塊順序，這件事由 request 層的「Links in page order」比對（每個 fragment 指到的元素包住哪些 `data-section`，依序）。產生器建的 pending 佔位 spec 刪掉。
  - 跟稿的出入：640px 以上也不換行，放不下時跟手機一樣橫向捲動；640 到約 710px 寬時六個連結一列放不下，換成兩列會讓導覽變高，卡片的 `scroll-mt-20` 就讓不出位置。鍵盤焦點的外框畫在連結內側，不會被可以捲動的導覽切掉。

## 3. 卡片裡的內容

- [x] 3.1 實作 Page content 的逐站表收合，套用 design「逐站表收進預設關閉的 details」：`LoadProfileTableComponent` 在 `section[data-section=load-profile]` 裡放一個不帶 `open` 的 `details[data-load-profile]`，`summary` 寫「逐站數字：載客剖面表」與站列數，表格放在裡面。[after: 2.4]
  - 行為：逐站表預設收起，點標題列展開；每一站的列都在伺服器輸出裡；收合列寫出站列數。
  - 驗證：`spec/components/load_profile_table_component_spec.rb` 加一個例子：`details[data-load-profile]` 沒有 `open`，裡面的 `tbody tr` 數等於站列數加分組標題列；`spec/requests/routes_spec.rb` 斷言 Scenario「Load profile closed by default」。
  - 結果（2026-10-23）：兩個例子改前先跑，失敗在沒有 `details`；元件測試多建一趟返程（第 5、6 站），站列數 3、分組標題 2，兩個數分得開。反向驗證：`details` 加上 `open`、站列數改成方向數，兩個例子都失敗，還原後轉綠。站列數另外寫在收合列的 `data-stop-rows`。字級加一個 token `--text-lead: 18px`（收合列的標題在 640px 以上用）。原本的標題與說明留到 3.4 照文案一節處理；收合裡右緣的漸層改成收合的 slate-50 底色。打開時向下的箭頭轉成向上，稿上只畫了收起的樣子。
- [x] 3.2 實作 Run time bars，套用 design「行駛時間的橫條用 HTML 定位，刻度兩個方向共用」：`RunTimeTableComponent` 算出兩個方向共用的刻度，每一列加一格 `hidden sm:table-cell` 的橫條，表格上方加一行橫條說明。先寫元件測試。
  - 行為：表格帶 `data-scale-from`、`data-scale-to`；每一列的橫條格帶 `data-bar-from`（p50）、`data-bar-to`（p95）、`data-bar-mark`（p85）；樣本少的列也有橫條，顏色較淡；兩個方向都沒有列時沒有刻度、橫條與說明那一行。
  - 驗證：`spec/components/run_time_table_component_spec.rb` 斷言 Scenario「Shared scale for both directions」（刻度 40 到 70，去程 55.0 到 68.0、直線 64.0）、Example「scale ends」三種情況（54.7 與 102.3 是 50 到 110；40.0 與 70.0 是 40 到 70；60.0 與 60.0 是 60 到 70），以及 Scenario「No rows, no scale」（沒有趟次時沒有 `[data-scale-from]` 與 `[data-bar-from]`）；既有的例子不改仍綠。
  - 結果（2026-10-23）：新例子用 `instance_double(RoutePage::RunTimes)` 直接給 spec 裡的 p50／p85／p95，改元件前 9 個失敗；既有 4 個例子連同它們的 `before` 收進一個 `describe`，本體不動。除了點名的 Scenario 與 Example，照分支與計算的規則多測：表頭的兩端與中點、橫條位置的百分比（50.0%、寬 43.3%、直線 80.0%）、樣本少的列有橫條且顏色較淡、有趟次時有說明那一行。反向驗證：拿掉「至少 10 分鐘」、刻度只看去程、樣本少不換顏色，對應的例子各自失敗，還原後轉綠。字級加一個 token `--text-tick: 12px`。
  - 測試檔的一處調整：既有例子用的 `cells` helper 原本取每列所有 `td`，加了橫條那一格（沒有文字）後會多一個空字串；helper 改成排除 `[data-bar-from]`，取回那個例子描述的五格（時、趟數、p50、p85、p95），例子本體沒有改。
  - 跟稿的出入：p50 等於 p95 的列，稿上畫寬 0.8% 的條；實作用 `min-width: 1px`（橫條欄寬 150px，0.8% 約 1px），不在 Ruby 裡另外夾最小值。
- [x] 3.3 換休息試算的結果改成兩欄對照（見 design 的 Design Source「換休息試算對照」）：`BufferTradeComponent` 把「只補不足的部分」「每次都加滿」各做成一欄，每欄是每天多幾車時與最忙小時多幾台車；手機上依指標分兩組、每組兩格並排；`data-value`、`data-peak`、`data-hour`、`data-vehicles` 的元素與文字不變。
  - 行為：數字與文案跟改版前一樣，只換排法；拉滑桿仍只換 `turbo-frame#buffer-trade` 這一塊。
  - 驗證：`spec/components/buffer_trade_component_spec.rb` 不改仍綠；`bin/dev` 在 1280 與 390 寬對照兩張稿。
  - 結果（2026-10-23）：測試範圍的排除理由：只換排法，排法是寫死的 class、只出現在這一塊，沒有新增測試；數字、文案與 `data-value`、`data-peak`、`data-hour`、`data-vehicles` 由既有的 8 個例子保住，不改仍綠。一份 HTML 兩種排法：640px 以上兩欄的外框是另外放進格線、跨三列的框，每一格在欄裡是一列；手機上每一格是一個小框，依指標分兩組。字級加四個 token：`--text-figure`／`--text-figure-sm`（36／32px，兩欄對照的數字）、`--text-figure-minor`／`--text-figure-minor-sm`（30／28px，下面兩個小數字塊）。
  - 對照（`bin/dev` 開 `/routes/15373?range=7d`，headless Chrome 截圖）：1280 寬兩欄、每欄兩列、最忙的小時在標籤下面，下面兩個小數字塊並排，跟稿一致；390 寬依指標分兩組、每組兩格並排，跟稿一致。滑桿標籤裡的分鐘數維持標籤的字級（稿上放大成 28／30px 的 teal），跟 01 的決定一樣，不在這條任務改。
- [x] 3.4 套用 design「文案」：照那一節改 `LayoverChartComponent`、`LayoverTableComponent`、`BufferTradeComponent`、`RunTimeTableComponent`、`LoadChartComponent`、`MrtOverlapComponent`、`LoadProfileTableComponent`、`RouteSummaryComponent` 的模板與 `.yml`（tw、zh-TW、en），加上指標名稱的小標。[after: 2.3, 3.1, 3.2, 3.3]
  - 行為：四張卡各有小標（折返停留、換休息試算、行駛時間、載客剖面）；行駛時間的標題是「一趟從起站到末站要跑多久？」；折返停留表沒有自己的標題，改帶一個 `sr-only` 的 `caption`「折返停留」，螢幕報讀仍知道這是哪張表，表下是合併後的那一句；沿線人數的說明是線與長條都適用的那一段。
  - 驗證：所有元件測試與 request 測試仍綠；每一個 `.yml` 的 en 與 tw 鍵相同（`YAML.load_file(path, aliases: true)` 比對兩邊的鍵）；文案逐條對 design 的文案一節做內容審查。
  - 結果（2026-10-23）：`spec/components/` 與 `spec/requests/` 124 個例子全綠。鍵的比對寫成常駐的例子放在 `spec/components/application_component_spec.rb`（每個元件 `.yml` 的 tw、zh-TW、en 三份鍵相同）：測試只用 tw 渲染，en 少一個鍵只會在正式環境出現，照 TDD 的判準屬於「分開的字面值要對得上」。它一開始就綠，反向驗證：把 `section_nav_component.yml` 的一個 en 鍵改名，它失敗並指出那個檔，還原後轉綠。文案本身是寫死的翻譯字串，照測試範圍判準不另寫測試，改從開發伺服器的回應逐條取字對 design 文案一節：四張卡的小標與標題、`sr-only` 的 caption、表下那一句、沿線人數的說明、收合列與收合裡的那一句、橫條說明都一致。小標用 `ApplicationComponent#eyebrow`，四個元件共用一份樣式；`與捷運重疊` 改成 `h3`（`text-subsection`），它底下的「重疊路段」跟著改成 `h4`，標題層級才連得起來。
  - 表下那一句照 design 的要求包含 `layover-other-routes` 的說法：「只算本趟有到末站、下一趟從起站出發，而且兩趟之間沒有去跑別的路線的配對，另一端漏站不影響。」開過去就走那句接在同一段後面，兩句用一個翻譯接起來（tw 不留空格、en 留一個空格），`[data-pass-through-note]` 照舊。
  - 還沒做的文案：沿線人數每站一列的表頭「站名」「人」與「同一個方向四個時段用同一個刻度。」，列在 4.3 才出現，跟著 4.3 加。

## 4. 手機

- [x] 4.1 實作 design「窄螢幕的折返停留表用 CSS 改成卡片，不另外輸出一份」：`LayoverTableComponent` 加 `max-sm:` 樣式與每格的 `data-label`；新增 `spec/system/route_page_mobile_spec.rb`（`:js`、`:duckdb`，用 `RouteDayLoader` 寫入 fixture 的 9001 台北日 2026-10-19，視窗 390×844）。[after: 3.4]
  - 行為：640px 以下，折返停留表的每一列顯示成一張卡，欄名用 `data-label` 顯示，頁面不橫向捲動；640px 以上仍是表格。
  - 驗證：`spec/components/layover_table_component_spec.rb` 不改仍綠（格子文字不含欄名）；系統測試量到 `tr[data-direction]` 的計算 `display` 是 `grid`，`document.documentElement.scrollWidth` 不大於 390。
  - 結果（2026-10-23）：系統測試改前先跑，手機上量到 `table-row` 而失敗；照分支規則同一個例子也量 1400 寬仍是 `table-row`。「分」只掛在有值的格子（`data-unit` 給 `after:` 偽元素用），這個分支在元件測試加一個例子，改前失敗。實作後 `layover_table_component_spec.rb` 既有的例子不改仍綠（欄名與「分」都在偽元素裡，格子文字不變），`spec/system/route_page_layout_spec.rb` 五個例子仍綠，`spec/components/` 與 `spec/requests/` 125 個例子全綠。字級加一個 token `--text-figure-card: 26px`；末站用 3.1 加的 `--text-lead`。
  - 測試範圍的排除理由：`scrollWidth` 不大於 390 沒有在新檔重寫一次，`spec/system/route_page_layout_spec.rb` 的「頁面本身不橫向捲動」已經在同一頁、同一個 390×844 的模擬下量這件事，改壞時由它失敗。
  - 對照（390 寬截圖）：卡頭左邊方向與末站、右上折返方式標籤，下面三欄數字帶欄名與「分」，「不到 15 分鐘」占兩欄，跟稿一致。出入：卡頭寫「去程」不是稿上的「去程結束」，同一份 HTML 只換樣式，格子文字不能多字。
- [x] 4.2 實作 One direction at a time on narrow screens 的行駛時間部分與 Run time bars 的窄螢幕部分，套用 design「窄螢幕的方向切換用 Alpine，沒有 JS 時兩個方向都在」：`RunTimeTableComponent` 的 `section` 帶 `x-data="{ direction: 0 }"`，兩個方向的容器用 `x-bind:class` 加 `max-sm:hidden`，切換按鈕帶 `x-cloak` 與 `sm:hidden`。[after: 4.1]
  - 行為：390px 寬預設只顯示去程，按「返程」只顯示返程，網址不變；行駛時間沒有橫條；1400px 寬兩個方向都顯示，沒有切換按鈕；沒有 JS 時兩個方向都在回應裡、都沒有隱藏的 class 或 style。
  - 驗證：`spec/system/route_page_mobile_spec.rb` 斷言 Scenario「Switching on a phone」「Wide screens show both directions」「No bars on a narrow screen」；`spec/requests/routes_spec.rb` 斷言 Scenario「Without JavaScript」的行駛時間部分。
  - 結果（2026-10-23）：「Switching on a phone」「Wide screens show both directions」與 request 的「Without JavaScript」改前先跑，失敗在沒有方向切換；「No bars on a narrow screen」一開始就綠（3.2 已經讓橫條 `hidden sm:table-cell`）。實作後四個都綠，反向驗證四件事都抓到：橫條拿掉 `hidden`、方向不切、切換在寬螢幕也出現、伺服器輸出就把返程藏起來。「Without JavaScript」量的是兩個方向的容器與它們在 `main` 裡的祖先都沒有 `hidden`、`max-sm:hidden`、`display: none` 或 `x-cloak`，切換按鈕帶 `x-cloak`。系統測試等 Alpine 啟動的方法：找到原本 `x-cloak` 的時段切換或方向切換。
  - 跟稿一致（390 寬截圖）：兩個平分的切換按鈕、預設去程、沒有橫條。手機上有切換按鈕時，方向的小標題改成只給螢幕報讀（`x-bind:class` 加 `max-sm:sr-only`，沒有 JS 時照常顯示），稿上的手機版沒有這個標題。
- [x] 4.3 實作 Load chart along the route 的窄螢幕列，套用 design「窄螢幕的沿線人數改成每站一列，跟 SVG 一起由伺服器輸出」：`LoadChartComponent` 在 SVG 之外輸出每個方向、每個時段的每站一列，SVG 的 `figure` 加 `max-sm:hidden`。先寫元件測試。[after: 3.4]
  - 行為：每列帶 `data-row-seq`，有人數時帶 `data-row-median` 與長條，沒有人數時寫「—」、沒有長條；重疊路段的列帶 `data-row-near`，第一列前一行路段標題；沒有距離時沒有底色與標題；非預設時段帶 `x-cloak`。
  - 驗證：`spec/components/load_chart_component_spec.rb` 斷言 Scenario「Rows on a narrow screen」與「Shaded rows」，既有的七個例子不改仍綠（屬性名分開，不會數到兩份）。改版前後各量一次 `/routes/15373?range=7d` 用 gzip 的回應大小（`curl -s --compressed -o /dev/null -w '%{size_download}'`），記在這條任務下面；壓縮後多出超過 30 KB 就照 design 的 Risks 把列的 class 收到父元素。
  - 結果（2026-10-23）：新例子改前先跑，四個失敗在還沒有列；照分支規則另外測長條長度（刻度頂端 10 時 3.0 是 30.0%、8.0 是 80.0%）、沒有距離時沒有底色與標題、非預設時段帶 `x-cloak`。「沒有距離」那個一開始就綠（列還不存在），反向驗證：讓每一列都帶底色，它與「Shaded rows」都失敗；拿掉列的 `x-cloak`，那個例子失敗，還原後轉綠。既有七個例子不改仍綠：每個方向包一層 `div[data-direction][data-scale-top]`，裡面是 `figure.max-sm:hidden` 與 `div.sm:hidden` 的列，列用 `data-row-*`。沿線人數列的文案（「站名」「人」與「同一個方向四個時段用同一個刻度。」）在這條加。
  - 回應大小（開發伺服器）：開發環境沒有 `Rack::Deflater`，`curl --compressed` 拿到的是未壓縮的大小，所以改用 `curl -s URL | gzip -c -6 | wc -c` 量，前後同一個方法。改這條之前未壓縮 216,019 bytes、gzip 23,891 bytes；之後 407,784 bytes、gzip 31,188 bytes，多 364 列（91 站 × 4 個時段）。壓縮後多 7.3 KB，低於 30 KB，不收 class。未壓縮多約 187 KB，比 design 估的 130 KB 多（每列連縮排約 520 bytes）；Gemfile 有 Thruster，正式環境的回應會壓縮。
  - 跟稿的出入：每個方向的列上面多一行方向名稱，沒有 JS 時兩個方向都在，要分得出是哪一個；稿上的手機版靠方向切換分辨，4.4 有切換之後這一行比照行駛時間只留給螢幕報讀。
- [x] 4.4 實作 One direction at a time on narrow screens 的長條部分，套用 design「窄螢幕的方向切換用 Alpine，沒有 JS 時兩個方向都在」：`LoadChartComponent` 既有的 `x-data` 加 `direction: 0`，每個方向的列帶 `x-show="direction === N"`（不帶 `x-cloak`），方向切換按鈕帶 `x-cloak` 與 `sm:hidden`。[after: 4.2, 4.3]
  - 行為：390px 寬只顯示每站一列、不顯示 SVG；預設去程，按「返程」換成返程；切換時段時列的數字跟著換；沒有 JS 時兩個方向的列都在回應裡、都沒有隱藏的 class 或 style。
  - 驗證：`spec/system/route_page_mobile_spec.rb` 加例子：SVG 的 `figure` 計算 `display` 是 `none`、列可見；切到日間後某一站的 `data-row-median` 顯示值改變；切到返程後只看到返程的列。`spec/requests/routes_spec.rb` 的 Scenario「Without JavaScript」補上每站一列的部分。
  - 結果（2026-10-23）：四個例子改前先跑都失敗（手機上兩個方向的列都顯示、還沒有方向切換）。實作後轉綠；跑的過程中 `wait_for_alpine` 原本找 `[role=group]`，手機上多了方向切換之後找到兩個，改找時段切換的 `[data-band-switch]`（測試 helper 的問題，不是 RED）。時段切換的按鈕加 `value` 與 `data-band-switch` 當掛勾。系統測試量顯示中的列（`getClientRects`）屬於哪個方向、哪個時段：手機上預設只有去程早尖峰；按日間之後全部換成日間，同一站的中位數有變；按返程之後只剩返程。反向驗證：拿掉方向的 `x-show`，三個系統例子失敗；伺服器輸出就在列的容器加 `x-cloak`，request 的「Without JavaScript」失敗（有 JS 時 Alpine 會拿掉，系統測試量不到這件事，所以它屬於 request 層）。還原後轉綠，`spec/requests/`、兩支系統測試與 `spec/components/` 129 個例子全綠。
  - 對照（390 寬截圖）：兩排切換（時段、方向）、表頭、每站一列、重疊路段的底色與路段標題，跟稿一致；方向名稱有切換時只留給螢幕報讀。
  - 收尾時補（2026-10-23）：640px 以上「顯示 SVG、不顯示每站一列」這個分支原本只靠截圖確認；列帶 `x-show`，Alpine 會設定又清掉 inline 的 `display`，之後仍要靠 `sm:hidden` 藏起來，不是純 CSS。系統測試加一個例子：1400 寬、Alpine 啟動後 `figure` 是 `block`、顯示中的列是空的。它一開始就綠，反向驗證：拿掉列容器的 `sm:hidden`，量到去程早尖峰的列而失敗，還原後轉綠；手機系統測試 10 個例子全綠。

## 5. 收尾

- [x] 5.1 實作 design「手機的第一個畫面放得下四個重點數字」並驗證導覽黏住：在 `spec/system/route_page_mobile_spec.rb` 加兩個例子：四張重點數字卡的數字元素 `getBoundingClientRect().bottom` 都不大於 844；捲到 `#runtimes` 之後 `nav[data-section-nav]` 的 `top` 是 0，`#runtimes` 卡的標題在導覽下緣之下。放不下時照 design 先把頁首的範圍切換與涵蓋的日子併成一列。[after: 2.4, 4.4]
  - 行為：390×844 打開 fixture 的路線頁，第一個畫面就看到四個重點數字；從導覽跳到某一區時標題不會被導覽蓋住。
  - 驗證：上面兩個系統測試的例子綠。
  - 結果（2026-10-23）：兩個例子一開始就綠，這兩件事在 2.1（`scroll-mt-20`）、2.3（2×2 的卡片）、2.4（`sticky`）已經做到，不用把頁首的範圍切換與涵蓋的日子併成一列。量到的值（fixture 的 9001，兩端都停車，Google Fonts 有載入）：七個數字（趟次 1、p50 兩行、不到 15 分鐘兩行、捷運重疊兩個方向）的下緣最低是 665px，離 844 還有 179px；點導覽的「行駛時間」之後導覽 top 0、下緣 65，卡片 top 80，標題 top 134。反向驗證：摘要改成一欄，第一個例子失敗；卡片拿掉 `scroll-mt-20`、導覽拿掉 `sticky`，第二個例子各自失敗；還原後轉綠。趟次那張卡的數字也加上 `data-number`，四張卡的數字用同一個掛勾量。
  - 量法：例子是真的點導覽的連結。Turbo 處理同頁錨點時，點擊後約 0.1 秒才捲過去並在網址加上 `#runtimes`，所以先等網址變成 `#runtimes` 再量。
- [x] 5.2 全部跑一次：`bin/rubocop` 對這個 change 新增或修改的檔案，`bin/rails parallel:spec` 全綠；`bin/dev` 開 `/routes/15373?range=7d` 與 `/`，在 1280 與 390 寬各對照一次 `.spectra/design-cache/02-route-page-mobile-first/` 的兩張稿，差異記在這條任務下面。[after: 1.1, 5.1]
  - 行為：路線頁與首頁照 design 呈現；每一頁都有網站名稱列；路線頁的數字跟改版前一樣。
  - 驗證：兩個指令的輸出全綠、沒有 RuboCop 警告；對照結果寫在任務下面。
  - 結果（2026-10-23）：`bin/rubocop` 對這個 change 新增或修改的 23 個 Ruby 檔沒有警告；`bin/rails parallel:spec` 524 個例子 0 失敗、0 略過（01 收尾時是 474 個）；4.4 收尾補的例子加進去之後重跑，525 個例子 0 失敗。
  - 對照（`bin/dev` 開 `/routes/15373?range=7d` 與 `/`，headless Chrome 在 1280 與 390 寬截整頁，稿也用同一個方法截圖）：網站名稱列、四張重點數字卡、區塊導覽、四張卡的小標與標題、分隔線、折返停留表與手機的卡片、試算兩欄對照與手機的兩組、行駛時間橫條與手機的方向切換、沿線人數與手機的每站一列、逐站表的收合、首頁 hero 拿掉站名，都照稿呈現；路線頁的數字跟改版前同一批物件、同一個格式。差異：
    - 頁首只移出卡片：稿上 640px 以上範圍切換與涵蓋的日子靠右一欄、日子標籤白底；實作維持 `RouteCoverageComponent` 原本由上往下的排法，標籤是 slate-50 底，在 slate-50 的頁面上靠外框分辨。這幾條任務沒有一條要改這個元件，留給之後決定。涵蓋的日子照 `day-types` archive 後的內容排，稿上「沒有分平日與假日。」是之前的文案。
    - 重點數字卡從 `lg`（1024px）開始一列 4 張，640 到 1023px 是 2×2（見 2.3）；第 3 張卡的說明是「末站・共 N 筆」（spec 要求每一行標出末站，見 2.3）。
    - 區塊導覽在任何寬度都不換行，放不下就橫向捲動（見 2.4）；1280 寬時一列放得下，跟稿看起來一樣。
    - 手機的折返停留卡頭寫「去程」，稿上是「去程結束」（見 4.1）。
    - 試算滑桿標籤的分鐘數維持標籤字級，稿上放大成 28／30px 的 teal（見 3.3，沿用 01 的決定）。
    - 行駛時間 p50 等於 p95 的列用 `min-width: 1px`，稿上寬 0.8%（見 3.2）。
    - 「與捷運重疊」是 `text-subsection`（20px），稿上 22／21px；它的兩個重疊路段表在桌機上仍是上下排，稿上左右並排（不在這次的任務）。
    - 逐站表打開時箭頭轉向上，稿上只畫了收起的樣子（見 3.1）。
    - 沿線人數的 SVG 維持 01 的 840 寬 viewBox，稿是 960（01 的決定）。
    - 資料限制那張卡的內距跟其他卡一樣（01 記過的差異）。
