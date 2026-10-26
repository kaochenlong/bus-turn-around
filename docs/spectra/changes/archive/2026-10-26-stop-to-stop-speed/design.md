## Context

路線頁的行駛時間卡（`RunTimeTableComponent`，讀 `RoutePage::RunTimes`）只報整趟從起站離站到末站到站的時間，按方向與發車小時分。使用者 2026-10-26 討論後要看「哪一段開最慢」，選了：顏色代表車速、一列一個時段、像 GitHub contribution graph 那樣分級的格子、不畫在地圖上。

現況與限制：

- `bus_data`（GPS）只有 `analysis/turnaround_facilities.sql` 讀，它在檔案裡建 `gps_reports`，只留當天有折返停留的車（`BusID IN (SELECT bus_id FROM layovers)`），照 `(BusID, DataTime)` 去重。`derived-tables` 規格寫明「`bus_data` 只由 `analysis/turnaround_facilities.sql` 讀」；02-end-nature-survey 的非目標把「把 `gps_reports` 從 `turnaround_facilities.sql` 拆出來」留給之後的 change，那是那次的範圍限制，不是否決。
- `bin/rails survey:end_natures`（`EndNatureSurveyCommand::EXTRA_FILES`）也跑 `turnaround_facilities.sql`，再接 `end_nature_evidence.sql` 讀 `gps_reports`；它的資料夾指紋包含跑過的 SQL 全文。
- 路線軌跡在衍生表 `route_day_shapes`，分析時由 `analysis/route_shape.sql` 建 `route_shapes`（每個方向一列，`points` 是 `[緯度, 經度]` 的陣列，取到小數 6 位）。點數 2026-10-24 量過，三條路線每個方向 205 到 266 個點（03-route-shape-map 量到的）。
- `derived:load` 現在的順序是程式裡的 `RouteDayLoader#export`：`params.sql`、編號階段、`mrt_overlap.sql`、`turnaround_facilities.sql`、`route_shape.sql`、`depots.sql`、`derived_export.sql`，寫十個 CSV。`derived-tables` 規格的 Derived export 還寫「九個檔」、順序裡沒有 `depots.sql`，是 03-depot-inspection-scores 另外加了 Depot rows stored with the route day、沒回頭改這一條；這次改寫 Derived export 時一起照程式改正。
- 時段的判斷寫在 `analysis/40_load_profile.sql` 的 `trip_bands`（看趟次起點的小時，邊界是 `params.sql` 的 7、9、17、19）。
- 路線頁的圖都由伺服器輸出成內嵌 SVG，不用圖表套件、沒有提示框（route-page-charts 的決定與非目標）。沿線人數圖（`LoadChartComponent`）640 px 以上畫 SVG、以下改成每站一列；行駛時間卡自己有一個 640 px 以下才出現的方向切換。
- 樣本少的門檻是 `RoutePage::RunTimes::SMALL_SAMPLE`（5），行駛時間與來回一趟共用，數字用 `text-orange-700` 標。
- 網站沒有深色模式。色票是 slate 與 teal-700，綠色是假日標籤（covered-day-holiday-chip），紫色是地圖上的靜止格。

2026-10-26 在討論裡量到的數字（中山幹線，備份資料，量到的）：

| 量什麼 | 結果 | 樣本 |
| --- | --- | --- |
| 進站紀錄出現時車離站牌 | p25／p50／p75／p90 是 83／93／99／111 公尺，GPS 時速 p50 28 公里 | 2026-10-22，前後 1 秒內有 GPS 點的 5,551 筆 |
| 離站紀錄出現時車離站牌 | 25／36／52／65 公尺，時速 p50 20 公里 | 同上 5,523 筆 |
| 同一台車相鄰兩個 GPS 點 | 相隔 p50、p90 20 秒，p99 28 到 30 秒；第一次抓到時已過 p50 8、p90 12、p99 15 秒 | 2026-10-22 08 與 17 時，每小時約 2,400 台 |
| 站牌對到路線軌跡 | 最遠 26 公尺（去程）、13 公尺（返程）；軌跡長 16,320 與 16,821 公尺，`GetRoute.gz` 的 `distance` 是 33.2 公里 | 2026-10-22 的快照 |
| 沿線距離 ÷ 直線距離 | 中位數 1.0，最大 6.04（去程「天母→天母」） | 同上 |
| 用到離站時刻 vs 用 GPS 算的時速（去程，早尖峰／白天） | 士林電機→德行 9.0／43.7 vs 6.5／10.6；聯合醫院和平院區→大埔街 9.0／17.4 vs 7.6／13.1；大同公司→台泥大樓 12.2／26.3 vs 9.9／11.3；三玉宮→天母廣場 4.5／7.7 vs 5.1／6.9 | 2026-10-22 一天，GPS 以它自帶的路線與方向篩，約 2.4 萬點 |

## Design Source

