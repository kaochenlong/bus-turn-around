## 1. 折返停留分佈圖

- [x] 1.1 新增 `RoutePage::LayoverDistribution`（需求 Layover distribution chart；決策「分組下界在 Ruby 再寫一次，由一致性測試守住」）。
  - 行為：
    - `#directions` 對最新那一天有的每個方向回傳一筆 `Direction(go_back:, last_stop:, next_first_stop:, counts:)`。
    - `counts` 是涵蓋日子裡、以這個方向結束的折返停留，在 `BIN_LOWER_BOUNDS = [0, 5, 10, 15, 30, 60]` 各組的筆數，每組含下界、不含下一個下界，最後一組不設上限。
    - `last_stop` 是這個方向 seq 最大的站，`next_first_stop` 是另一個方向 seq 最小的站。
    - 沒有折返停留的方向，`counts` 全是 0。
  - 驗證：
    - `spec/models/route_page/layover_distribution_spec.rb`：4.9、5.0、14.9、15.0、75.0 分鐘得到 1、1、1、1、0、1；標題的兩個站名；沒有折返停留的方向；兩天合計。
    - `spec/models/route_page/card_consistency_spec.rb` 新增一例：fixture 2026-10-19 上，`BIN_LOWER_BOUNDS` 等於健檢卡的 `bin_lower_bounds`，每個方向的 `counts` 等於 `bin_counts`（去程 0,0,6,3,1,0、返程 0,0,3,3,0,3）。
- [x] 1.2 新增 `LayoverChartComponent`，用 `--locale` 產生 `.yml`（需求 Layover distribution chart；決策「圖由伺服器輸出成內嵌 SVG，不用圖表套件」）。[after: 1.1]
  - 行為：
    - 輸出 `section[data-section=layover-chart]`，每個方向一個 `[data-direction]` 的內嵌 SVG 橫條圖。
    - 每根長條是 `[data-bin=<下界>][data-count=<筆數>]`，長度按同一個方向內的最大筆數比例畫。
    - 有一條 `[data-divider=15]`。
    - 標題含末站與下一趟起站的站名。
    - 沒有折返停留的方向顯示 `[data-no-layover]`，不畫長條。
    - SVG 帶 `role="img"` 與 `aria-label`；所有長條同一個顏色。
  - 驗證：`spec/components/layover_chart_component_spec.rb`，驗長條的組與筆數、兩個站名、空方向、分隔線。標題與說明是固定文案，照規則不寫斷言，在 3.2 人工看過。

## 2. 沿線車上人數圖

- [x] 2.1 新增 `RoutePage::LoadProfile#stops` 與 `RoutePage::MrtOverlap#stretch_ranges`。
  - 行為：
    - `stops` 回傳最新那一天每個方向的 `Stop(go_back:, seq:, stop_name:)`，依方向與 seq 排序。
    - `stretch_ranges` 回傳 `{ go_back => [first_seq..last_seq] }`，跟 `stretches` 同一套切法，但不查車上人數；`needs_reload?` 為真時回傳 `{}`。
    - `stretches` 改成從同一個 `runs` 組出來，輸出不變。
  - 驗證：
    - `spec/models/route_page/mrt_overlap_spec.rb` 新增：seq 2 到 4 靠近捷運時得到 `{ 0 => [2..4] }`；沒有距離時得到 `{}`。
    - 現有的 `stretches` 測試照樣通過。
    - `stops` 在 2.2 的元件測試裡驗。
- [x] 2.2 新增 `LoadChartComponent`，用 `--locale` 產生 `.yml`（需求 Load chart along the route；決策「圖由伺服器輸出成內嵌 SVG，不用圖表套件」）。[after: 2.1]
  - 行為：
    - 輸出 `section[data-section=load-chart]`，每個方向一個 `[data-direction][data-scale-top]` 的內嵌 SVG 折線圖，橫軸是 `LoadProfile#stops` 的站序。
    - 四個時段各一組 `[data-band]`，點是 `[data-seq][data-median]`；沒有人數的站，線斷開。
    - 縱軸頂端是該方向四個時段最大中位數往上取到 10 的倍數，沒有任何人數時是 10。
    - 底色帶是 `[data-span-from][data-span-to]`，標出兩端站名；圖上也寫出方向的第一站與最後一站。
    - 早尖峰之外的時段組與切換按鈕帶 `x-cloak`，用 Alpine `x-show` 切換，不重新載入頁面。
  - 驗證：`spec/components/load_chart_component_spec.rb`：
    - 早尖峰 seq 0、1 的點是 3.0、8.0；日間只有 seq 0 的 5.0。
    - 兩個時段的 `data-scale-top` 相同且不小於 8.0。
    - seq 2–4 的一段底色帶，以及沒有距離時沒有底色帶。
    - 非預設時段帶 `x-cloak`。

## 3. 放上路線頁與真資料核對

- [x] 3.1 在 `app/views/routes/show.html.erb` 的摘要後面依序加上兩張圖（需求 Page content；決策「兩張圖放在摘要後面，表格順序不變」）。[after: 1.2, 2.2]
  - 行為：頁面區塊順序變成 summary、layover-chart、load-chart、run-times、layovers、buffer-trade、mrt-overlap、load-profile、limitations。
  - 驗證：
    - `spec/requests/routes_spec.rb` 的區塊順序測試改成這個順序。
    - 現有「頁面不含車牌」與「距離缺漏」的測試照樣通過。
    - test 環境的 Bullet 不報 N+1。
- [x] 3.2 在中山幹線真資料上核對並收尾。[after: 3.1]
  - 數字核對：用 `bin/dev` 打開 `/routes/15373?day=2026-10-21&range=7d`，核對以下各項跟 design 量到的值一致：
    - 去程長條 201、10、3、0、0、0，返程 11、24、16、29、16、23。
    - 標題站名：去程是青年公園(馬場町) 與青年社宅，返程是職能發展學院二。
    - 底色帶在去程 seq 17–37、返程 seq 57–74。
    - 縱軸頂端去程 40、返程 60。
  - 畫面檢查：截圖看桌面與 375px 手機寬度，沒有水平捲動，時段切換有作用。
  - 收尾驗證：`make test` 全過、`bin/rubocop` 對這次動到的檔案沒有問題、`bin/brakeman` 0 警告。
