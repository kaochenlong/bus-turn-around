## Context

路線頁的「換休息試算：每趟加緩衝」由 `RoutePage::BufferTrade` 與 `BufferTradeComponent` 組成：

- `RoutePage::BufferTrade` 的 SQL 取涵蓋日子裡結束在停車端的 `layovers`，依結束時刻的台北小時分組，一次算出每小時的筆數、不少於緩衝分鐘數的筆數、下限（補足）與上限（每次都加）的分鐘數；`#vehicle_hours`、`#peak`、`#achieved_share` 都從這一份算。
- `BufferTradeComponent` 包在 `turbo-frame#buffer-trade`（`data-turbo-action="advance"`）裡：一張 GET 表單帶 `day`、`range` 的 hidden 欄位與一個 `input[type=range][name=buffer]`，放開拉桿（`change`）時用 Alpine 送出，只替換這一塊；表單外是兩欄區間（下限、上限的車時與最忙小時的車數）、休息達成率與每天平均車數。
- `RoutesController#show` 用 `RoutePage::BufferTrade.minutes` 讀 `buffer`，不合法時丟 `RoutePage::Coverage::InvalidParameter`，轉成 400。

2026-10-24 的討論（`/spectra-discuss`）結論：使用者要的是「每多幾分鐘的休息或晚到，車時就增加多少」看得到、拉了就變。休息與晚到在算式裡疊在同一條軸上；同一個晚到報兩邊（保住休息要多花多少車、車數不變時休息剩多少），使用者選了兩邊都報。

已核對的事實：

- `config/route_page.yml`：15373、10712、11764 都是方向 1 停車、方向 0 開過去就走（三處開過去就走那一端的折返停留中位數 1.9、2.3、2.8 分鐘，寫在設定的查證註解）；16111（307，掛 19108）兩端都停車。
- `RoutePage::Coverage#route_days` 已經 `order(:day)`；在它後面接 `order(day: :desc).pick` 會變成先照日期由舊到新排，7 天範圍取到的是最早那天（`RoutePage::LayoverDistribution`、`LayoverStats`、`LoadProfile` 是這樣寫的）。`RoutePage::Cycles`、`StopSequence` 用 `reorder(day: :desc)`，取到的是最新一天。
- `route_day_stops` 每列帶 `route_id`，307 的頁面同一天有 16111 與 19108 兩份站序。
- 2026-10-24 路線頁上中山幹線某一天的試算寫著「停車那一端量到 36 次折返停留，這段期間總共跑了 164 趟」（使用者的截圖，量到的）。

仍然生效、這個 change 照著走的決定：

- `zhongshan-buffer-trade`「增加車時用下限與上限的區間，不給單一數字」：理由是停了 15 分鐘不等於休息了 15 分鐘，只給一個數字會被讀成成本就這麼多。這裡只把公式裡的 B 換成每次折返要留的分鐘數，區間、只用量到的折返停留、除以天數與 60、一位小數都不變。
- `zhongshan-buffer-trade`「增加車數按折返停留結束的台北小時估」：它否決按時段分組，理由是時段的起訖只寫在 `analysis/params.sql`。套用的小時照小時篩，不做時段按鈕。
- `zhongshan-buffer-trade`「緩衝分鐘數用網址參數 `buffer`，在 server 算」：理由是計算留在 Ruby、用 RSpec 測，網址就是試算的完整狀態。這裡照舊；只有「放開拉桿時送出表單」這一個做法，對休息與晚到兩個拉桿改成下面「曲線在伺服器算好寫進回應，休息與晚到的拉桿不送請求」那一條。
- `zhongshan-turnaround-ends`「試算只算停車端的折返停留，開過去就走那一端只報筆數」與它的非目標「假設青年公園端之後設了停車位、兩端一起加緩衝的試算」。
- `route-page-charts`「圖由伺服器輸出成內嵌 SVG，不用圖表套件」與它的非目標（JS 圖表套件、提示框、縮放、動畫）。
- `turnaround-map`「資料由伺服器算好寫進回應，前端只畫」、`load-chart-stretch-markers`「指到某一段或清單某一列時，兩邊一起變深」（位置由伺服器算好，JavaScript 只切換）、`02-route-page-mobile-first`「窄螢幕的方向切換用 Alpine，沒有 JS 時兩個方向都在」。

詞彙依 `docs/spectra/LANGUAGE.md`：折返停留、停車那一端、開過去就走、換休息試算、台北日。這個 change 新增「緩衝」「晚到」兩條、改「換休息試算」的邊界（見最後一條決定）。

## Goals / Non-Goals

**Goals:**