- 來源：Claude Design 畫布「站間車速格子圖方案比較」https://claude.ai/artifact/9u6Brmo6LkYFqEYyHUoaLo，畫板「B｜寬螢幕 1280」與「B｜手機 390（同現況）」，2026-10-26 畫的、同一天由使用者選定。數字是中山幹線 2026-10-19 到 22 四個平日合併的實際值（開發資料庫）。同一張畫布上方案 A 的兩張畫板沒有採用。
- 快取：`.spectra/design-cache/stop-to-stop-speed/B-desktop.dc.html`、`.spectra/design-cache/stop-to-stop-speed/B-phone.dc.html`（`.spectra/` 在 `.gitignore` 裡，只存在本機）。
- 稿上的顏色是 Tailwind v4 主題的 OKLCH 值，下表寫對應的 class。標題、說明、圖例、數字表與卡片照現在的實作畫，不改；手機那張是現在的每段一列照畫，也不改。

| 元素 | 值 |
| --- | --- |
| 格子 | 18 × 18 px、圓角 4 px；橫向與縱向的縫都是 3 px，一格的間距 21 px；有顏色的格子 teal-200／400／600／800，樣本少與量不到是白底加 1 px slate-300 外框 |
| 時段名 | 13 px、slate-600、靠右，欄寬 46 px，離格子 6 px（格子從 x = 52 開始），跟每一列垂直置中 |
| 路線 | 格子下面 12 px 起是站點；一條 2 px slate-300 的橫線穿過每個站點的中心，從第一站畫到最後一站 |
| 站點 | 外徑 10 px（2 px 外框）；中間的站白底、外框 slate-400；第一站與最後一站實心 slate-600；中心在前後兩格之間那道縫的中心，第 i 站（從 0 起）在 x = 52 + 21 × i − 1.5 |
| 站名 | 直書（`writing-mode: vertical-rl`，中文直立，括號與斜線轉 90 度），14 px、slate-700；跟站點同一個 x，從站點下緣往下 8 px 開始 |
| SVG 的寬 | 52 + 段數 × 21 + 6 px：中山幹線去程 45 段是 1,003 px，放得進卡片內寬 1,006 px；307 去程 65 段是 1,423 px，比框寬，照舊橫向捲動 |
| SVG 的高 | 站名從格子下緣往下 30 px 開始，高度照最長的站名算（字數 × 14 px） |
| 圖例 | 不變：色塊 14 px、圓角 3 px |
| 手機（640 px 以下） | 不變：每段一列，「起站 → 迄站」15 px slate-700；四個方塊 20 px、圓角 3 px、間隔 4 px；上面一列寫時段簡稱，13 px slate-500；列與列之間 1 px slate-100 |

## Goals / Non-Goals

**Goals:**

- 定義站間車速：每趟在每個兩站之間開了幾公尺、幾秒，由 GPS 沿登記的路線軌跡量，存進衍生表。
- 路線頁行駛時間卡的表格下面，每個方向一張四列的格子圖，看得出哪兩站之間慢、慢在哪個時段。
- GPS 的讀取拆成共用的檔，折返點設施與折返點性質試跑的數字不變。

**Non-Goals:**

- 改行駛時間、折返停留、來回一趟、週期的定義；到離站位置對它們的影響另開 change 量，`docs/decisions.md` 第 13 條照舊。
- 地圖、單一車牌的 GPS、提示框、用顏色或門檻判好壞（03-route-shape-map、turnaround-map、route-page-charts 的非目標照舊）。
- 「比平常多花幾秒」、倍數、一小時一列（使用者選了車速與四個時段）。
- 成員路線的趟次、站上停靠的時間、跨路線比較、健檢卡、月報、TDX 的站間旅行時間（02-route-307-page 的決定「TDX 站間旅行時間只做內部對照」）。
- 讓 GPS 的對位知道趟次的前進方向（例如只往前找）；這次每一筆獨立對到最近的線上，靠後面的條件把對錯的組濾掉。

## Decisions

### 車速從 GPS 算，不用到離站時刻

站間車速 = 落在這兩站之間、被算進來的 GPS 組，公尺加總 ÷ 秒數加總。不用「這站離站到下一站進站」：Context 的表顯示進站紀錄出現在站前約 90 公尺、離站紀錄在站後三十幾公尺，兩個時刻之間只涵蓋站距扣掉一百多公尺，除以站距會把車速算大，段越短越嚴重（士林電機→德行白天 43.7 對 10.6 公里）。

替代方案：用到離站時刻、距離改成「站距扣掉兩端的觸發距離」（每站的觸發距離不同，量不準，否決）；用 GPS 自帶的 `Speed` 欄位取平均（點不是等時間間隔，到離站時車機會多報一點，平均會偏向站旁的速度，否決）；只用使用者沒選的「比平常多花幾秒」（使用者選了車速）。

### 站牌照站序對到路線軌跡上，存成 route_day_stops.shape_meters

頁面路線每個方向的站牌，照 `seqNo` 由小到大一個一個對到那個方向的路線軌跡上，得到「從軌跡起點沿線走幾公尺」。每一站只在前一個有位置的站牌之後的線上找最近的點；最近距離 15 公尺內（`stop_tie_meters`）的候選都算平手，取沿線最前面的那個，所以路線繞回來、同一條路走兩次時，站牌落在先經過的那一次。最近距離超過 50 公尺（`shape_snap_meters`）的站牌沒有位置，下一站接著從最後一個有位置的站牌之後找。位置存成 `route_day_stops.shape_meters`（公尺，一位小數）；成員路線的站牌、當天沒有路線軌跡的方向都是空的。

