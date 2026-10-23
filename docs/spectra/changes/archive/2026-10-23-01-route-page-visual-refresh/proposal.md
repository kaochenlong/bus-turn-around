## Why

這個 change 服務第一樣交付物「路線健檢卡」與第二樣「換休息試算」在網站上的呈現：兩者的數字都在路線頁 `/routes/:route_id` 上給人讀。不新增任何資料，讀的仍是衍生表 `route_days`、`route_day_stops`、`trips`、`layovers`、`trip_stop_counts`，資料來源不變。

路線頁的讀者是調度站長（`docs/use-cases.md` 第 1 節，辦公室）與駕駛（第 11 節，「手機。路線頁要一個畫面、三秒開完」）。現在的頁面在手機上不好讀：

- 內文 15px，表格 14px，圖上的字 12px。
- 分佈圖的 SVG 是 460 寬的 viewBox 縮到螢幕寬，390px 寬的手機上內容區 358px，圖上的字約 9.3px；沿線人數圖最小 600px 寬、viewBox 720，字約 10px。兩個數字都是依模板的 viewBox 與 CSS 寬度換算，沒有在瀏覽器量。
- 表格的格子沒有內距、沒有列線；樣本少的列用 `text-slate-400`，在白底上對比 2.6:1，低於 WCAG AA 的 4.5:1（依 Tailwind 的色碼換算）。
- 折返停留表 8 欄、載客剖面表 7 欄，手機上沒有橫向捲動的框。

2026-10-23 用設計稿（Claude Design 畫布，見 design.md 的 Design Source）討論後，使用者選了「手機優先」的改版方向，拆成兩個 change：這個先做外觀與字級，不動區塊、順序、指標與規格；結構調整在 `02-route-page-mobile-first`。看稿時使用者的意見是「字型有點太小」，字級整體放大是這次的核心。

## What Changes

- 字級：在 `app/frontend/stylesheets/application.css` 的 `@theme` 定一套字級，路線頁與首頁共用。內文 17px（原 15px）；表格 16px，手機 15px（原 14px）；表頭 14px，手機 13px；表下註記 15px；圖上的字 14px（原 12px）；區塊標題 26px，手機 23px（原 24px）；路線名 40px，手機 30px（原 32px）；顯名聲明 footer 13px（原 12px）。
- 首頁只改字級與頁面寬度：hero、路線清單、資料限制、資料來源換成同一套字級，頁面最寬跟路線頁一起改；其他版面、插圖、文案不動。
- 頁面寬度：路線頁與首頁的 `main`、顯名聲明 footer 最寬從 1024px 改成 1152px，640px 以上左右內距 32px（手機維持 16px），三處改用 `application.css` 裡同一個 `.page-column`，左右邊界對齊。設計稿是 1080px；2026-10-23 apply 之後使用者要求加寬，在 1080px、1152px、1080px 但內距 16px 三個選項中選了 1152px，並選擇首頁一起改。
- 路線頁的版面：頁面底色 slate-50、每個區塊一張白卡（圓角 16px、slate-200 外框）。卡片外框由新的 `CardComponent` 在 `app/views/routes/show.html.erb` 包上，區塊元件本身不帶外框，`02-route-page-mobile-first` 才能把圖與表放進同一張卡。頂部把路線名、起迄、範圍切換、涵蓋的日子與趟次摘要併成一張卡，桌機上趟次摘要靠右；範圍切換與沿線人數圖的時段切換改成分段按鈕；涵蓋的日子改成小標籤。layout 的 `<body>` 讀 `content_for(:body_class)`，路線頁用它把底色帶到 footer，首頁不設就維持白底。
- 表格：格子加內距與列線、數字靠右；行駛時間的 p85 欄加粗；樣本少的列從 slate-400 改成 slate-500（白底對比 4.76:1，依色碼換算），趟數旁的「（樣本少）」改成標籤；折返停留表的折返方式改成標籤，「停車」「開過去就走」用同一個樣式；載客剖面表改成依方向分組，方向成為每組的標題列，不再每列重複。
- 分佈圖：一張 SVG 同時給桌機與手機，viewBox 改成 300 寬、字 14，桌機最寬 340px；390px 與 375px 寬的手機上字不小於 14px（換算值，由新的系統測試量）。圖說裡折返方式的括號改成標籤，`app/components/layover_chart_component.yml` 的 `stops_html` 三個語系跟著改。
- 沿線人數圖：viewBox 改成 840 寬、字 14，手機上放在可以橫向捲動的框裡，最小寬度 720px，字約 12px（換算值）。手機上要再大，等 `02-route-page-mobile-first` 改成每站一列的長條。
- 手機：折返停留表、載客剖面表放進可以橫向捲動的框，右緣有漸層提示還有內容。
- 資料限制：路線頁那份改成卡片樣式，首頁那份只放大字級。
- 測試：新增手機寬度的系統測試，量頁面不會橫向捲動、內文 17px、分佈圖的字實際顯示不小於 14px；載客剖面表的元件測試跟著分組列改。