- 休息與晚到兩個拉桿一動，車時、多派的車數、曲線上的點、休息達成率立刻跟著變，不等伺服器。
- 看得到「再多留 1 分鐘要多花多少」，也看得到整條成本曲線。
- 晚到疊在休息上，同時報保住休息的成本與車數不變時的達成率。
- 可以只看某幾個小時、只看某一個停車端。
- 晚到是 0、篩選是預設時，所有數字跟現在一樣；沒有 JavaScript 時頁面照樣完整。

**Non-Goals:**

- 把上限與晚到的計算基礎改成所有從停車端發車的趟次（會碰到「增加車時用下限與上限的區間，不給單一數字」記下的「量到的折返停留次數」，另外討論）。
- 「停車時有幾分鐘不是在休息」的假設參數。
- 車數不變時少跑幾趟、班距拉長多少；受影響乘客數。
- 駕駛的班、每車時的錢、每台車一天一次的長休。
- 時段按鈕（早尖峰、晚尖峰）、跨午夜繞回來的小時範圍。
- 在開過去就走那一端加緩衝。
- 圖表套件、提示框、縮放、動畫。
- 用 GPS 量停留裡有多少時間在移動；`analysis/`、衍生表、`derived:load`、健檢卡、其他路線、排程與部署。

## Decisions

### 晚到疊在休息上：每次折返要留 B + D 分鐘

晚到 D 是一個假設：每次車回到停車那一端，都比量到的再晚 D 分鐘，下一趟的出發時刻不變，所以那一次停留短 D 分鐘。休息 B 分鐘（`buffer`）加晚到 D 分鐘，是每次折返要留的分鐘數 H = B + D。

對試算基礎裡量到的每一次折返停留 m 分鐘：

- 下限（補足）：`max(H − m, 0)`。
- 上限（每次都加）：`H`。

兩者加總後除以涵蓋天數再除以 60，報每天平均車時，四捨五入到一位小數；最忙小時照舊按折返停留結束的台北小時分組、同值取較早的小時。D 是 0 時 H 等於 B，公式跟現在一字不差。

晚到比停留長（m < D）時，下限加的是 `H − m`，比 B 多：那次停留吸收不了的晚到，加上要保住的休息。上限每一次都是 H。因為 m 不小於 0，下限永遠不超過上限。

D 是 0 到 20 的整數，預設 0，網址參數 `late`；20 跟休息的上限一樣，是介面的範圍，不是對實際晚到的估計。H 因此是 0 到 40。

理由：

- 對車時來說，休息與晚到都是車停在停車那一端的分鐘，疊在同一條軸上。但兩者不是同一個價錢：下限那條線越往右越陡，同樣 1 分鐘，在 20 分鐘那裡比在 10 分鐘那裡貴。
- 晚到量在回到停車那一端的時候，而不是每一趟：15373、10712、11764 只有一端停車，另一端開過去就走，整個來回的晚到都落在停車那一端；307 兩端都停車，各自吸收自己那一趟。「回到停車那一端時比量到的再晚 D 分鐘」兩種路線都說得通。
- 量到的那幾天的晚到已經在折返停留裡：車晚到，停留就短。D 只能是「再晚」，把平常的晚到再加一次就重複算了。

替代方案：

- 每一趟晚 D 分鐘：一端停車的路線等於停車那一端晚 2D，兩端停車的路線是每端晚 D，同一個數字在不同路線意思不同。否決。
- 跟班表比的誤點：衍生表沒有班表的到站時刻，`run-time-vs-cycle` 的非目標記過班表要先寫進新的衍生表。否決。
- 用量到的行駛時間 p85 與 p50 的差當晚到的預設值：那是趟次之間的差異，已經反映在量到的停留裡，再加一次就重複。否決。

### 同一個晚到報兩邊：保住休息的成本、車數不變的達成率

- 保住休息：H 的下限與上限車時、再多留 1 分鐘的成本、下限與上限各自最忙的小時與那個小時多派幾台車。
- 車數不變：量到的折返停留中 `m − D ≥ B`（也就是 `m ≥ H`）的比例，標成「車數不變、再晚到 D 分鐘，還停得到 B 分鐘的比例」，只在 D 大於 0 時出現，放在既有的「現在已經停到 B 分鐘以上的比例」（`m ≥ B`）旁邊。晚到比停留長的那幾次算沒停到；它們會讓下一趟晚出發，試算不往下追，所以這個比例也是上限。

理由：使用者在討論裡選了兩邊都報。司機看的是休息剩多少，站長看的是要多花多少車，兩個數字都從同一份折返停留算，達成率那一格本來就在，只是多一個晚到之後的值。

替代方案：只報成本、只報達成率（使用者 2026-10-24 選了兩邊都報）。

### 曲線在伺服器算好寫進回應，休息與晚到的拉桿不送請求