「兩站之間」是同一方向相鄰兩個有位置的站牌之間，用前一站的 `seq` 代表；中間有站牌沒有位置時，就跨過它。

座標換成平面公尺：`y = R × 緯度弧度`、`x = R × 經度弧度 × cos(這個方向軌跡各點緯度平均的弧度)`，`R` 是 6,371,000 公尺，跟 `mrt_overlap.sql` 的 `haversine_meters` 同一個地球半徑。一條路線南北不到 0.2 度，餘弦的變化不到千分之一，忽略。

替代方案：每一站各自找全線最近的點（路線繞回來時會跳到後面那一次，站序就亂了，否決）；在 Ruby 裡算（GPS 只在 DuckDB 裡，站的位置也要在那裡才能分段，否決）；用 PostGIS 或 DuckDB spatial（`docs/decisions.md` 第 3 條說 spatial 擴充可以用，但現有的 SQL 都沒有載它，為一個投影多一個擴充不划算；平面公式在這個尺度夠準，否決）。

### GPS 一組的中點決定歸哪兩站之間，站的前後 40 公尺不算

每一趟取那台車在趟次起點到終點（含兩端）之間的 `gps_reports`，每一筆對到那個方向軌跡上最近的點（全線找，距離相同取沿線前面的），離線超過 50 公尺的不算。剩下的照時間排，相鄰兩筆是一組；一組算進來要同時滿足：相隔超過 0 秒、不超過 40 秒（`pair_max_seconds`）；沿線往前（後一筆的位置不小於前一筆）；每秒不超過 25 公尺（`pair_max_meters_per_second`）。一組的中點（兩筆位置的平均）落在哪兩站之間就歸那裡，中點離這兩站任一站不到 40 公尺（`stop_zone_meters`）的不算，落在第一站之前或最後一站之後的也不算。

40 秒是 GPS 一般 20 秒一點、p99 到 30 秒，容得下漏一個點；超過就是中間沒有回報，看不到那段怎麼開的。25 公尺是時速 90 公里，比這幾條路線任何一段都快，快過它的是對錯了線。40 公尺是車減速進站、停車、起步出站的範圍：離站紀錄出現在站後 36 公尺（中位數）是參考，不是量出來的門檻，所以寫成常數。這樣兩站之間只量路上開的那一段，不含進出站與上下客；兩站相距 80 公尺以內的量不到。

替代方案：跨兩站的組按比例拆到兩邊（車在站旁怎麼停看不到，拆了也不準，中點落在站旁的本來就不算，否決）；不扣站的前後（停靠上下客會算成路上慢，跟使用者要的「開最慢」不是同一件事，否決）；用站與站之間每一筆 GPS 的速度欄位（見上一條）。

### 時段看車開進這兩站之間的時刻，邊界跟載客剖面同一組

每趟每個兩站之間一列，時段取那一列第一組的前一筆回報的台北時刻，邊界跟 `load-profile` 的時段相同：7 點到 8 點 59 分是早尖峰、9 點到 16 點 59 分是日間、17 點到 18 點 59 分是晚尖峰、其餘是其餘。邊界抽成 `params.sql` 的 macro `time_band(ts)`，`40_load_profile.sql` 的 `trip_bands` 改用它，健檢卡的輸出不變。

不照整趟的發車時刻分：一趟要跑一個多小時，06 時 50 分發車的車有一半在早尖峰的路上跑，照發車時刻會把它算進其餘（02-route-307-page 拿 TDX 對照時就看到這個偏差）。代價是這張圖的時段跟沿線人數圖不是同一種分法，格子圖的說明寫明「看車開到這一段的時刻」。

### 起點只有到站時刻的趟次不算，有成員路線時只算頁面路線的趟次

`start_from_arrival` 為真的趟次，起點是到站時刻，那之後車可能還停在起站前後等發車，趟次的時間窗會把等的時間包進去，整趟不算；其他完整與不完整的趟次都算，因為只要那一段有 GPS 組就量得到。`end_from_departure` 為真的趟次照算：它結束在末站的離站，停站那一段在 40 公尺內本來就不算。

成員路線（`trips.route_id` 不是頁面路線）不算：路線軌跡是頁面路線的，成員的車在走法不同的地方會離線或對錯段。307 一頁兩個 Id 時，站間車速只有 16111 的車；資料限制的成員那一條寫明。

### gps_reports 拆成共用的 analysis/gps_reports.sql，留當天有趟次的車

新檔 `analysis/gps_reports.sql` 接手 `bus_data_files` 與 `gps_reports`，讀法、欄位、去重都不變，留的車改成「當天有趟次的車」（`BusID IN (SELECT bus_id FROM trips)`）。有折返停留的車一定有趟次，`standstill_records` 與 `end_nature_evidence.sql` 都是跟 `layovers` 接著用，多留的車不會被讀到，所以折返點設施與試跑的數字不變。`turnaround_facilities.sql` 不再讀 `bus_data`；`derived:load` 與 `bin/rails survey:end_natures` 都在 `mrt_overlap.sql` 之後、`turnaround_facilities.sql` 之前跑它。試跑的指紋包含 SQL 全文，所以下次試跑會把每個路線日重跑一次。

