## Why

這個 change 服務第一樣交付物「路線健檢卡」與第二樣「換休息試算」在網站上的呈現，也就是路線頁 `/routes/:route_id`。不新增任何資料：新的重點數字全部取自頁面上已經算好、已經顯示的值，讀的仍是衍生表 `route_days`、`route_day_stops`、`trips`、`layovers`、`trip_stop_counts`。

駕駛的使用場景（`docs/use-cases.md` 第 11 節）是「地：手機。路線頁要一個畫面、三秒開完」：在終點站停下來的那幾分鐘，要看到每個時段的趟次實際跑多久、在終點能停幾分鐘。`01-route-page-visual-refresh` 放大了字、整理了外觀，但頁面的結構沒變：

- 390px 寬的手機上，第一個畫面只有路線名、範圍切換與兩個趟次數字（依設計稿 A 手機版的排版估的，沒有在瀏覽器量）。
- 同一個指標的圖和表隔著兩三個區塊：分佈圖在第二塊，折返停留表在第五塊。
- 逐站的載客剖面表，中山幹線有 91 列（2026-10-19 到 21 開發資料庫量到的），整張攤開在資料限制前面。
- 路線頁沒有回首頁的路。

2026-10-23 討論設計稿（見 design.md 的 Design Source）時，使用者選了「手機優先」的方向，拆成兩個 change。這是第二個，在第一個的字級與卡片樣式上調整結構。

## What Changes

- 網站名稱列：layout 在每一頁最上面放一條「折返點 TurnAround」，連回 `/`；首頁 hero 拿掉自己那行網站名稱，同一個名字在首頁只出現一次。
- 路線頁的摘要多三個重點數字：停車端的折返停留 p50、停車端不到 15 分鐘的比例、捷運重疊（500 公尺內）兩個方向的比例。每個數字都是頁面表格裡已經有的值、同一個寫法，點了跳到那一區；兩端都停車時每一端各一行，沒有停車的一端時寫明沒有，表格寫「—」時這裡也寫「—」，捷運距離還沒載入時是「—」。
- 摘要下面一排區塊導覽，連到折返停留、換休息試算、行駛時間、載客剖面、捷運重疊、資料限制，捲動時停在畫面上方；只用連結，不靠 JS。
- **BREAKING**（規格上的區塊順序）區塊依指標分組重排：摘要 → 折返停留（分佈圖與折返停留表同一張卡）→ 換休息試算 → 行駛時間 → 載客剖面（沿線人數圖、捷運重疊、逐站表同一張卡）→ 資料限制。這會推翻 `route-page-charts` 的決定「兩張圖放在摘要後面，表格順序不變」，使用者已同意。
- 折返停留表裡被重點數字引用的格子（停車端的 p50 與不到 15 分鐘的比例）加粗，對得回摘要；只用字重，不用顏色。
- 換休息試算的結果從表格改成「只補不足的部分」「每次都加滿」兩欄對照，數字與文案不變；手機上依指標分組，每個指標兩格並排。
- 逐站的載客剖面表放進預設收起的區塊，每一列仍在伺服器輸出裡。
- 行駛時間每一列加一條從 p50 到 p95 的橫條，p85 標一條直線，兩個方向用同一個刻度；640px 以下不畫橫條。
- 640px 以下的手機：
  - 折返停留表每一列改成一張卡，同一份 HTML，只換樣式。
  - 行駛時間與沿線人數一次顯示一個方向，用去程／返程切換，預設去程；沒有 JS 時兩個方向都顯示。
  - 沿線人數圖改成每站一列：站名、長條、中位數。同一個方向四個時段共用刻度；沒有人數的站寫「—」、不畫長條；重疊路段的列有底色，路段第一列前寫出兩端站名。
- 文案：
  - 各區塊加上指標名稱的小標：折返停留、換休息試算、行駛時間、載客剖面。
  - 行駛時間的標題改成問句「一趟從起站到末站要跑多久？」。
  - 「換休息試算：每趟加緩衝」拆成小標「換休息試算」與標題「每趟加緩衝」。
  - 折返停留圖與表的說明併成一段；沿線人數的說明改成線與長條都適用的寫法。
  - tw、zh-TW、en 三份一起改。

## Non-Goals