## Non-Goals

- 區塊順序、內容、指標定義：一律不改。網站名稱列、重點數字、區塊導覽、圖與表合併、收起逐站表、行駛時間的橫條、手機的折返停留卡片、去程／返程切換、每站一列的長條，都在 `02-route-page-mobile-first`。
- 換色票：維持 slate 與 teal-700，amber 只給提醒框。`home-page` 的決定「構圖與風格：一張圖講司機的休息，色票鎖在路線頁，不畫五官，通用公車」把首頁插圖的色票綁在路線頁這套，換色就要重出插圖。
- 用顏色標好壞、標任何門檻：`route-page-charts` 的非目標「在圖上標示任何審議門檻（重疊 70%、尖峰每班次 5 人），或用顏色表示「合不合規」」照舊；p85 加粗只是字重。「停車」「開過去就走」兩個標籤同一個樣式，照 `zhongshan-turnaround-ends` 的決定不用顏色區分。
- 圖表套件、提示框、縮放、動畫：`route-page-charts` 的決定「圖由伺服器輸出成內嵌 SVG，不用圖表套件」與它的非目標照舊。
- 深色模式、換字型、把 Google Fonts 連結搬進 layout。
- 首頁除了字級與頁面寬度以外的任何改動。

## Impact

- Affected specs: none
- Affected code:
  - New: app/components/card_component.rb, app/components/card_component.html.erb, spec/components/card_component_spec.rb, spec/system/route_page_layout_spec.rb
  - Modified: app/components/application_component.rb, app/components/load_profile_table_component.yml, spec/components/data_limitations_component_spec.rb, app/frontend/stylesheets/application.css, app/views/layouts/application.html.erb, app/views/routes/show.html.erb, app/views/pages/home.html.erb, app/components/route_coverage_component.html.erb, app/components/route_coverage_component.yml, app/components/route_summary_component.html.erb, app/components/layover_chart_component.rb, app/components/layover_chart_component.html.erb, app/components/layover_chart_component.yml, app/components/load_chart_component.rb, app/components/load_chart_component.html.erb, app/components/run_time_table_component.html.erb, app/components/layover_table_component.html.erb, app/components/buffer_trade_component.html.erb, app/components/mrt_overlap_component.html.erb, app/components/load_profile_table_component.rb, app/components/load_profile_table_component.html.erb, app/components/data_limitations_component.rb, app/components/data_limitations_component.html.erb, app/components/attribution_component.html.erb, app/components/home_hero_component.html.erb, app/components/route_list_component.html.erb, app/components/data_sources_component.html.erb, spec/components/load_profile_table_component_spec.rb, spec/components/run_time_table_component_spec.rb, spec/components/route_coverage_component_spec.rb, spec/requests/site_layout_spec.rb
  - Removed: (none)
- Compatibility: no capability-level observable behavior changes。區塊、順序、數字、`data-*` 屬性都不變，`spec/requests/routes_spec.rb` 的區塊順序與既有元件測試照舊要綠；只有載客剖面表的元件測試因為方向改成分組列而要改寫；行駛時間表、範圍切換、layout 的 body class 各在自己的測試檔加新例子。
- 排程：`02-route-page-mobile-first` 建立在這個 change 的字級與卡片樣式上，等這個 change archive 之後才開始。
- 排程：`day-types` 正在 apply（2026-10-23 看到 15 項做完 10 項），它改 `RouteCoverageComponent` 的 `.rb` 與 `.yml`、`app/models/route_page/coverage.rb`、`DataLimitationsComponent` 與 `AttributionComponent` 的 `.yml`、`ApplicationComponent`，也改了大部分元件測試的資料建法。頁首會標出涵蓋的日子是平日還是假日、每天的日曆備註、另一種日型別最近一天的連結，並拿掉「沒有分平日與假日」那句。這個 change 等 `day-types` archive 之後才 apply，頂部那張卡照 archive 後的 `route-page`「Day coverage」內容排。`layover-other-routes` 只改 `app/components/layover_table_component.yml` 的說明，跟這個 change 改的 `.html.erb` 不衝突。