替代方案：在 `stop_speeds.sql` 再讀一次 `bus_data`（同一批檔讀兩次，一天多讀兩三百 MB 的壓縮檔，規格也要改成兩個檔都能讀，否決）；把站間車速寫進 `turnaround_facilities.sql`（兩件不相干的事綁在一個檔，否決）。

### 衍生表存每趟每個兩站之間的公尺與秒數，彙總在讀頁面時算

照 zhongshan-route-page 的決定「衍生表存逐趟資料，彙總在讀頁面時用 SQL 算」：新表 `trip_stop_speeds` 每趟每個有算進來的兩站之間一列（`trip_id`、`seq`、`band`、`meters`、`seconds`），跟 `trip_stop_counts` 一樣用車牌與起點時刻在載入時接回 `trips`。頁面把涵蓋日子的列按方向、`seq`、時段加總公尺與秒數，再除。存公尺與秒數、不存時速，因為好幾天合起來的車速要用總距離除總時間，不能把每天的時速平均。

替代方案：只存每個路線日的彙總（頁面的「最近 7 天」要從原始數字合，否決）；存每一組 GPS（一天一個方向就兩萬多列，頁面用不到這麼細，否決）。

### 格子圖放在行駛時間卡的表格下面，一列一個時段

新元件 `StopSpeedGridComponent` 放在 `app/views/routes/show.html.erb` 的 `CardComponent.new(id: "runtimes")` 裡、`RunTimeTableComponent` 之後，區塊導覽不變。標題「哪一段開最慢？」，說明寫：越深越慢；時段看車開到這一段的時刻；站的前後 40 公尺不算，所以不含進出站與上下客；數字在下面的表。

每個方向一張 SVG：四列照早尖峰、日間、晚尖峰、其餘排，一格是一個兩站之間，照站序由左到右；格子是圓角方塊，之間留縫（GitHub contribution graph 的樣子）；格子下面一條路線、每一站一個點，站名直書在點的下面，每一站都寫（大小與寫法見「站名直書，掛在格子下方的路線上」與 Design Source）；SVG 比框寬時橫向捲動，跟沿線人數圖一樣。不畫在地圖上（使用者 2026-10-26），也不跟沿線人數圖共用一張圖。

替代方案：一列一個小時（19 列太高、當天每格只有 3 到 5 趟、手機一列要擠 19 格，使用者選了四個時段）；放進載客那張卡（載客卡講的是人，這張講的是時間花在哪，跟行駛時間同一件事）。

### 站名直書，掛在格子下方的路線上

第一版照上一條做：格子 14 px、縫 2 px，站名斜 60 度寫在交界下面。2026-10-26 使用者看了 1280 px 寬的截圖說不好看：相鄰兩站只隔 16 px，斜寫之後相鄰兩行字的距離是 16 × sin 60° ≈ 13.9 px，12 px 的字之間幾乎沒有空隙，站名那一塊也比格子還高。之後在 Claude Design 畫布（見 Design Source）用中山幹線的實際數字畫了兩個方案，使用者選了 B：

- 格子放大到 18 px、縫 3 px、圓角 4 px，一格的間距 21 px，四列照舊。中山幹線去程 45 段，SVG 寬 1,003 px，放得進卡片的內寬 1,006 px。
- 格子下面一條線，每一站一個點，起訖兩站實心；站名直書（中文直立，括號與斜線轉向）掛在點的下面，像臺北公車站牌上的路線圖。相鄰兩個站名的字之間隔 7 px（間距 21 px、字 14 px）。
- 640 px 以下照舊每段一列，不改。

站名照舊是 SVG 的 `text`，加 CSS `writing-mode: vertical-rl`，不拆字、不換成 HTML，路線頁的圖照舊都是伺服器輸出的內嵌 SVG。MDN 的相容性資料：`writing-mode` 的 `vertical-rl` 在 Chrome 48、Firefox 43、Safari 9 起支援，只給 SVG 用的舊值 `tb`、`tb-rl` 在 Chrome 48、Firefox 43、Safari 10.1 起支援。

替代方案：方案 A，時段改成四欄、一站一行、站名橫寫、兩個方向並排（站名最好讀，手機與寬螢幕同一種版面，但中山幹線一個方向就有 1,000 多 px 高，使用者選了 B）；斜角加大到 70 到 75 度（相鄰兩行字的距離只多約 1.5 px，還是同一個問題）；只寫部分站名、其餘看表（每一站都要寫，否決）；把字一個一個往下排（括號與斜線不會轉向，否決）。

### 深淺四級照每公里秒數佔這個方向最慢那一格的比例分，圖例寫每級的時速範圍

每一格的「每公里秒數」是秒數加總 ÷ 公尺加總 × 1000。同一個方向裡，樣本夠的格子取最慢那一格的每公里秒數 `P`；每一格的級數是 `⌈4 × 每公里秒數 ÷ P⌉`，1 到 4，越大越深，所以第 k 級是每公里秒數落在 `P` 的 `(k−1)/4` 到 `k/4`（含上界）。用有理數比，不用浮點數，剛好落在邊界的值歸較淺的那一級。這是折返點地圖靜止格「四級深淺照佔最大格的比例」（turnaround-map 的決定）的同一套做法，換成「越慢越深」。