`RoutePage::BufferTrade` 對選定的套用的小時與停車端，把 H 從 0 到 40 的每一個整數點都算好（內部多算 41，給再多留 1 分鐘的差用）；每一點帶齊畫面要的數字：下限與上限車時、再多留 1 分鐘的成本、`m ≥ H` 的比例、下限與上限最忙的小時與車數、每個小時的下限與上限車數。一個查詢：基礎的每一筆依結束小時分組，與 `generate_series(0, 41)` 交叉，依 H 與小時彙總，Ruby 再依 H 組成曲線。

`BufferTradeComponent` 把曲線寫成 frame 裡的一段 `<script type="application/json" data-buffer-trade-curve>`：數字是元件已經格式化好的字串（一位小數、百分比、`08:00–09:00` 這種小時），加上每一點在圖上的座標。Alpine 元件 `bufferTrade` 只做搬運：

- 休息或晚到的拉桿 `input` 時，把 H = B + D 那一點的字串放進各個數字、把座標放進圖上的點、把逐小時的值放進表格；「現在」的達成率取 H = B 那一點。
- 用 `history.replaceState(history.state, "", url)` 把網址的 `buffer`、`late` 換成新的值，其他參數照留，不多一筆瀏覽紀錄，也不送請求。
- 套用的小時與加在哪一端的控制項 `change` 時送出表單；frame 照舊只替換這一塊，`advance` 把網址換成帶全部參數的那一個。

沒有 JavaScript 時，所有控制項是同一張 GET 表單，「重算」按鈕照舊在回應裡（有 JavaScript 時才由 `x-init` 隱藏），伺服器照網址的參數輸出那一組數字。

`zhongshan-buffer-trade`「緩衝分鐘數用網址參數 `buffer`，在 server 算」照舊生效：`buffer` 仍是 0 到 20 的網址參數、預設 15、不合法回 400，計算在 Ruby 的查詢物件裡用 RSpec 測，網址仍是試算的完整狀態。改的只有它做法裡「放開拉桿時送出表單」那一句。它否決的「把每次折返停留的分鐘數送到頁面上、在瀏覽器裡算」這裡也不做：送出去的是算好的結果，沒有任何一筆折返停留。

理由：使用者要拉了就變（2026-10-24）。`turnaround-map` 已經用過「資料由伺服器算好寫進回應，前端只畫」：數字在回應裡，元件測試用 Nokogiri 讀得到；頁面不用等 JavaScript 才完整。

回應會變大：41 點、每點十來個字串，加上每小時兩個字串乘上有折返停留的小時數（一天十八個小時上下）。估計 JSON 未壓縮 20 到 35 KB（估的，沒量過）。驗收時量 `/routes/16111?range=7d` 改動前後的回應大小；超過 60 KB 就把逐小時的值拿出 JSON，只在伺服器輸出選定的 H 那一份，改成逐小時的表格跟著篩選更新、不跟著拉桿更新。

替代方案：

- 照舊放開才送出：數字要等一次來回，不是使用者要的「拉了就變」。否決。
- 另開一個 JSON 端點：`turnaround-map` 否決過（多一條路由、多一次請求，數字離開 HTML 之後元件測試看不到）。否決。
- 在瀏覽器裡用每次折返停留的分鐘數算：`zhongshan-buffer-trade` 否決過。否決。

### 再多留 1 分鐘的成本用前後兩點的差

H 點的「再多留 1 分鐘」是 `f(H + 1) − f(H)`，下限與上限各算一次，用沒有四捨五入的加總相減，再四捨五入到一位小數；H 是 40 時用內部多算的 41。上限的差在每一點都一樣（基礎筆數 ÷ 60 ÷ 天數），下限的差隨 H 變大。

理由：使用者的問題是「每增加幾分鐘，車時增加多少」，就是曲線在那一點的斜率；往後差回答的是「如果再多留 1 分鐘」。

替代方案：往前差（回答的是「最後那 1 分鐘花了多少」，讀起來繞）；每 10 分鐘報一次（太粗）。

### 套用的小時用起訖小時，不做尖峰按鈕

`from` 是 0 到 23、`to` 是 1 到 24 的整數，`from` 要小於 `to`，預設 0 與 24（全天）。小時是折返停留結束時刻的台北小時，跟最忙小時的分組同一個。午夜之後才結束的折返停留落在 0 或 1 點；不支援跨午夜繞回來的範圍。

套用的小時決定試算的基礎：所有車時、車數、達成率、逐小時的列與最忙小時都只用這段時間結束的折返停留。趟次數、每天平均車數、全天量到的筆數、開過去就走那一端的筆數不受影響。

理由：`zhongshan-buffer-trade`「增加車數按折返停留結束的台北小時估」否決過按時段分組，時段的起訖只寫在 `analysis/params.sql`；做成「早尖峰」按鈕就是把同一個定義寫回 Ruby。連續的起訖小時足夠回答「離峰先做要多少」與「我那一班的幾個小時」。

