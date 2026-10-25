## Why

這個 change 服務三樣交付物中的第二樣「換休息試算」，把它往調度員的桌上多推一步：現在的試算只回答「每趟多留幾分鐘休息要多花幾車時、幾台車」，調度員拿到數字之後，班表還是得自己在紙上從頭鋪。使用場景 1 寫的交付物是「該路線分時段的實際行駛時間 p50 與 p85、折返停留分佈的一頁表格，加上每趟加 15 分鐘緩衝要多幾台車的試算」，而站長每天早上實際在做的，是在行車憑單上一車一張寫下每個車次幾點發車。這個 change 讓網站用量到的行駛時間、調度員選的休息分鐘數與每小時發車數，鋪出一車一張的班表，可以在頁面上改、印出來帶進調度室。它是給排班的人用的工具：準不準不是重點，要不要照著發是調度員的事，網站不替這張表定位。

它需要的資料全部已經在衍生表裡：`trips` 的逐趟起訖與方向（行駛時間的百分位數、量到的每小時發車數、量到的每天車數）、`layovers`（直接折返那一端量到的停留中位數）、`route_day_stops`（兩端的站名）、`config/route_page.yml` 記的兩端性質。不讀靜態快照裡公佈的班距與定時班表，不開新的衍生表，不重跑 `derived:load`。

為什麼是現在：2026-10-25 的討論查到，四條有路線頁的路線裡三條對外公佈的只有班距範圍，哪台車幾點發車沒有任何公開的地方；開放資料裡的「業者機動預排班表」佐證班本每天浮動（10-21 與 10-22 都有的 91 條路線裡 48 條的發車時刻不同），但我們四條都不在裡面。這塊空白就是調度員每天手填的部分。

2026-10-25 apply 做到一半，使用者改了兩個決定，這份提案與 design、specs、tasks 跟著改：這個工具叫「班表」、不叫「草稿」；鋪排與手動微調都在瀏覽器算，伺服器只給量到的資料。原本做好的伺服器端微調（POST）、Ruby 的鋪排與四小時視窗拆掉，詳見 design「鋪排與微調都在瀏覽器算，伺服器只給量到的資料」。

## What Changes

- 新增一條路線一天的「班表」頁，網址在路線頁底下（`/routes/<Id>/timetable`），吃路線頁同一組 `day` 與 `range`，加上休息分鐘數（沿用 `buffer`，0 到 20，預設 15）與行駛時間百分位數 `p`（50 到 95，每 5 一格，預設 85）當初始值。每個方向每小時的發車數預設取涵蓋日子量到的平均，在頁面上改，不進網址。
- 伺服器只給資料：回應裡嵌一段 JSON，有每個方向每個小時在每個百分位數下的計畫行駛時間與是否退回全天、量到的每小時發車數、兩端的停留分鐘數、兩端的站名。鋪排、每張單的四小時休息數字、頁首的車數與班數、改時刻、刪列、加列全部在瀏覽器算，不送回伺服器、不存。換百分位數、休息或發車數立刻重新鋪排、手動改過的會不見，介面明講；`buffer` 與 `p` 寫回網址、不多一筆瀏覽紀錄（同換休息試算拉桿的做法），重新載入保得住。
- 鋪排規則：每小時的發車數在那一小時內平均分佈；一趟的計畫行駛時間取該方向、該發車小時在涵蓋日子裡的第 p 百分位數，那一小時不到 5 趟時退回該方向全天的同一百分位數並在單子上標出；停車那一端停滿休息分鐘數才接下一趟，直接折返那一端停量到的停留中位數；每一班發車交給在那一端等最久的車，沒有車就多開一台。
- 單子一車一張，欄位照行車憑單：車次、發車時間、起點、預計到達終點、停留、預計返回起點、預計返站時間、回站後停留；職號、姓名、調度員、里程留白給調度員手填。每張單報「若一人開完這張單，連續 4 小時裡最緊的那段休了幾分鐘」，照 `layover-metrics` 的四小時視窗算在計畫時刻上，只報數字，不標合不合規。
- 用量到的趟次驗班表：對每一個百分位數選項，列出涵蓋日子裡實際行駛時間超過計畫的趟次比例、超過到把休息吃光的比例、超過分鐘數的中位數；一趟一趟各算，不追延誤往下一趟傳。這張表由伺服器算與畫，選中的那一列由瀏覽器隨 `p` 切換。
- 頁首寫路線名、涵蓋的日子與日型別、用的參數、量到的平均每天車數、鋪出來的車數與每方向班數、「手動改過 N 處」；不寫「草稿」「不是定稿」這類替這張表定位的話。頁尾沿用網站的顯名聲明，加上這張表的資料限制。
- 列印：列印樣式表把名稱列、控制項與提醒藏起來、時刻印成文字、一車一頁，按鈕呼叫瀏覽器的列印，另存 PDF 交給瀏覽器；不加 PDF gem、不裝 headless Chrome。
- 沒有 JavaScript 時：頁面寫一句這一頁要有 JavaScript 才鋪得出班表，沒有單子；超時比例表、資料限制、顯名聲明照常。網站其他頁沒有 JavaScript 也完整，這一頁是例外。
- 入口：路線頁換休息試算那張卡上一個「排成班表」的連結，帶著當時的 `day`、`range`、`buffer`；網站名稱列在路線頁與班表頁多一個「班表」連結。首頁的名稱列不變。
- 測試工具：瀏覽器端的演算法用 Vitest 做單元測試（新的 devDependency），`bin/ci` 多跑一步 `yarn test:js`；頁面上的流程用既有的 system spec。
- 文件：`docs/spectra/LANGUAGE.md` 新增「班本」與「班表」；`docs/use-cases.md` 第 11 項「這套系統不發班表」改成「網站鋪得出一車一張的班表，要不要照著發是站長的事」；README 的交付物加上班表頁。
- 名稱：capability 叫 `timetable`，網址、路由 helper、類別、元件、控制器、view、spec 與 data 屬性都不用 Draft 這個字（`RoutePage::Timetable`、`TimetableSheetComponent`、`TimetablesController` 這一類）。
- 重開一條記過的非目標：`zhongshan-buffer-trade` 的「駕駛工時、排班、班表產生」只在「單一路線、單一天、一車一張的班表」這個範圍重開；駕駛工時與 README 的「全網排班最佳化」不重開。詳見 design。

