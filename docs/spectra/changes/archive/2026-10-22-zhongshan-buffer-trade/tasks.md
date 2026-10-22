<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
-->

## 1. 試算的計算

- [x] 1.1 實作 Buffer minutes 與 Route page address and parameters 的修改，套用 design「`buffer` 不合法時沿用 `RoutePage::Coverage::InvalidParameter`」：新增 `RoutePage::BufferTrade.minutes(param)`，空值回 15，只接受 0 到 20 的整數字串，其他丟 `RoutePage::Coverage::InvalidParameter`；`RoutesController#show` 先算 `@buffer_minutes` 再建 `Coverage`。驗證：`spec/models/route_page/buffer_trade_spec.rb` 斷言 Scenario「Default buffer」與「Rejected buffer values」（`21`、`-1`、`abc`、`1.5`），並斷言 `0` 與 `20` 被接受；`spec/requests/routes_spec.rb` 斷言 Scenario「Bad buffer」（`/routes/9001?buffer=21` 回 400）。
- [x] 1.2 實作 Measured base of the estimate、Rest achievement、Added vehicle-hours as a range 與 Added vehicles in the busiest hour，套用 design「增加車時用下限與上限的區間，不給單一數字」「增加車數按折返停留結束的台北小時估」「只報量到的折返停留，標出涵蓋率」「休息達成率是不少於 B 分鐘的比例」：`RoutePage::BufferTrade.new(route_days, minutes:)` 回 `n_days`、`n_layovers`、`n_trips`、`vehicles_per_day`、`achieved_share`、`vehicle_hours`（下限、上限）、`peak`（下限、上限各自的小時與車數），分鐘從 `layovers` 的兩個時刻算，小時用 `end_time` 的台北小時，不選車牌欄位。驗證：spec 以灌入的資料斷言 Scenario「Coverage reported」（2 天、4 次、8 趟、2.5 台）、「Share at or above the buffer」（25.0%）、「No layover」（達成率與增加量都沒有）、Example「Four layovers over two days」（下限 0.2、上限 0.5）、「Hour 8 is busiest」（下限 8 點 0.1、上限 8 點 0.4）、「Tie goes to the earlier hour」（7 點 0.2）。 [after: 1.1]

## 2. 路線頁

- [x] 2.1 實作 Page content 的修改與 No threshold or compliance marking，套用 design「緩衝分鐘數用網址參數 `buffer`，在 server 算」：用 `bin/rails g view_component:component BufferTrade buffer_trade coverage --locale` 產生元件，整塊包在 `turbo_frame_tag "buffer-trade"`（`data-turbo-action="advance"`）裡，`section[data-section="buffer-trade"]` 顯示緩衝分鐘數、涵蓋天數、量到的折返停留與趟次、達成率、車時下限與上限、最忙小時的車數下限與上限、每天平均車數，各自放在可斷言的 `data-*` 欄位；GET 表單有 `input[type=range][name=buffer][min=0][max=20]` 與 hidden 的 `day`、`range`，放開拉桿時用 Alpine 送出、拖動時顯示目前分鐘數；沒有折返停留時顯示說明、不顯示數字；不出現任何合不合規的標示。`app/views/routes/show.html.erb` 把它放在折返停留與捷運重疊之間。驗證：`spec/components/buffer_trade_component_spec.rb` 斷言數字出現在對應欄位、表單欄位與 frame id、沒有折返停留時的說明；`spec/requests/routes_spec.rb` 的區塊順序改成摘要、行駛時間、折返停留、試算、捷運重疊、載客剖面、資料限制（Scenario「Overlap block in place」），並斷言 Scenario「Defaults」的緩衝 15 與「Buffer from the address」（`?day=2026-10-19&range=7d&buffer=10` 時元件用 10 分鐘、hidden 欄位帶著 2026-10-19 與 7d）；`spec/requests/route_page_fixture_spec.rb` 仍沒有任何車牌、Bullet 不報 N+1。 [after: 1.2]
- [x] 2.2 實作 Data limitations on the page 的修改：`app/components/data_limitations_component.yml` 的 tw 與 en 加上試算的限制（算的是車時不是駕駛工時、只用量到的折返停留、增加車數是按小時平均的估計不是排班）；`docs/spectra/LANGUAGE.md` 的「換休息試算」一條把「工時變化」改成「車時變化」，「在資料或程式碼裡」寫上 `RoutePage::BufferTrade`，「邊界」寫明目前只有每趟加緩衝一個動作、下限與上限的意思。驗證：資料限制與詞彙表是固定文案，照專案的 TDD 規則不寫斷言，做內容審查對照 `buffer-trade` spec 與 design；`spec/requests/routes_spec.rb` 既有的資料限制一節存在的斷言仍綠。 [after: 2.1]

## 3. 真資料

- [x] 3.1 以真資料驗收：衍生表已有 15373 的 2026-10-19 到 10-21，不用重跑 `derived:load`。對 `/routes/15373?day=2026-10-19&buffer=15` 核對量到的折返停留 77 次、趟次 163、達成率 23.4%、車時下限 10.9、上限 19.3，與 design 的 Implementation Contract 相同；另記下 `range=7d` 與單日的最忙小時，寫進 design 的 Risks 那一條。驗證：`bin/rails runner` 印出的數字對照 design；`make test`、`bin/rubocop`（改到的檔）、`bin/brakeman` 全綠；用 `bin/dev` 開頁面人工確認拉動拉桿時只有這一塊重新載入、網址帶上 `buffer`、上一頁回得去。 [after: 2.2]