兩個選單只列得出合法的組合：開始小時的選項只有小於目前結束小時的，結束小時的選項只有大於目前開始小時的。有 JavaScript 時每改一個就送出一次，伺服器照新的值重排另一個選單，所以送不出 `from` 不小於 `to` 的組合；不這樣做的話，frame 裡的表單拿到 400 會找不到 frame，整塊壞掉。沒有 JavaScript 時兩個選單一起送出，同時改兩個仍可能送出不合法的組合，那是整頁的請求，回 400，跟直接打錯網址一樣。

替代方案：時段按鈕（否決，理由同上）；每個小時一個勾選框（手機上太長，否決）；不合法的組合自動對調或夾到範圍內（同一個網址參數有兩種處理方式，否決）。

### 加在哪一端只列停車端，只在兩端都停車時出現

`end` 是停車那一端結束的趟次方向（`go_back`）：`0` 或 `1`，而且那一端停車；沒給時是所有停車端。指到開過去就走那一端、或不是 `0` 與 `1` 的值，回 400。只有一端停車的路線，`end` 等於那一端時接受，數字不變；控制項只在兩端都停車時出現（目前只有 16111）。

選項是「兩端」與每個停車端的末站名稱：涵蓋日子裡最新一天（`reorder(day: :desc)`，不是 `order(day: :desc)`）、這一頁路線（`route_id` 等於頁面的路線 `Id`，排除成員路線的站序）在那個方向 `seq` 最大的站牌。

理由：`zhongshan-turnaround-ends` 的決定「試算只算停車端的折返停留，開過去就走那一端只報筆數」說緩衝只能加在車停得下來的地方；它的非目標把「兩端一起加緩衝的試算」留到設施盤點之後。

替代方案：每條路線都顯示這個控制項（大多數路線只有一個選項，只是雜訊，否決）；允許選開過去就走那一端（非目標，否決）。

### 涵蓋那一句同時報全天與試算用的筆數

沒有篩選時照舊：「N 天裡總共跑了 T 趟，在停車那一端量得到車停多久的有 L 次。」有篩選時接一句：「試算只用其中 6 點到 10 點、在莊敬里的 L′ 次。」開過去就走那一端的句子照舊，報全天的筆數。

篩選之後一筆都沒有（L′ 是 0、L 大於 0）時，這一塊說「這幾天 6 點到 10 點，在停車那一端量不到車停了多久，沒辦法試算。」，不出現任何數字、圖與逐小時的表，控制項照舊在，換條件就能再試。L 是 0 時照舊是「這幾天在停車那一端量不到車停了多久，沒辦法試算。」

理由：`zhongshan-buffer-trade`「只報量到的折返停留，標出涵蓋率」要讀者看得到試算用了多少；拿 6 點到 10 點的筆數跟全天的趟次放在一起比，會讀錯。

### 曲線圖由伺服器輸出成內嵌 SVG，點由 Alpine 移動

`svg[data-chart=buffer-curve]`，`viewBox="0 0 320 180"`、`w-full`，`role="img"` 與一句 `aria-label`（說明 H 從 0 到 40 分鐘時下限與上限各從 0 到多少車時，不含目前的點，所以拉桿移動時不用改）。

- 座標：x = 36 + H × 6.8（H 從 0 到 40，畫到 308）；y = 156 − 值 ÷ 頂 × 144，頂是這份回應 H = 40 的上限（沒有四捨五入的值）。
- 下限一條 `polyline[data-bound=lower]`（`stroke-teal-700`），上限一條 `polyline[data-bound=upper]`（`stroke-slate-500`），粗細一樣，各 41 個點；兩條線之間是 `polygon[data-band]`（`fill-teal-50`）。
- 目前的點 `g[data-marker]`：一條從橫軸到上限的虛線（`stroke-slate-400`）與下限、上限上各一個點（半徑 3.5）；伺服器畫在網址的 H，Alpine 移動時從 JSON 取那一點的座標。
- 橫軸刻度 0、10、20、30、40；縱軸標 0 與頂的值（一位小數）。軸的名稱與兩條線的圖例用 HTML 放在圖的上下，圖例的字跟兩欄數字的標題一樣。
- 沒有提示框、縮放、動畫；點直接跳到新位置。

理由：`route-page-charts` 的三個理由（不加 npm 相依、數字不只在 JS 裡、頁面不用等 JS）在這裡都成立；`load-chart-stretch-markers` 已經示範位置由伺服器算好、Alpine 只切換。兩條線粗細一樣，延續 `zhongshan-buffer-trade` 的風險對策「兩個數字並列、同樣大小，不挑一個加粗」。

替代方案：圖表套件（`route-page-charts` 否決）；只有數字不畫圖（看不出越往右越貴，否決）。

### 逐小時的多派車數放在預設關閉的 details