圖例在兩個方向的格子圖上方，只有一份：「快」、四個色塊、「慢」，色塊跟格子同樣子。每一級的時速範圍因方向而不同，所以寫在每個方向自己的格子圖上面一行，用那個方向最慢那一格的時速 `v` 算：最淺 `4v` 以上、再來 `2v` 到 `4v`、再來 `4v/3` 到 `2v`、最深 `4v/3` 以下，一位小數。例如最慢 5.0 公里時是 20.0 以上、10.0 到 20.0、6.7 到 10.0、6.7 以下。深淺只比同一個方向，不同方向、不同路線不能比，說明裡寫明這一點，也不寫「塞車」。

四級用同一個色相 teal 由淺到深：Tailwind v4 的 teal-200、teal-400、teal-600、teal-800（OKLCH 亮度約 91、78、60、44，單調遞減）。dataviz skill 對單一色相漸層的檢查是亮度單調，不跑分類色的驗證器；網站沒有深色模式，所以只做淺色。不用綠（假日標籤）、不用紫（靜止格），也不用紅或琥珀（會讀成警示）。

替代方案：固定的時速級距（例如 10、15、20 公里）（慢的路線整張一個顏色、快的路線也一個顏色，看不出這條線哪裡慢，否決）；四分位數分級（差一點點也會被拉成不同級，否決）；連續漸層（GitHub 與靜止格都是分級，分級才讀得出「最深那幾格」，否決）。

### 樣本少與量不到的格子只畫外框，不填色

格子有三種：有顏色（樣本至少 5 趟）、樣本少（1 到 4 趟）、量不到（0 趟，含兩站相距 80 公尺內與那個時段沒有車）。後兩種都只畫 slate-300 的外框、裡面是白色，跟最淺的 teal-200 分得開；樣本少的格子不參與「最慢那一格」。GitHub 最淺的灰格代表 0 次，這裡的空格代表不知道，所以不能用最淺的顏色畫。樣本少的門檻用 `RoutePage::RunTimes::SMALL_SAMPLE`，跟行駛時間、來回一趟同一個。

### 數字放在預設收起的表裡，不加提示框

格子圖下面一個預設收起的 `details`：一列一個兩站之間（「起站 → 迄站」、沿線距離幾公尺），四欄時段，每格寫時速（一位小數）與幾趟；樣本少的格子用 `text-orange-700` 加螢幕報讀的「樣本少」，跟行駛時間表一樣；量不到的寫「—」。兩個方向各一張表。

dataviz skill 預設每一格要有滑鼠移上去的提示框，這裡不做：route-page-charts 的非目標「互動提示框、縮放、動畫，或任何 JS 圖表套件」還在，網站上其他圖也都沒有；skill 要求的表格視圖就是這張表。

### 窄螢幕一次一個方向、一段一列、後面四個小方塊

640 px 以下不畫 SVG，改成每個兩站之間一列：前面是「起站 → 迄站」，後面四個小方塊依序是四個時段，方塊的顏色與外框規則跟 SVG 一樣，上面一列寫四個時段的簡稱。一次只看一個方向，預設去程，切換按鈕跟行駛時間卡的樣子相同、只改頁面上的狀態、不改網址；這個區塊自己一個切換，不跟行駛時間表的切換連動（沿線人數圖也是各自一個）。沒有 JavaScript 時切換按鈕藏著（`x-cloak`），兩個方向的列都在、沒有藏起來的樣式。

### 涵蓋的日子都沒有站間車速時，一句話講兩種原因

涵蓋的日子裡，頁面路線的趟次沒有任何 `trip_stop_speeds` 列時，這一塊只留標題與一句話：涵蓋的日子沒有站間車速，可能是那幾天在加上站間車速之前載入、要重新載入，也可能是那幾天的快照沒有路線軌跡。不多存一個欄位去分這兩種原因：前一種在正式站重算之後就不會出現，後一種很少見。有資料、但其中一個方向沒有（例如那個方向沒有軌跡）時，那個方向的位置寫「這個方向沒有站間車速」。

### 詞彙表新增「站間車速」，decisions.md 第 13 條補一筆

`docs/spectra/LANGUAGE.md` 的「指標」新增「站間車速」一條：定義、在資料或程式碼裡、邊界（不用到離站時刻的理由與 Context 那張表、時段看開進那一段的時刻、哪些趟次不算、80 公尺內量不到、軌跡是登記的）、不要用（站間旅行時間是 TDX 推估的時間、路段是捷運重疊的連續站、熱力圖是載客剖面不要用的說法、塞車指數、旅行速率）。程式識別字裡的「兩站之間」叫 leg 或用 `seq` 代表，不叫 segment，因為 `analysis/20_trips.sql` 的 `segment_no` 已經是切趟用的段。

`docs/decisions.md` 第 13 條結尾補一段（2026-10-26）：站間車速改用 GPS 沿路線軌跡量，因為到離站紀錄出現在站前約 90 公尺與站後三十幾公尺；行駛時間與折返停留照舊從到離站事件算。路線頁的格子圖說明、資料限制那一條、詞彙表三處說同一件事：GPS 沿登記的路線、站的前後 40 公尺不算、起點只有到站時刻的趟次不算、只算頁面路線的車。

