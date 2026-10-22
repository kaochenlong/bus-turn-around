## Why

這個 change 服務第一樣交付物「路線健檢卡」在網站上的那一頁：路線頁（`/routes/:route_id`）。資料全部來自已經寫進 PostgreSQL 的衍生表（`layovers`、`trip_stop_counts`、`trips`、`route_day_stops`），不讀原始檔，也不新增任何資料來源。

路線頁現在有七塊，全是表格。專案要回答的兩個問題：「折返點實際能休幾分鐘」「重疊路段實際載多少人」，答案都在頁面上，但散在折返停留表、捷運重疊表、91 列的載客剖面表裡，第一次打開的人看不出這一頁在回答什麼。

中山幹線 2026-10-19 到 10-21 的真資料（量到的）就是例子：
- 去程結束在青年公園(馬場町) 的 214 筆折返停留，201 筆不到 5 分鐘。返程結束在職能發展學院二的 119 筆裡，有 39 筆超過 30 分鐘。表格裡這只是兩列 p10、p50、p90，畫成分佈一眼就看得出兩端完全不同。
- 去程第 17 到 37 站、返程第 57 到 74 站是 500 公尺內有捷運出入口的連續段。它們的車上人數在載客剖面表裡要逐列對站序才找得到。

## What Changes

- 路線頁在摘要下面加兩張圖，各用一句白話的問題當標題：
  - **折返停留分佈**：每個方向一張橫條圖，分組跟健檢卡相同（0、5、10、15、30、60 分鐘為下界，最後一組不設上限），每組標出筆數，15 分鐘處畫一條分隔線。標題寫出那個方向的末站，以及下一趟出發的起站（另一個方向的起站）。
  - **沿線車上人數**：每個方向一張折線圖，橫軸是站序，縱軸是每站車上人數的中位數。500 公尺內有捷運出入口的連續段畫成底色帶。用一組按鈕在早尖峰、日間、晚尖峰、其餘四個時段之間切換；同一個方向的四個時段用同一個縱軸刻度。
- 原本的表格全部留著，順序不變，放在兩張圖下面，當成可以引用的精確數字。
- 圖由伺服器輸出成內嵌 SVG，不加任何 JS 或 Ruby 套件；時段切換用現有的 Alpine。
- `RoutePage::MrtOverlap` 多一個只回傳重疊路段站序範圍的方法，畫底色帶時不用再去查每段的車上人數。

## Non-Goals

- 拿掉或改寫任何現有表格與它們的數字。表格是引用用的精確數字，圖只看得出大概。
- 修改折返停留、載客剖面、捷運重疊、換休息試算的定義或數字。
- 在圖上標示任何審議門檻（重疊 70%、尖峰每班次 5 人），或用顏色表示「合不合規」。15 分鐘那條線是把現有「不到 15 分鐘」那一欄畫出來，不是判定。
- 查清楚青年公園那一端的折返停留是不是量錯地方。這張圖會讓那一端很醒目，但查證另外處理；這次只在標題寫出量的是哪兩個站。
- 換休息試算、行駛時間的圖；健檢卡（`bin/health-card`）加圖；其他路線；平日與假日分開。
- 互動提示框、縮放、動畫，或任何 JS 圖表套件。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `route-page`：頁面內容的順序多了兩張圖；新增折返停留分佈圖與沿線車上人數圖兩條需求。

## Impact

- 資料限制（沿用頁面上已有的「資料限制」一塊，不新增條目）：
  - 車不等於人，折返停留是休息的上限。
  - 車上人數是刷卡推出來的值，不是點人頭。
  - 10 秒輪詢會漏站，有些站在某些時段沒有人數，折線在那裡斷開，不補值。
  - 圖用的數字跟下面的表格是同一批趟次。
- 受影響的程式碼：
  - 新增 app/models/route_page/layover_distribution.rb
  - 新增 app/components/layover_chart_component.rb、.html.erb、.yml
  - 新增 app/components/load_chart_component.rb、.html.erb、.yml
  - 修改 app/models/route_page/mrt_overlap.rb
  - 修改 app/views/routes/show.html.erb
- 受影響的測試：新增 spec/models/route_page/layover_distribution_spec.rb、spec/components/layover_chart_component_spec.rb、spec/components/load_chart_component_spec.rb；修改 spec/models/route_page/mrt_overlap_spec.rb、spec/requests/routes_spec.rb。
- 相依套件：無新增。