`details` 預設關閉，摘要「各小時要多派幾台車」；裡面一張表：小時（`08:00–09:00`）、不夠的補足、每次都多留，列是套用的小時裡有折返停留的每個小時，照小時排，值是目前 H 的。最忙的小時照舊放在主要的數字裡。

理由：司機在手機上看（`docs/use-cases.md` 第 11 項，一個畫面），十幾列的表不能一打開就佔掉畫面；`02-route-page-mobile-first`「逐站表收進預設關閉的 details」是同一個做法。

替代方案：預設打開（手機上太長，否決）；每小時一根橫條（先給數字，之後再說）。

### 網址參數與檢查

- `late`：只接受 `/\A\d+\z/` 而且在 0 到 20 的字串，空的是 0。
- `from`、`to`：只接受 `/\A\d+\z/` 的字串，`from` 在 0 到 23、`to` 在 1 到 24、`from` 小於 `to`；空的是 0 與 24。
- `end`：只接受 `0` 或 `1`，而且是停車那一端；空的是所有停車端。
- 陣列（例如 `late[]=1`）跟其他不合法的值一樣。不合法一律丟 `RoutePage::Coverage::InvalidParameter`，控制器既有的 rescue 轉成 400。
- `buffer` 沿用舊名，讓已經分享出去的網址照樣能開；畫面上改稱「休息」。
- Ruby 裡 `end` 是保留字，屬性與參數叫 `end_go_back`；小時範圍叫 `hour_range`（`from...to` 的 Range）。

### 返回這一頁時，數字跟網址一致

拉桿移動時，Alpine 同時更新輸入框的 `value` 屬性，讓 Turbo 快取的畫面帶著移動後的值；元件初始化（包括從 Turbo 快取還原）時，從輸入框目前的值讀 B 與 D，再放上 H = B + D 那一點。被換掉的網址與快取的畫面因此一致。

替代方案：像 `homeHero`、`endMap` 那樣在 `turbo:before-cache` 還原成伺服器輸出：網址已經換成移動後的值，還原後畫面卻是伺服器當初的值，兩邊對不上。否決。

### 每次回應帶一個 data-rendered 記號

這一塊的 `section[data-section=buffer-trade]` 帶 `data-rendered`，值是每次輸出時產生的亂數（`SecureRandom.hex(8)`）。拉桿移動後它不變，改篩選、frame 換掉之後它變了；系統測試用它分辨「沒有送請求」與「這一塊重新載入」。

替代方案：從瀏覽器的網路紀錄數請求（要開 CDP 的網路事件，測試慢又容易不穩，否決）。

### 文案

tw 與 zh-TW 用同一份（`<<: *tw`），en 照同樣的意思另寫。

- `eyebrow`「換休息試算」、`title`「每趟加緩衝」不變。
- `note`：「假設班表讓車在停車那一端每次多停幾分鐘再開下一趟，算算一天要多花幾車時、多派幾台車；也可以假設車回到那裡，比量到的再晚幾分鐘。1 車時就是一台車開一個小時。這裡算的是車，不是駕駛的工時。」
- `buffer_html`：「休息 %{minutes} 分鐘」。`late_html`：「晚到 %{minutes} 分鐘」；`late_hint`：「車回到停車那一端，比量到的再晚幾分鐘。量到的那幾天的晚到已經算在裡面。」
- `hours_label`：「套用的小時」，兩個選單之間是「點到」、最後是「點」。`end_label`：「加在哪一端」，`end_both`：「兩端」。`submit`：「重算」不變。
- `hold_html`：「每次折返要留 %{hold} 分鐘（休息 %{minutes} ＋ 晚到 %{late}）」。
- `coverage_html`：「%{days} 天裡總共跑了 %{trips} 趟，在停車那一端量得到車停多久的有 %{layovers} 次。」；`coverage_used_html`：「試算只用其中%{condition}的 %{used} 次。」；`condition_hours`：「%{from} 點到 %{to} 點」；`condition_end`：「在%{stop}」，兩個都有時用「、」接。`pass_through_html` 不變。
- `lower`：「不夠 %{hold} 分鐘的補足」，`upper`：「每次都多留 %{hold} 分鐘」。`vehicle_hours`「一天要多花幾車時」、`peak_vehicles`「最忙的那個小時要多派幾台車」不變；`next_minute`：「再多留 1 分鐘，一天再多幾車時」。
- `bounds_note`：「「不夠的補足」把車現在停的時間都當成休息，只補差額；「每次都多留」把現在停的時間都當成沒在休息，整段另外加。車停著的時候其實有一部分在回場、加油、等發車，所以真正要多花的會落在兩者之間。多派的車數是把那個小時多出來的分鐘數除以 60 估的，實際排班會不一樣。」
- `achieved`「現在已經停到 %{minutes} 分鐘以上的比例」、`vehicles_per_day` 不變；`achieved_late`：「車數不變、再晚到 %{late} 分鐘，還停得到 %{minutes} 分鐘的比例」。
- 圖：`chart_x`「每次折返要留幾分鐘」、`chart_y`「一天多幾車時」、`chart_aria`「每次折返要留 0 到 40 分鐘時一天要多花的車時：不夠的補足從 0 到 %{lower}，每次都多留從 0 到 %{upper}。」
- 逐小時：`hourly_summary`「各小時要多派幾台車」、`hourly_hour`「小時」，另兩欄用 `lower`、`upper` 去掉分鐘數的短名「不夠的補足」「每次都多留」（`lower_short`、`upper_short`）。
- `no_layover` 不變；`no_layover_filtered`：「這幾天%{condition}，在停車那一端量不到車停了多久，沒辦法試算。」
- 資料限制在既有的換休息試算那一條後面加一條：「換休息試算的晚到是假設：每次車回到停車那一端，都比量到的再晚同樣的分鐘數。量到的那幾天的晚到已經算在折返停留裡，不用再加；晚到比停留還長的部分會延到下一趟發車，試算不往下追。套用的小時看的是車回到停車那一端的時刻。」