### Derived export 的檔案清單照程式補上 depots

改寫 `derived-tables` 的 Derived export 時，順序照 `RouteDayLoader#export` 實際的樣子寫進 `analysis/depots.sql`，檔案清單寫十一個（原本十個加 `stop_speeds.csv`），Scenario「Nine files written」改成列出全部的檔。這是補 03-depot-inspection-scores 沒改到的地方，不是新的行為。Replace one route day atomically 的「九個檔」這次不改：照 depots 的前例，新表的刪除與同一個交易寫在新增的 Stop speed rows stored with the route day 裡，那一條的過時字樣留給之後整理那一條的 change。

## Implementation Contract

**`analysis/params.sql`** 新增常數與 macro，其他 SQL 檔不寫這些字面數字：

| 名字 | 值 | 用在 |
| --- | --- | --- |
| `shape_snap_meters` | 50 | 站牌與 GPS 離軌跡多遠以內才對得上 |
| `stop_tie_meters` | 15 | 站牌對位時算平手的距離差 |
| `stop_zone_meters` | 40 | 站的前後不算的距離 |
| `pair_max_seconds` | 40 | 一組兩筆最多隔幾秒 |
| `pair_max_meters_per_second` | 25 | 一組最快每秒幾公尺 |
| `time_band(ts)` | macro | 回 `morning_peak`、`daytime`、`evening_peak`、`other`，邊界是既有的四個小時常數 |

**`analysis/gps_reports.sql`**（名字不以數字開頭，`bin/health-card` 不跑）：讀第 10 階段的 `day_files`、`window_start`、`window_end` 與第 20 階段的 `trips`，建 `bus_data_files` 變數與 `gps_reports`（`bus_id`、`latitude`、`longitude`、`speed`、`data_time`），去重與現在的 `turnaround_facilities.sql` 相同。整個 repo 只有這個檔讀 `bus_data`。

**`analysis/stop_speeds.sql`**（不以數字開頭）：在 `route_shape.sql` 與 `depots.sql` 之後、`derived_export.sql` 之前跑，讀 `route_id`、`stops`、`trips`、`gps_reports`、`route_shapes`，建：

- `stop_positions`：頁面路線每個方向每個站牌一列，`go_back`、`seq`、`shape_meters`（沒有位置是 NULL）。
- `trip_stop_speeds`（view，讀 `gps_reports` 時才查，測試可以先換掉 `gps_reports`）：`trip_id`、`bus_id`、`start_time`、`go_back`、`seq`、`band`、`meters`、`seconds`，每趟每個兩站之間最多一列，沒有組算進來的不出列。`meters` 是加總後四捨五入到一位小數，`seconds` 是整數。

GPS 對位只拿外框範圍（線段兩端點的範圍各往外放 50 公尺）裡的線段算距離，結果跟全線算相同。

**`analysis/derived_export.sql`**：`stops.csv` 最後多一欄 `shape_meters`（一位小數，沒有位置時空白）；新檔 `stop_speeds.csv`，欄位 `bus_id,start_time,seq,band,meters,seconds`，照 `bus_id`、`start_time`、`seq` 排，時刻帶 `+08:00`。

**資料庫**：

- `trip_stop_speeds`：`trip_id`（外鍵 `trips`，`on_delete: :cascade`）、`seq` integer、`band` string、`meters` float、`seconds` integer，全部必填，唯一索引 `(trip_id, seq)`。
- `route_day_stops.shape_meters` float，可空。
- `TripStopSpeed belongs_to :trip`；`Trip has_many :stop_speeds, class_name: "TripStopSpeed", dependent: nil`（刪除靠資料庫的 cascade，跟 `trip_stop_counts` 一樣）。`bin/push-derived` 照外鍵自己找到新表，不用改。

**`RouteDayLoader`**：`AnalysisRun.run` 的 `extra_files` 是 `mrt_overlap.sql gps_reports.sql turnaround_facilities.sql route_shape.sql depots.sql stop_speeds.sql derived_export.sql`；`STAGING` 多 `stop_speeds`（`bus_id text, start_time timestamptz, seq integer, band text, meters double precision, seconds integer`）、`stops` 多 `shape_meters double precision`；`insert_stops` 寫 `shape_meters`；新的 `insert_trip_stop_speeds` 用 `(bus_id, start_time)` 接 `trips`，照 `insert` 的寫法檢查列數；回傳的計數多 `trip_stop_speeds`。`RouteDayLoader.summary` 那一行不改。

**`EndNatureSurveyCommand::EXTRA_FILES`**：`mrt_overlap.sql gps_reports.sql turnaround_facilities.sql end_nature_evidence.sql end_nature_export.sql`。

**`RoutePage::StopSpeeds.new(route_days)`**（頁面傳給其他區塊的同一個 relation）：

