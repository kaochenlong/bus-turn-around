## Why

這個 change 服務三樣交付物的第二樣「換休息」試算，改的是路線頁上已經有的「每趟加緩衝」那一塊（`buffer-trade`）。現在它只有一個拉桿，放開才重算，結果是兩欄區間；站長與司機看不出每多幾分鐘要多花多少車，也問不了「如果車再晚到幾分鐘」。2026-10-24 的討論定了方向：改成一條成本曲線，休息與晚到疊在同一條軸上，拉桿一動數字就跟著變；同一個晚到同時報兩邊：保住休息要多花多少車，或車數不變的話休息剩多少。

需要的資料都已經在衍生表裡，不用新的資料來源，不改 `analysis/`，不用重跑 `derived:load`：

- `layovers`：每次折返停留的結束時刻、下一趟出發時刻與結束的方向。
- `trips`：每天的趟次數與車牌數，只拿來算趟次與每天平均幾台車，頁面不顯示車牌。
- `route_day_stops`：涵蓋日子裡最新一天、這一頁路線各方向的末站名稱，給「加在哪一端」當選項。
- `config/route_page.yml` 的 `ends`：哪一端停車。

## What Changes

- 新增「晚到」：每次回到停車那一端，都比量到的再晚 D 分鐘，0 到 20 的整數，預設 0，網址參數 `late`。休息 B 分鐘（既有的 `buffer`，畫面上改稱「休息」）加晚到 D 分鐘，是每次折返要留的分鐘數 B + D。增加車時的下限與上限、最忙小時多派幾台車，都改用 B + D 算；D 是 0 時，所有數字跟現在一樣。
- 同一個 D 報兩邊：保住 B 分鐘休息要多花幾車時、多派幾台車；車數不變的話，停得到 B 分鐘的比例從多少變成多少。
- 伺服器把每次折返要留 0 到 40 分鐘的每一個整數點都算好，連同畫面要的數字寫進回應。休息與晚到兩個拉桿移動時，數字、曲線上的點、逐小時的列直接換成那一點的值，不送請求；網址換成新的 `buffer` 與 `late`，不多一筆瀏覽紀錄。
- 新增曲線圖：橫軸是每次折返要留幾分鐘，縱軸是一天多幾車時，畫下限與上限兩條線與中間的範圍，標出目前的點。另報「再多留 1 分鐘，一天再多幾車時」。
- 新增兩個篩選：「套用的小時」（`from`、`to`，起訖小時，預設全天）與「加在哪一端」（`end`，只列停車的那端，只在兩端都停車的路線出現）。改篩選時送出表單，只替換這一塊；涵蓋那一句同時報全天量到幾次、試算用了幾次。
- 新增逐小時的多派幾台車，放在預設關閉的 details 裡。
- 網址參數 `late`、`from`、`to`、`end` 不合法時回 400；`end` 指到開過去就走那一端也回 400。
- 沒有 JavaScript 時，所有條件是一張會送出的表單，回應裡就是那組條件的數字。
- 資料限制補上晚到與套用的小時；`docs/spectra/LANGUAGE.md` 新增「緩衝」「晚到」兩條，改「換休息試算」的邊界。

## Non-Goals

非目標，這個 change 不做：

- 改計算的基礎。上限與晚到仍只算量到的折返停留，跟 `zhongshan-buffer-trade` 的決定「增加車時用下限與上限的區間，不給單一數字」一樣；改成所有從停車端發車的趟次會碰到那條決定，另外討論。
- 「停車時有幾分鐘不是在休息」的假設參數。曲線已經畫出整段區間，讀者看得到兩頭與斜率，不需要在區間裡挑一個點。
- 車數不變時少跑幾趟、班距拉長多少。那要從週期推，是新的定義，也會影響乘客；`zhongshan-buffer-trade` 把受影響乘客數列為非目標。
- 換算成駕駛的班、每車時多少錢、每台車一天一次的長休。`buffer-trade` 規定不報駕駛工時；錢沒有資料來源，`docs/background.md` 第 4 點也定調不談省錢；長休要先有班次串，而且雙班制下車對不回人。
- 「早尖峰」「晚尖峰」這類按鈕。`zhongshan-buffer-trade` 的決定「增加車數按折返停留結束的台北小時估」否決過按時段分組，理由是時段的起訖只寫在 `analysis/params.sql`。
- 在開過去就走那一端加緩衝（`zhongshan-turnaround-ends` 的非目標）。
- 圖表套件、提示框、縮放、動畫（`route-page-charts` 的決定「圖由伺服器輸出成內嵌 SVG，不用圖表套件」與它的非目標）。
- 用 GPS 量停留裡有多少時間在移動。那要改 `analysis/`、重跑 `derived:load`、再推上正式站。
- 健檢卡、其他路線、`analysis/` 與衍生表、排程與部署。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `buffer-trade`：試算的基礎可以依套用的小時與停車端篩選；新增晚到、每次折返要留的分鐘數、0 到 40 分鐘的成本曲線、再多留 1 分鐘的成本、逐小時的多派車數；休息達成率分成現在與車數不變再晚到兩個。
- `route-page`：網址多 `late`、`from`、`to`、`end` 四個參數；試算那一塊的內容與控制項（拉桿不送請求、篩選只替換這一塊、沒有 JavaScript 時是一張表單）；新增曲線圖；資料限制多晚到與套用的小時。

## Impact

- 修改 `app/models/route_page/buffer_trade.rb`（晚到、篩選、曲線）、`app/controllers/routes_controller.rb`（讀新參數並檢查）、`app/views/routes/show.html.erb`（把新條件傳進去）、`app/components/buffer_trade_component.rb`、`app/components/buffer_trade_component.html.erb`、`app/components/buffer_trade_component.yml`、`app/components/data_limitations_component.yml`、`app/frontend/entrypoints/application.js`（新增 `bufferTrade` 這個 Alpine 元件）、`docs/spectra/LANGUAGE.md`。
- 測試：`spec/models/route_page/buffer_trade_spec.rb`、`spec/components/buffer_trade_component_spec.rb`、`spec/requests/routes_spec.rb`，新增 `spec/system/buffer_trade_spec.rb`。
- 不新增 migration、npm 或 gem 相依；不改 `analysis/`、`bin/health-card`；不用重跑 `derived:load`，也不用 `bin/push-derived`。
- 資料限制與假設，頁面與 spec 都寫明：
  - 車不等於人：增加的是車時與車數，不是駕駛工時，雙班制下一台車兩人開。
  - 折返停留含回場、加油、等發車，是休息的上限，所以真正的成本落在下限與上限之間，達成率也是上限。
  - 晚到是假設：每次回到停車那一端都晚同樣的分鐘數；量到的那幾天的晚到已經在折返停留裡，不能再加一次；晚到比停留長的部分會延到下一趟發車，試算不往下追。
  - 漏站：10 秒輪詢會漏站，漏了起站或末站的趟次接不成折返停留，試算的基礎因此比趟次少，涵蓋那一句照實報。
  - 刷卡率：試算不用車上人數，刷卡率不影響。
  - 跨小時重複：原始檔跨小時檔的重複，下游重建趟次時一律再去重一次，不影響折返停留。
  - 多派幾台車是按小時平均的估計，不是排班結果；單一天的逐小時數字樣本少，要看多天的範圍。