這個 change 新寫的字串都不提到開過去就走那一端；`pass_through_html` 不在這個 change 的範圍裡，暫存的 `01-pass-through-wording` 要把這個詞改成「直接折返」，誰先 apply 都不衝突。

畫面上不出現合規、達標、門檻與顏色判定（`buffer-trade` 的 No threshold or compliance marking）。

### 詞彙：緩衝分成休息與晚到，套用的小時不叫時段

`docs/spectra/LANGUAGE.md`：

- 新增「緩衝」：班表在停車那一端留給車的時間，換休息試算把它分成休息與吸收晚到兩塊；在程式裡是 `buffer`（休息，沿用舊名）與 `late`（晚到），兩者相加是 `RoutePage::BufferTrade#hold`；邊界寫明緩衝是班表上留的、折返停留是量到的；不要用 recovery time、layover。
- 新增「晚到」：每次回到停車那一端都比量到的再晚的分鐘數，是假設；邊界寫明它不是誤點（衍生表沒有班表的到站時刻）、量到的那幾天的晚到已經在折返停留裡、晚到比停留長的部分試算不往下追；不要用誤點、delay、延誤。
- 改「換休息試算」：輸入是休息、晚到、套用的小時、加在哪一端；曲線在伺服器算好；套用的小時看車回到停車那一端的台北小時，跟載客剖面的時段（`band`）不是同一件事。

## Implementation Contract

**Behavior**

- `GET /routes/15373?day=2026-10-22` 不帶新參數時，試算的數字跟改動前一樣（晚到 0、全天、所有停車端），另外多一張曲線圖、再多留 1 分鐘的成本與收起來的逐小時表。
- `GET /routes/9001?day=2026-10-19&buffer=15&late=6` 用 H = 21 算：伺服器輸出的數字、圖上的點與 JSON 裡第 21 點相同；同一塊另報「現在」（H = 15）與「車數不變、再晚到 6 分鐘」（H = 21）的達成率。
- 在瀏覽器裡移動休息或晚到的拉桿：數字、點、逐小時的值換成 H = B + D 那一點，`data-rendered` 不變，網址的 `buffer`、`late` 換成新的值、其他參數不變、瀏覽紀錄的筆數不變。
- 改套用的小時或加在哪一端：送出表單，只替換這一塊（`data-rendered` 變了），網址帶全部參數。
- 移動拉桿、離開這一頁、再按上一頁：拉桿與數字是移動後的值。
- 沒有 JavaScript：回應裡有一張 GET 表單，含 `buffer`、`late`、`from`、`to`（兩端都停車時還有 `end`）與 hidden 的 `day`、`range`，以及沒有標成隱藏的「重算」按鈕。

**Interface / data shape**