- `available?`：涵蓋日子裡頁面路線的趟次有沒有任何 `trip_stop_speeds` 列。
- `directions`：方向 0 與 1 各一個，`go_back`、`legs`（沒有 leg 時是空的）、`level_ranges`（那個方向最慢那一格的時速算出的三個邊界，沒有夠樣本的格子時是空的）。
- 每個 leg：`seq`、`from_name`、`to_name`、`meters`（取涵蓋日子裡、那個方向有站牌帶 `shape_meters` 的最新一天，頁面路線的 `route_day_stops` 相鄰兩個有位置的站牌相減），以及四個時段各一格：`kmh`（一位小數，沒有列時 nil）、`n_trips`、`small_sample`、`level`（1 到 4，樣本少或沒有列時 nil）。
- 列按 `go_back`、`seq`、`band` 加總，`seq` 對不到那一天的 leg 的列不算。查詢固定，不隨方向或天數增加，Bullet 不報 N+1。

**`StopSpeedGridComponent.new(stop_speeds:)`**（`bin/rails g view_component:component StopSpeedGrid stop_speeds --locale` 產生，`.rb`、`.html.erb`、`.yml` 同一層）輸出：

- `section[data-section="stop-speeds"]`，Alpine `x-data="{ direction: 0 }"`；eyebrow「站間車速」、`h2`「哪一段開最慢？」、說明一段。
- 圖例 `[data-stop-speed-legend]`：「快」、四個 `[data-legend-level="1"…"4"]` 色塊、「慢」，兩個方向共用一份。
- 每個方向 `[data-direction="0|1"]`：有夠樣本的格子時，一行 `[data-level-ranges]` 寫那個方向四級的時速範圍；640 px 以上的 `figure` 裡一個 `svg`，每格一個 `rect[data-seq][data-band]`，有顏色的帶 `data-level`，樣本少的帶 `data-small-sample`，量不到的帶 `data-no-speed`；格子下面一條線，每一站一個 `circle[data-stop-mark]`，站名是直書的 `text[data-stop-label]`，跟站點同一個 x、照站序，尺寸照 Design Source；640 px 以下的 `[data-leg-row][data-seq]`，每列四個 `[data-band]` 方塊，屬性同上。
- `details[data-stop-speed-table]`（不帶 `open`）：每個方向一張表，`tr[data-seq]`，每格 `td[data-band]`。
- 方向切換 `[data-direction-switch]`，跟 `RunTimeTableComponent` 同樣的按鈕與 `x-cloak`。
- 沒有資料：只輸出標題與 `p[data-no-stop-speeds]`；某個方向沒有 leg：那個方向的位置輸出 `p[data-no-stop-speeds-for]`。
- 回應裡沒有任何車牌。
- 字在 `stop_speed_grid_component.yml` 的 tw、zh-TW、en。

**資料限制**（`app/components/data_limitations_component.yml` 的 tw、en）：`items` 多一條，講站間車速是同一台車相鄰兩筆 GPS 沿臺北市公共運輸處登記的路線軌跡量的、站的前後 40 公尺不算所以不含進出站與上下客、兩站相距 80 公尺以內量不到、起點只有到站時刻的趟次不算、深淺只比同一個方向；`member_item` 在「沿線載客圖、捷運重疊與站序只用 %{page_id} 的站序」那一句之後補「站間車速只算 %{page_id} 的車」。

**範圍內**：上面列的 SQL、衍生表、載入、試跑的檔案順序、頁面區塊、資料限制、詞彙表、decisions.md、data-sources.md 裡講誰讀 `bus_data` 的那一句、`analysis/README.md`。**範圍外**：行駛時間、折返停留與其他既有指標的定義、健檢卡、地圖、其他頁面、正式站的部署與重算（使用者自己跑）。

**驗收**：`bundle exec rspec spec/analysis spec/models spec/components spec/requests spec/system` 全過；`bin/rubocop` 對新增與修改的 Ruby 檔沒有 offense；`bin/ci` 全綠；真資料驗收照 tasks 的最後一節。

## Risks / Trade-offs