- 指標定義、衍生表、`analysis/`、`bin/health-card`：一律不改。
- 重點數字以外的新彙總值，例如兩個停車端合併成一個 p50：卡上只放表格裡已經有的值。`route-page-charts` 的目標「不會出現第二套定義」照舊；`home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」的理由是數字旁邊要有定義與資料限制，這裡的重點數字在同一頁、帶限定詞（「休息的上限」）、點了就到定義那一區。
- 用顏色或門檻標示重點數字或任何數字的好壞：`route-page-charts` 的非目標照舊。
- 互動提示框、縮放、動畫、圖表套件：`route-page-charts` 的決定「圖由伺服器輸出成內嵌 SVG，不用圖表套件」與它的非目標照舊。
- 網站名稱列上的選單：只放一個回首頁的連結。`home-page` 把「共用的頁首導覽」列為非目標，理由是「各自等有東西再開 change，不留空殼」；這次有了回首頁的需要才加，也只加這一個連結，車牌查詢、回報表單、月報等有了再說。
- 區塊導覽標出目前捲到哪一區：要 JS 監聽捲動，不在範圍。
- 首頁除了拿掉 hero 那行網站名稱以外的改動。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `route-page`: 區塊順序改成依指標分組；摘要加重點數字；新增區塊導覽、行駛時間的橫條、窄螢幕一次一個方向；逐站的載客剖面表預設收起；沿線人數圖在窄螢幕改成每站一列。
- `site-layout`: 每一頁最上面加網站名稱列，連回首頁。
- `home-page`: hero 不再放網站名稱，改由網站名稱列提供。

## Impact

- 新增：app/components/site_bar_component.rb、app/components/site_bar_component.html.erb；app/components/section_nav_component.rb、app/components/section_nav_component.html.erb、app/components/section_nav_component.yml；spec/components/site_bar_component_spec.rb、spec/components/section_nav_component_spec.rb；spec/system/route_page_mobile_spec.rb。
- 修改：app/views/layouts/application.html.erb、app/views/routes/show.html.erb、app/models/route_page/layover_stats.rb（`rows` 記住結果，摘要與折返停留表共用一次查詢）、app/components/application_component.rb（表格與重點數字共用的數字格式）、app/components/card_component.html.erb（錨點跳轉時讓出導覽的高度）、app/components/route_summary_component.rb、app/components/route_summary_component.html.erb、app/components/route_summary_component.yml、app/components/layover_chart_component.html.erb、app/components/layover_chart_component.yml、app/components/layover_table_component.rb、app/components/layover_table_component.html.erb、app/components/layover_table_component.yml、app/components/buffer_trade_component.html.erb、app/components/buffer_trade_component.yml、app/components/run_time_table_component.rb、app/components/run_time_table_component.html.erb、app/components/run_time_table_component.yml、app/components/load_chart_component.rb、app/components/load_chart_component.html.erb、app/components/load_chart_component.yml、app/components/mrt_overlap_component.rb、app/components/mrt_overlap_component.html.erb、app/components/load_profile_table_component.html.erb、app/components/load_profile_table_component.yml、app/components/home_hero_component.html.erb。
- 測試：spec/models/route_page/layover_stats_spec.rb（`rows` 只查一次）、spec/requests/routes_spec.rb（區塊順序、重點數字與表格同值、導覽、沒有 JS 時兩個方向都在）、spec/requests/site_layout_spec.rb、spec/requests/pages_spec.rb、spec/components/route_summary_component_spec.rb、spec/components/run_time_table_component_spec.rb、spec/components/load_chart_component_spec.rb、spec/components/load_profile_table_component_spec.rb、spec/components/home_hero_component_spec.rb。
- 排程：建立在 `01-route-page-visual-refresh` 的字級 token 與 `CardComponent` 上，等它 archive 之後才 apply。另外兩個進行中的 change 也要先 archive：`day-types` 改 `ApplicationComponent` 與頁首的涵蓋內容（這個 change 要在 `ApplicationComponent` 加數字格式、在手機上壓縮頁首）；`layover-other-routes` 改 `app/components/layover_table_component.yml` 的說明，這個 change 的文案也改同一份，要以它改過的說法為準。三個 change 改的規格條目不重疊：`day-types` 改 `route-page` 的「Day coverage」「Data limitations on the page」、`home-page` 的「Route list」、`site-layout` 的「Attribution footer on every page」；`layover-other-routes` 改 `layover-metrics`。
- 相依：不新增 gem 或 npm 套件；頁面互動仍是 Alpine。
- 資料限制與假設：這個 change 不改任何指標定義。重點數字沿用表格的值，也沿用它們的限制：折返停留是駕駛休息的上限（車不等於人，雙班制下一台車兩個人開），卡上寫「休息的上限」；捷運重疊是站牌到出入口的直線距離，靠近捷運不等於可以被捷運取代。資料限制區塊的條目不變。