- `RoutePage::BufferTrade`
  - 常數：`DEFAULT_MINUTES = 15`、`MINUTES_RANGE = 0..20`（不變）、`DEFAULT_LATE = 0`、`LATE_RANGE = 0..20`、`HOLD_RANGE = 0..40`、`ALL_HOURS = 0...24`。
  - `self.minutes(param)` 不變；`self.late(param) -> Integer`；`self.hour_range(from, to) -> Range`；`self.end_go_back(param, ends:) -> Integer | nil`。不合法時丟 `RoutePage::Coverage::InvalidParameter`。
  - `new(route_days, minutes:, ends:, late: DEFAULT_LATE, hour_range: ALL_HOURS, end_go_back: nil)`，既有的呼叫照樣能用。
  - `#minutes`、`#late`、`#hold`（B + D）、`#hour_range`、`#end_go_back`、`#ends`、`#filtered?`（小時不是全天或指定了一端）。
  - `#n_days`、`#n_trips`、`#vehicles_per_day` 不變；`#n_stopping_layovers`：全天、所有停車端量到的筆數；`#n_layovers`：套用的小時與停車端篩過的筆數，試算的基礎；`#n_pass_through_layovers`：全天、開過去就走那一端的筆數。
  - `Point = Data.define(:hold, :vehicle_hours, :next_minute, :achieved_share, :peak, :hourly)`：`vehicle_hours` 與 `next_minute` 是 `Bound(lower:, upper:)`，`peak` 是 `Bound(lower: Peak, upper: Peak)`，`hourly` 是 `Hour = Data.define(:hour, :lower, :upper)` 的陣列（套用的小時裡有折返停留的小時，照小時排）。
  - `#curve -> Array<Point>`：H 從 0 到 40，`#curve[h].hold == h`；基礎是 0 筆時是 `nil`。
  - `#point`（`curve[hold]`）；`#vehicle_hours`、`#peak`、`#next_minute` 是 `#point` 的；`#achieved_share` 是 `curve[minutes]` 的（現在）；`#achieved_share_late` 是 `curve[hold]` 的（車數不變、再晚到）。基礎是 0 筆時這些都是 `nil`。
  - `#stopping_end_names -> Hash{Integer => String}`：每個停車端結束的方向對應末站名稱。
- `BufferTradeComponent.new(buffer_trade:, coverage:)` 簽名不變。
  - frame 裡的 `script[type="application/json"][data-buffer-trade-curve]`，形狀是 `{ "hours": ["08:00–09:00", ...], "points": [ { "hold": 21, "vehicle_hours": ["0.4", "0.7"], "next_minute": ["0.0", "0.0"], "achieved": "0.0%", "peak": [["08:00–09:00", "0.2"], ["08:00–09:00", "0.5"]], "hourly": [["0.2", "0.5"], ["0.2", "0.2"]], "marker": { "x": 178.8, "lower_y": 113.7, "upper_y": 80.4 } }, ... ] }`：`points` 的索引就是 H，每個陣列都是先下限後上限，`hourly` 跟 `hours` 一一對應。
  - 既有的 `data-value` 名稱（`minutes`、`days`、`layovers`、`trips`、`achieved`、`vehicle-hours-lower`、`vehicle-hours-upper`、`vehicles-per-day`、`pass-through-layovers`）與 `data-peak` 照留；新增 `late`、`hold`、`used-layovers`、`next-minute-lower`、`next-minute-upper`、`achieved-late`。
  - 這一塊的說明文字（`note`、`bounds_note`、拉桿下的說明、涵蓋那一句、篩選後沒有折返停留的說明，以及新增的任何說明段落）不加 `max-w-[46em]` 或其他行寬上限，跟卡片一樣寬，照 `ui-touchups` 的決定「說明文字拿掉 46em 的行寬上限，14 處一起」。2026-10-24 它已經拿掉這一塊原本的 3 處，所以開工時模板裡沒有 `max-w-[46em]`。
- `RoutesController#show`：在建 `Coverage` 之前，用上面的四個類別方法讀 `buffer`、`late`、`from`/`to`、`end`，傳進 `app/views/routes/show.html.erb` 建的 `RoutePage::BufferTrade`。
- `app/frontend/entrypoints/application.js`：`Alpine.data("bufferTrade", ...)`，讀 `data-buffer-trade-curve`，做「曲線在伺服器算好寫進回應，休息與晚到的拉桿不送請求」與「返回這一頁時，數字跟網址一致」兩條說的事；不算任何數字、不算任何座標。

**Failure modes**

- 不合法的 `late`、`from`、`to`、`end`：400，跟 `day`、`range`、`buffer` 一樣，不輸出半頁。畫面上的選單只列合法的值，所以有 JavaScript 時從畫面送不出 400；沒有 JavaScript 時同時改兩個小時選單，可能送出 `from` 不小於 `to`，整頁回 400。
- 涵蓋的日子裡停車端一筆都沒有：照舊的說明，沒有圖、沒有 JSON；篩選之後一筆都沒有：說明寫出條件，控制項照舊在。
- 開過去就走那一端：永遠不進試算，`end` 指到它回 400。
- 沒有 JavaScript 或 JSON 讀不到：伺服器輸出的數字照舊在，拉桿要按「重算」才更新。

**Acceptance criteria**