- [GPS 對到別的一段線，例如路線繞回來或同一條路來回] → 每一筆各自找最近的線，可能對錯；對錯的多半變成往回走或快得不合理，那一組不算。驗收時看中山幹線去程「天母→天母」（沿線是直線的 6.04 倍）那一帶的列數與時速合不合理。2026-10-26 驗收：那一段沿線 169.5 公尺，2026-10-22 早尖峰 3 趟 24.7 公里、日間 30 趟 22.3 公里、晚尖峰 5 趟 15.0 公里、其餘 15 趟 23.4 公里，量級合理，沒有看到對錯段的跡象。
- [登記的路線軌跡舊、少列或跟實際走法不同] → 站的位置與兩站距離跟著錯；臨時改道時離線超過 50 公尺的點不算；當天沒有軌跡的方向沒有站間車速。資料限制寫明軌跡是登記的。
- [樣本少] → 只看當天時，早尖峰一個方向每格約 5 到 7 趟（估計：2026-10-22 用到離站量到的兩站之間趟數），去程扣掉起點只有到站的約三成會更少；最近 7 天約多五倍。樣本少的格子只畫外框，表裡標樣本少。驗收時數當天與最近 7 天有顏色的格子各幾格。2026-10-26 驗收（中山幹線 2026-10-22，量到的）：只看當天，去程早尖峰每格只有 4 趟，所以早尖峰那一列幾乎都是外框；有顏色的格子去程 134／180、返程 163／176。最近 7 天（同類型的 4 個平日）是 176／180 與 175／176。
- [深淺是相對的] → 一條很快的路線最慢那一格也是最深；不同方向、不同路線不能比。圖例寫每一級的時速範圍，說明寫只比同一個方向。
- [40 公尺與 15 公尺是判斷，不是量出來的] → 都在 `params.sql`，要改只改一處；驗收時對照討論那天的試算（兩種扣法排名相近）。2026-10-26 驗收：中山幹線 2026-10-22 去程士林電機→德行、聯合醫院和平院區→大埔街、大同公司→台泥大樓、三玉宮→天母廣場四段的日間時速是 9.4、13.7、12.4、5.8 公里（各 30 到 33 趟）；討論那天沒扣站旁、照 10 到 15 時算的是 10.6、13.1、11.3、6.9，量級相同，最慢的仍是三玉宮→天母廣場。
- [一筆 GPS 對位的計算量] → 點數 × 線段數，中山幹線一個方向一天約 2.4 萬點（量到的，以 GPS 自帶的路線與方向篩）× 二、三百段（估計，照 03-route-shape-map 量到的點數），先用外框範圍篩掉大部分；驗收時量 `derived:load` 一個路線日多花多久。2026-10-26 驗收：中山幹線 2026-10-22 的分析跑到 `depots.sql` 為止 3.4 秒、加上 `stop_speeds.sql` 與匯出 3.8 秒（各量兩次），多 0.4 秒以內；`bin/rails derived:load` 一個路線日含 Rails 開機 5 到 10 秒（307 最慢）。`trip_stop_speeds` 一個路線日的列數：中山幹線平日 5,318 到 5,721（proposal 估 7,600，扣掉起點只有到站的趟次與量不到的兩站之間之後比較少）、10-25 假日 3,423，251 約 3,900，251區 約 4,400 到 4,600，307 約 24,000 到 25,600。
- [回應變大] → 估計 30 到 60 KB 未壓縮（兩個方向 × 約 45 個兩站之間 × 4 格的 SVG、窄螢幕的列、兩張表）；驗收時量 fixture 日與中山幹線最近 7 天的回應大小。2026-10-26 驗收（`bin/dev`，量到的）：估計低了四到六倍。中山幹線最近 7 天這一塊 235 KB 未壓縮、gzip 後 16 KB，整頁從 505 KB 變成 741 KB（gzip 後 48 KB 變 63 KB）；307 這一塊 332 KB。同一份數字畫了三次（格子圖、窄螢幕的每段一列、數字表），每一格都帶 class 與 data 屬性。正式站由 Thruster 壓縮回應，傳輸只多十幾 KB，但瀏覽器要解析的 DOM 多了將近一半。fixture 日開發資料庫沒有，沒量。改成直書之後每一站多一個點與一條線，2026-10-26 重量（量到的）：中山幹線最近 7 天這一塊 247 KB、gzip 後 16.6 KB，整頁 752 KB（gzip 後 64 KB）；307 這一塊 348 KB、gzip 後 22.2 KB，比第一版各多約 5%。
- [直書的站名靠瀏覽器支援 SVG 的 `writing-mode`] → MDN 記載三家瀏覽器都支援（見「站名直書，掛在格子下方的路線上」）。站名直書的寫法、跟站點對齊與彼此不重疊都是單一畫面的版面，照 TDD 的測試範圍規則不寫成測試；2026-10-26 在 headless Chrome 1400 px 寬量過一次（量到的）：中山幹線與 307 最近 7 天的四張圖，每個站名都是高大於寬、在自己的站點下面、中心跟站點差 0 px，相鄰兩個站名的外框最少隔 4 px（外框 17 px 寬，含字的左右留白）。Safari 與 Firefox 沒有量，驗收時由使用者在 Safari 看一次寬螢幕的格子圖。
- [長路線要橫向捲動] → 間距固定 21 px，307 去程 65 段的 SVG 寬 1,423 px（算出來的），比卡片內寬 1,006 px 寬，橫向捲動；第一版 307 的 SVG 寬 1,183 px（量到的），一樣要捲。
- [試跑的指紋改變] → `gps_reports.sql` 與改過的 `turnaround_facilities.sql` 讓下次 `survey:end_natures` 每個路線日都重跑一次，只花時間、數字不變。

## Migration Plan

1. migration 建 `trip_stop_speeds`、加 `route_day_stops.shape_meters`（可空，不回填）；回滾就是反向的 migration，其他表不受影響。
2. 開發資料庫：對已經載入的日子重跑 `bin/rails derived:load`（四條有路線頁的路線）。
3. 正式站（使用者自己跑）：照平常的方式部署，容器啟動時的 `bin/rails db:prepare` 會跑這個 migration；Mac mini 的 checkout 更新到同一版（`bin/nightly-load` 寫入前會比對正式站的 `schema_migrations` 與 checkout 的 migration 檔，不一致就不寫），再跑 `bin/nightly-load --recompute`，讓已經在正式站的路線日都重算一次。重算之前，那些日子的頁面會出現「沒有站間車速」那句話，其他區塊照常。