## 資料限制與假設

- 車不等於人：鋪的是車，一車一張；雙班制下同一台車兩個人開，職號與姓名由調度員填，四小時休息的數字標明「若一人開完這張單」。
- 漏站：計畫行駛時間只用完整、起訖都量到端點的趟次，跟 `run-time` 一樣；預設的每小時發車數用涵蓋日子裡所有趟次算，漏起站的趟次發車小時可能差一格。
- 跨小時重複：衍生表寫入時已經去重，這裡不再處理。
- 刷卡率：這個 change 不用車上人數，不受影響。
- 直接折返那一端的停留取量到的中位數，是車從末站開到下一趟起站的時間，不是休息。
- 計畫行駛時間是量到的百分位數，不是保證；超過計畫的分鐘數從休息裡扣，一趟一趟各算，前一趟晚到會不會推遲下一趟，這張表不追。

## 非目標

- 產生或推薦駕駛的班：職號、姓名、工時、輪休都不碰。
- 全網或多路線一起排、任何目標函數或最佳化；班表只照上面的規則鋪一次，給調度員改。
- 讀公佈的班距或定時班表當預設；開新的衍生表；班表對照（脫班、班距達成）另開 change。
- 儲存班表、帳號、下載成檔案再上傳、分享改過的班表；把發車數或手動改的格子放進網址。
- 沒有 JavaScript 也鋪得出班表：這一頁要 JavaScript。
- 延誤傳遞的模擬、蒙地卡羅；換休息試算現有的任何數字、定義與介面。
- 伺服器端產 PDF（Prawn、wicked_pdf、Grover 這類）。
- 把四小時休息的數字標成合規或不合規、用顏色標好壞。
- 把量到的班次串、歸零檢查、資料品質數字搬上頁面（`zhongshan-route-page` 的非目標照舊）。
- 首頁的名稱列加連結、名稱列做選單。

## Capabilities

### New Capabilities

- `timetable`: 一條路線一天、一車一張的班表：網址與初始參數、伺服器給瀏覽器的資料、預設值、鋪排規則、單子的內容、計畫時刻上的四小時休息數字、用量到的趟次驗班表的表、瀏覽器裡的手動微調、網址同步、列印、沒有 JavaScript 時的樣子。

### Modified Capabilities

- `route-page`: 換休息試算那一塊多一個連到班表頁的連結，帶著當時的日子、範圍與休息分鐘數。
- `site-layout`: 網站名稱列在路線頁與班表頁多一個「班表」連結；首頁仍是兩個連結。

## Impact

- 新增：`app/controllers/timetables_controller.rb`、`config/routes.rb` 的班表網址（只有 GET）、`app/models/route_page/timetable.rb`（組資料給頁面）與 `planned_run_times.rb`、`measured_departures.rb`、`timetable_overruns.rb` 三個查詢物件、`app/components/` 的班表頁首、單子的 template、超時比例表、資料限制四個元件及同層 `.yml`、`app/frontend/timetable/` 的鋪排、四小時視窗、列的配對、微調、時刻格式化等 JavaScript 模組與它們的 Vitest 測試、`app/frontend/entrypoints/application.js` 的 Alpine 元件 `timetable`、`app/frontend/stylesheets/application.css` 的列印樣式、`package.json` 的 Vitest 與 `test:js`、`config/ci.rb` 的 JavaScript 測試步驟。
- 修改：`app/components/buffer_trade_component.html.erb`、`.rb` 與 `.yml`（連結）、`app/components/site_bar_component.rb`、`.html.erb` 與 `.yml`（第三個連結）、`app/views/layouts/application.html.erb`（把目前路線傳給名稱列）、`app/controllers/routes_controller.rb`（設給名稱列的路線）、`app/controllers/application_controller.rb`（共用的 404 渲染）、`config/locales` 的頁面標題與方向名。
- 拆掉（2026-10-25 之前做好的伺服器端微調）：POST 路由與控制器的 `update`、`RoutePage::DraftEdits`、Ruby 的鋪排 `RoutePage::DraftLayout` 與四小時視窗 `RoutePage::DraftRestWindows`、單子裡的 POST 表單與隱藏欄位，以及它們的 spec。
- 測試：`spec/models/route_page/` 的三個查詢物件與 `timetable_spec.rb`、`spec/requests/timetables_spec.rb`、`spec/components/` 的各元件、`spec/system/timetable_*_spec.rb`（微調、列印、入口、手機寬度）、`spec/requests/site_layout_spec.rb` 與 `spec/requests/routes_spec.rb` 的名稱列與連結、`app/frontend/timetable/*.test.js`。
- 文件：`docs/spectra/LANGUAGE.md`、`docs/use-cases.md`、`README.md`。
- 不動：衍生表結構、`analysis/`、`bin/health-card`、`derived:load`、`bin/push-derived`、正式站的資料。