- `spec/models/route_page/buffer_trade_spec.rb` 用手算的資料驗證：H = B + D 的下限、上限、最忙小時；晚到比停留長時下限加的比 B 多；現在與車數不變的達成率；再多留 1 分鐘；曲線 41 點、H = 0 的那一點；套用的小時與停車端篩選、全天筆數與試算用的筆數；篩選後沒有折返停留；`late`、`hour_range`、`end_go_back` 接受與拒絕的值；末站名稱取最新一天、頁面路線的站序。既有的例子（晚到 0）一個不改。
- `spec/components/buffer_trade_component_spec.rb` 驗證：控制項（兩個拉桿的範圍與值、兩個小時選單、只有兩端都停車時才有的端點選項、hidden 的 `day`、`range`、沒有隱藏的重算按鈕）、`data-rendered`、各個 `data-value`、JSON 的形狀與第 H 點等於伺服器輸出的數字、圖的兩條線各 41 點與目前的點的座標等於 JSON 第 H 點、逐小時的表在預設關閉的 details 裡、篩選後沒有折返停留的說明。
- `spec/requests/routes_spec.rb` 驗證新參數的預設與 400（`late=21`、`late=-1`、`late=abc`、`late[]=1`、`from=10&to=9`、`from=24`、`to=0`、`to=25`、`end=2`、`end=x`、開過去就走那一端的 `end`），以及只有一端停車時 `end` 等於那一端照樣 200。
- 新的 `spec/system/buffer_trade_spec.rb`（`:js`）驗證：移動拉桿後數字等於 JSON 那一點、`data-rendered` 不變、網址換了 `buffer`、`late` 而 `day`、`range` 照留、`history.length` 不變；改套用的小時後 `data-rendered` 變了、網址帶 `from`；移動拉桿、離開再按上一頁，數字是移動後的值。
- 真資料：改動前先記下 15373 與 16111 在 2026-10-22（`range=day` 與 `7d`，`buffer=15`）的數字，不用 10-23、10-24（薔琵颱風減班停駛，資料量只有平日三到四成，不放上網站）；改完後不帶新參數的數字一樣；16111 的「加在哪一端」列出兩個末站，兩端各自的試算筆數加起來等於「兩端」的筆數；記下 `/routes/16111?range=7d` 改動前後的回應大小；390 寬的手機畫面頁面不橫向捲動（既有的 `spec/system/route_page_layout_spec.rb`）。

**Scope boundaries**

- 在範圍內：`RoutePage::BufferTrade`、`BufferTradeComponent`（`.rb`、`.html.erb`、`.yml`）、`RoutesController#show` 的參數、`app/views/routes/show.html.erb` 傳參數、`DataLimitationsComponent` 的文案、`app/frontend/entrypoints/application.js` 的 `bufferTrade`、`docs/spectra/LANGUAGE.md` 的三條。
- 不在範圍內：`analysis/`、衍生表與 migration、`derived:load`、`bin/push-derived`、`bin/health-card`、`config/route_page.yml`、重點數字與區塊導覽、其他區塊的元件、部署。

## Risks / Trade-offs

- [回應變大] → 估的 20 到 35 KB 在驗收時量；超過 60 KB 就照「曲線在伺服器算好寫進回應，休息與晚到的拉桿不送請求」那一條的退路，把逐小時的值拿出 JSON。
- [`replaceState` 跟 Turbo 的瀏覽紀錄打架] → 保留 `history.state`；系統測試走一次「移動、離開、上一頁」。
- [讀者只記住其中一條線] → 兩條線粗細一樣、兩欄數字同樣大小、圖例與 `bounds_note` 說明各自代表什麼。
- [晚到被讀成平常的誤點] → 拉桿下的說明、資料限制與詞彙表都寫明是「比量到的再晚」。
- [單一天的逐小時數字樣本少] → 表收在 details 裡；資料限制照舊寫多派的車數是按小時平均估的。
- [套用的小時被當成載客剖面的時段] → 名稱用「套用的小時」，詞彙表寫明不是 `band`。
- [H 拉到 40 時，下限可能比任何一天真的會排的都高] → 曲線只用量到的折返停留算，沒有推算；40 是介面的範圍。
- [其他 change 動到同一批檔案] → `ui-touchups` 把換休息試算那一塊的 `select-none` 排在這個 change 之後（它的 2.3 等這個 change 的 3.1 到 3.4 與 4.1）；說明文字的行寬它已經先做了，2026-10-24 它的 3.1 拿掉了這一塊 3 處 `max-w-[46em]`，這個 change 新寫的說明照滿版（見 Implementation Contract 的 `BufferTradeComponent`）。暫存的 `01-pass-through-wording` 改 `buffer_trade_component.yml` 的 `pass_through_html` 與詞彙表「換休息試算」條目的用詞；`02-end-nature-survey` 只加詞彙表條目。開工前重看一次（tasks 的第一項），已經 apply 的照它的說法寫，新的重疊先問使用者順序。

## Migration Plan

只換程式，不用重算或推資料。沒有新的網址參數時頁面跟改動前一樣，舊的分享連結照樣能開。要退回就 revert 這個 change 的 commit；退回後網址上多出來的 `late`、`from`、`to`、`end` 會被舊程式忽略，不會 400。
