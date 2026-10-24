<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）原文照抄，分析器靠字串比對。
-->

## 1. 改之前先留基準

- [x] 1.1 改任何檔之前，先替已有路線頁的三條路線各產一份健檢卡當基準，之後用來證明「Sub-route to route and direction mapping」改了之後三條線的輸出不變：`TURNAROUND_DATA` 指向本機的資料備份（路徑不寫進 repo），對 15373、10712、11764 各跑 `bin/health-card --route <Id> --day 2026-10-22`，Markdown 與 JSON 存到 `tmp/routes-dedupe/before/<Id>/`（`tmp/` 不進 git）。驗證：三條路線各有一份卡，卡上的趟次數跟衍生表裡同一天的 `trips` 筆數相同（`bin/rails runner` 查 `Trip.joins(:route_day).where(route_days: { route_id:, day: "2026-10-22" }).count`），確認基準是對的那一天。

## 2. 先讓測試失敗

- [x] 2.1 [after: 1.1] fixture 照真資料裡重複列的樣子多一列：`spec/fixtures/analysis/static/2026-10-19/GetRoute.gz` 在附屬路線 9002（測試幹線去程半）那一列之後，加一列六欄（`Id`、`pathAttributeId`、`nameZh`、`pathAttributeName`、`departureZh`、`destinationZh`）完全相同、只有 `providerId` 9998、`providerName` 測試客運二不同的列；`spec/fixtures/analysis/README.md` 的靜態快照一節記下這一列與它的用途；`spec/analysis/fixtures_spec.rb` 的例子「路線 9001 有附屬路線 9001、9002、9003，另有一條對照路線 9100」改成期望 (9001, 9002) 出現兩次。`spec/analysis/load_spec.rb` 的「附屬路線對回路線與方向」加一個例子，對應 Sub-route to route and direction mapping 的 Scenario「Duplicate rows of one sub-route」：`routes` 的 `path_attribute_id` 是 9001、9002、9003 各一列。驗證：改 SQL 之前跑 `bundle exec rspec spec/analysis/load_spec.rb spec/analysis/fixtures_spec.rb`，新例子失敗（`routes` 有 4 列），既有例子「去重後的到離站事件不是對到站序就是 unknown-stop，一筆不少」也因為 9002 的事件被算成兩筆而失敗；fixtures_spec 全綠。這是預期的紅燈。

## 3. 修 SQL

- [x] 3.1 [after: 2.1] `analysis/10_load.sql` 建 `routes` 時改成對那六個欄位 `SELECT DISTINCT`，每條附屬路線一列，`bin/health-card` 與 `bin/rails derived:load` 共用這段 SQL 所以一起修好；旁邊的註解寫清楚為什麼要去重（同一條附屬路線在 `GetRoute.gz` 可能一個業者一列，2026-10-24 的快照 55 組、307 每條 4 列）。驗證：`bundle exec rspec spec/analysis/load_spec.rb spec/analysis/fixtures_spec.rb` 全綠；接著 `bin/rails parallel:spec` 全綠，讀 `routes` 下游的 `spec/analysis/trips_spec.rb`、`layovers_spec.rb`、`profile_spec.rb`、`quality_spec.rb`、`card_spec.rb`、`derived_export_spec.rb` 一個斷言都沒有改；`bin/rubocop` 對這次改到的 Ruby 檔沒有警告。

## 4. 真資料確認輸出不變

- [x] 4.1 [after: 3.1] 用 1.1 的基準證明三條路線的輸出不變：同一個 `TURNAROUND_DATA`，對 15373、10712、11764 再跑一次 `bin/health-card --route <Id> --day 2026-10-22` 到 `tmp/routes-dedupe/after/<Id>/`，`diff -r tmp/routes-dedupe/before tmp/routes-dedupe/after` 沒有任何差異（三條路線在 2026-10-24 的快照都沒有重複列，所以照理一個 byte 都不會變；健檢卡的 Deterministic output 保證同輸入同輸出）。驗證：diff 無輸出；把三條路線的趟次數與折返停留筆數抄進這條任務底下當紀錄。

    紀錄（2026-10-24 執行，`TURNAROUND_DATA` 指向本機備份，靜態快照日等於資料日 2026-10-22）：15373 中山幹線 趟次 164、折返停留 105；10712 251 趟次 74、折返停留 66；11764 251區 趟次 107、折返停留 91。三條路線的趟次數跟衍生表同一天的 `trips` 筆數相同，折返停留筆數也跟 `layovers` 相同。改前改後 `diff -r tmp/routes-dedupe/before tmp/routes-dedupe/after` 只差每張卡的「產出時刻」一行（`bin/health-card` 用執行當下的時間寫這一行），其餘逐行相同；trips、layovers、chains、profile、quality 五個 CSV 逐檔 byte 相同。兩次執行之間 `analysis/` 的 SQL、`bin/health-card` 與 `lib/analysis_run.rb` 只有 `10_load.sql` 的指紋變了。`bin/health-card` 的輸出是 Markdown 卡加這五個 CSV，沒有 JSON，1.1 存的就是這兩樣。2026-10-22 的 `GetRoute.gz` 跟 2026-10-24 一樣是 800 列、731 組，三條路線每條附屬路線各一列，307 的四條附屬路線各 4 列。
