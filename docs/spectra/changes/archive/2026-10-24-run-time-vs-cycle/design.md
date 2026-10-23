## Context

路線頁 `/routes/:route_id` 現在依序是頁首、重點數字、區塊導覽，然後五張卡：折返停留（圖與表）、換休息試算、行駛時間、載客剖面（圖、捷運重疊、表）、資料限制（決策「區塊依指標分組：同一個指標的圖與表放進同一張卡」，02-route-page-mobile-first）。每一塊是 `app/models/route_page/` 下的一個查詢物件配一個 ViewComponent，查詢物件拿 `RoutePage::Coverage#route_days` 回的那幾天，在讀頁面時用 PostgreSQL 的 SQL 彙總衍生表，百分位數用 `percentile_cont` 線性內插、一位小數（`RoutePage::RunTimes`、`RoutePage::LayoverStats`）。

已核對的事實（讀程式與 2026-10-23 的查詢）：

- `trips` 每列有 `route_day_id`、`bus_id`、`go_back`、`start_time`、`end_time`、`completeness`（`complete`、`missing_start`、`missing_end`、`missing_both`）、`start_from_arrival`、`end_from_departure`；`(route_day_id, bus_id, start_time)` 唯一。
- `layovers` 每列有 `route_day_id`、`bus_id`、`go_back`（本趟的方向）、`end_time`（本趟末站到站）、`next_start_time`（下一趟的 `start_time`）。`analysis/30_layovers.sql` 的 `layover_pairs` 用 `lead(start_time)` 配同一台車的下一趟，只有本趟有到末站（`complete` 或 `missing_start`）、下一趟從起站出發（`complete` 或 `missing_end`）、兩趟之間沒有跑別的路線、差值不為負的配對才進 `layovers`。所以 `layovers` 的一列就是「同一台車相鄰兩趟、中間沒去跑別條線」的證明，`end_time` 對得到本趟的 `trips.end_time`，`next_start_time` 對得到下一趟的 `trips.start_time`。
- `RoutePage::Ends` 從 `config/route_page.yml` 讀兩端的性質，鍵是結束在那一端的趟次方向：15373、10712、11764 都是 `0: pass_through`、`1: stop`，測試路線 9001 兩端都是 `stop`。
- `RoutePage::RunTimes` 只算 `completeness = 'complete'` 且 `start_from_arrival`、`end_from_departure` 都為假的趟次，`SMALL_SAMPLE = 5`，按方向與起點的台北小時分組。
- `RunTimeTableComponent` 在 640 px 以下用 Alpine 的 `x-data="{ direction: 0 }"` 一次只看一個方向，沒有 JS 時兩個方向都在；`SectionNavComponent::SECTIONS` 是 `%w[layovers buffer runtimes load mrt limits]`，同層 `.yml` 給每個連結的文字；`CardComponent.new(id:)` 的 `id` 就是區塊導覽的 fragment。
- `spec/requests/routes_spec.rb` 用 `page.css("[data-section]")` 斷言區塊順序、用 `nav[data-section-nav] a` 斷言六個連結各對到包住那一區的元素。
- 停車端的離站事件常漏。中山幹線 2026-10-19 到 10-22 四個平日（量到的）：去程 341 趟、完整 249 趟，其中 93 趟的起點是到站時刻（`start_from_arrival`），返程 333 趟裡終點是離站時刻的 0 趟。起點是到站時刻的完整去程趟次，行駛時間中位數 74.6 分鐘，起點是離站的 71.9 分鐘，差 2.7 分鐘：車到了起站很快就發車，漏的是離站事件本身，不是把休息算進了趟次。251 與 251區 兩種情況各只有 0 到 2 趟。
- 同一批資料下，週期如果定義成停車端發車對發車、照 `run-time` 的規則排除起點是到站時刻的趟次，中山幹線四個平日只剩 39 個；定義成停車端到站對到站，有 101 個。
- 測試 fixture（`spec/fixtures/analysis`，路線 9001，2026-10-19）跑 `bin/health-card` 得到 27 趟、18 筆折返停留；照下面的定義手算，來回一趟 7 個、週期 5 個，數字寫在 `round-trip-cycle` 規格的例子裡。

詞彙依 `docs/spectra/LANGUAGE.md`：趟次、行駛時間、折返停留、起站、末站、折返點、停車、開過去就走、百分位數、路線頁。「來回一趟」與「週期」是這個 change 新增的詞，由任務寫進詞彙表。

## Goals / Non-Goals

**Goals:**

- 路線頁上一眼看得到：這條路線來回一趟要跑多久、業者實際維持的週期給了多久，按發車小時並排，加一列全天。
- 定義只用已經驗過的衍生表，配對一律走 `layovers`，不另外發明一套相鄰趟次的判斷。
- 三條已設定的路線與兩端都停車的測試路線都算得出來，筆數與排除看得見。

**Non-Goals:**

- 班距對實際發車數、重點數字加值、門檻與顏色、推算量不到的配對、改任何既有定義、健檢卡、排程與部署、最近 30 天、其他路線（proposal 的非目標照舊）。

## Decisions

### 前段方向由兩端性質決定，去程優先

來回一趟從停車端發車開始算。兩端性質的鍵是結束在那一端的趟次方向，所以「方向 d 的趟次從停車端發車」等於「方向 1−d 的趟次結束在停車端」。規則：前段是方向 0，除非方向 0 的趟次結束在停車端而方向 1 的趟次結束在開過去就走的那一端（`0: stop`、`1: pass_through`），這時前段是方向 1。後段永遠是另一個方向。

三條已設定的路線都是 `0: pass_through`、`1: stop`，前段是去程，停車端是返程的末站（中山幹線職能發展學院二，251 與 251區 福安居一）。兩端都停車的路線（測試路線 9001）前段是去程，來回一趟含另一端的停留，頁面的說明寫出來。兩端都開過去就走的路線沒有停車端，照同一條規則前段仍是去程。

理由：兩端性質是人工查證過的事實（`turnaround-ends`），不從資料推；讀者口中的「一趟」是從調度站出發再回來，停車端就是調度站所在的那一端。替代方案：讓讀者選方向（否決：兩個方向的來回一趟相差的只是起點，多一個選項不多一個事實）。

### 來回一趟是前段離站到後段到站，排除規則沿用行駛時間

來回一趟 = 後段趟次的 `end_time` − 前段趟次的 `start_time`，單位分鐘。成立條件：

- 前段趟次 `completeness = 'complete'` 且 `start_from_arrival` 為假。
- `layovers` 有一列，`go_back` 是前段方向、`end_time` 等於前段趟次的 `end_time`、`next_start_time` 等於後段趟次的 `start_time`（同一個 `route_day_id` 與 `bus_id`）。
- 後段趟次 `go_back` 是後段方向、`completeness = 'complete'` 且 `end_from_departure` 為假。

它含另一端的停留：開過去就走的那一端是一兩分鐘的過站，兩端都停車的路線則含那一端的休息。

理由：起點是到站時刻會把在起站等發車的時間算進去，終點是離站時刻會把在末站的停留算進去，`run-time` 已經為同一個原因排除它們（決策「行駛時間只算完整趟次，排除起訖用替代時刻的趟次」，zhongshan-route-page）。走 `layovers` 配對，是因為那一列已經保證兩趟相鄰、中間沒有去跑別的路線、差值不為負（`layover-metrics` 的 Layover definition 與 Another route between the trips），不在這裡重寫一次。替代方案：直接用同一台車時間上相鄰的兩趟（否決：會把去開別條線的那段算成一個很長的來回）。

### 週期用停車端的到站對到站，不用發車對發車

週期 = 同一台車相鄰兩次後段趟次到末站的間隔：前一個後段趟次的 `end_time` 到下一個後段趟次的 `end_time`，中間經過一個前段趟次。成立條件：

- `layovers` 有一列把前一個後段趟次接到前段趟次（`go_back` 是後段方向、`end_time` 等於前一個後段趟次的 `end_time`、`next_start_time` 等於前段趟次的 `start_time`），前一個後段趟次的 `end_from_departure` 為假。
- `layovers` 有一列把前段趟次接到下一個後段趟次（條件同來回一趟的第二點）。
- 下一個後段趟次 `completeness = 'complete'` 且 `end_from_departure` 為假。
- 前段趟次的完整度與 `start_from_arrival` 不限：它只用來接起兩列，並提供分組用的發車小時。

同一組配對裡，週期恰好等於停車端的折返停留加來回一趟，因為三者用的是同三個時刻。

理由：停車端的離站事件漏得多，到站事件幾乎不漏（Context 的數字）。照 `run-time` 的規則排除起點是到站時刻的趟次後，中山幹線四個平日只剩 39 個週期，到站對到站有 101 個，而且不需要任何新的排除規則。週期要回答的是「業者給一台車跑一圈多少時間」，從哪個時刻起算不影響它的分佈。替代方案：發車對發車但不排除起點是到站時刻的趟次（否決：同一個週期一端用離站、另一端用到站，誤差就是那趟在起站等發車的時間，而這個時間正是我們要量的東西）。

### 按前段發車的台北小時分組，加一列全天，樣本少的門檻共用

來回一趟與週期都按前段趟次 `start_time` 的台北小時分組，每小時一列：來回一趟的筆數、p50、p85；週期的筆數、p10、p50。再加一列全天，把涵蓋天數裡所有小時合在一起算。一個量在一列的筆數少於 `RoutePage::RunTimes::SMALL_SAMPLE`（5）就標樣本少；筆數是 0 時百分位數是 nil，頁面顯示「—」。百分位數用 `percentile_cont` 線性內插、一位小數，跟其他表一樣在 PostgreSQL 算。

理由：行駛時間表已經是按發車小時，讀者對照兩張表時列對得起來；來回一趟報 p85 是「八成五的來回跑得完的時間」，週期報 p10 是「最緊的一成週期」，兩個都是對照搶黃燈那個缺口要看的那一端。全天那列是白話句子的來源，也讓單日樣本少時仍有一個可讀的數字。門檻共用是為了同一個「樣本少」在同一頁只有一個意思。

### 區塊依指標分組：同一個指標的圖與表放進同一張卡，來回一趟與週期在折返停留之後

**Supersedes**: 02-route-page-mobile-first / 區塊依指標分組：同一個指標的圖與表放進同一張卡

分組的原則不變：同一個指標的圖與表放進同一張 `CardComponent`，`show.html.erb` 的順序與分卡改成：

1. 頁首（`RouteCoverageComponent`，不放卡片）。
2. 重點數字（`RouteSummaryComponent`，`section[data-section=summary]`）。
3. 區塊導覽（`SectionNavComponent`），七個連結依序 `#layovers`、`#cycles`、`#buffer`、`#runtimes`、`#load`、`#mrt`、`#limits`。
4. `CardComponent(id: "layovers")`：`LayoverChartComponent`、分隔線、`LayoverTableComponent`。
5. `CardComponent(id: "cycles")`：`CycleTableComponent`（`section[data-section=cycles]`）。
6. `CardComponent(id: "buffer")`：`BufferTradeComponent`。
7. `CardComponent(id: "runtimes")`：`RunTimeTableComponent`。
8. `CardComponent(id: "load")`：`LoadChartComponent`、分隔線、`MrtOverlapComponent`、分隔線、`LoadProfileTableComponent`。
9. `CardComponent(id: "limits")`：`DataLimitationsComponent`。

理由：折返停留說剩下幾分鐘，來回一趟與週期說為什麼剩這麼少，換休息試算說補回來要幾台車，三張卡照這個順序讀。放在行駛時間之前，是因為它回答的問題比單向的行駛時間更接近讀者的經驗；行駛時間表仍是精確的每段數字。

### 手機上兩張表一次看一張，切換方式跟行駛時間一樣

640 px 以上兩張表並排（`grid lg:grid-cols-2`），來回一趟在左、週期在右。640 px 以下用 Alpine 的 `x-data="{ measure: 'round_trip' }"` 一次只看一張，預設來回一趟；切換按鈕帶 `x-cloak` 與 `sm:hidden`，沒有 JS 時兩張表都在；切換不改網址（決策「窄螢幕的方向切換用 Alpine，沒有 JS 時兩個方向都在」，02-route-page-mobile-first，同一套做法）。

理由：七個數字欄在手機上放不下，而兩個量各自是一張四欄的表，正好套用現成的切換。

### 白話句子只用全天那列的值，沒有來回就不出現

表上方一句話，用全天那列的四個數字寫成，例如「來回一趟有一半要 151.3 分鐘以上、八成五在 169.6 分鐘內跑完；週期最緊的一成只有 146.8 分鐘、一半在 181.6 分鐘內。」數字的文字跟全天那列的格子一模一樣（`ApplicationComponent#minutes`）。全天那列的來回一趟筆數是 0 時，整塊改顯示「這幾天沒有算得出來的來回」；來回有、週期沒有時，句子只寫來回的那一半。

理由：`02-route-page-mobile-first` 的非目標「重點數字以外的新彙總值…卡上只放表格裡已經有的值」，全天那列就是表格裡的值，句子不產生第二套數字。句子不寫「週期減來回等於停留」這種跨百分位數的減法，因為百分位數之間不能相減。

### 文案

tw 與 zh-TW 用同一份（`<<: *tw`），en 另寫。

- 小標（eyebrow）「來回一趟與週期」，標題「跑得完嗎？來回一趟要多久，週期給了多久」。
- 說明一段：「來回一趟從{前段起站}發車算到回到{後段末站}，含另一端的停留；週期是這台車回到{後段末站}，到下一次回到同一站的間隔，中間的休息都算在裡面。兩者都照發車的那個小時分組，只算兩段都量到起站與末站、而且中間沒有去跑別條路線的車。一列的筆數少於 5 就標「樣本少」。」兩端都停車的路線多一句「另一端的停留是休息，不是過站」。站名取自涵蓋天數裡最新一天的 `route_day_stops`。
- 表頭：來回一趟那張「發車時、筆數、p50、p85」，週期那張「發車時、筆數、p10、p50」；最後一列的發車時寫「全天」。
- 不出現合規、達標、門檻、顏色。
- 區塊導覽的連結文字「來回與週期」。
- 資料限制加一條：「來回一趟與週期只用兩段都量到起站與末站、而且在折返停留裡配得起來的趟次，所以筆數會比趟次數少。一台車當天第一個來回沒有週期。週期是車的節奏，雙班制下對不回某一個駕駛的班表。」

## Implementation Contract

**Behavior**

- `GET /routes/15373?day=2026-10-22&range=7d` 回 200，頁面在 `#layovers` 那張卡之後、`#buffer` 之前有 `div#cycles` 包住 `section[data-section="cycles"]`；區塊導覽有七個連結，第二個是 `#cycles`。
- 這一塊顯示：小標、標題、說明（含起站與末站站名）、白話句子、兩張表。每張表每個有資料的發車小時一列，最後一列全天；筆數少於 5 的列帶 `data-small-sample`。
- 沒有任何來回一趟時，整塊顯示說明與「這幾天沒有算得出來的來回」，不顯示表與句子。
- 頁面不顯示任何車牌，不標示任何門檻或合不合規。
- 選的那天沒有資料時，跟其他卡一樣不出現。

**Interface / data shape**

- `RoutePage::Cycles.new(route_days, ends:)`
  - `#lead_go_back -> 0 | 1`：照決策「前段方向由兩端性質決定，去程優先」。
  - `#back_go_back -> 0 | 1`：另一個方向。
  - `#first_stop_name -> String | nil`、`#last_stop_name -> String | nil`：涵蓋天數裡最新一天，前段的第一個站牌名與後段的最後一個站牌名（`route_day_stops` 依 `seq`）。
  - `#rows -> [Row]`：每個有資料的台北小時一列，依小時排序；`Row = Data.define(:hour, :n_round_trips, :round_trip_percentiles, :n_cycles, :cycle_percentiles)`，`round_trip_percentiles` 是 `[p50, p85]`、`cycle_percentiles` 是 `[p10, p50]`，各自在筆數為 0 時是 `[nil, nil]`。
  - `#total -> Row`：`hour` 是 `nil`，其餘是全天合計。
  - `Row#round_trip_small_sample?`、`Row#cycle_small_sample?`：筆數少於 `RoutePage::RunTimes::SMALL_SAMPLE`。
  - `#any_round_trips? -> Boolean`。
  - 同一個物件呼叫兩次 `rows` 只查一次資料庫，`total` 與 `rows` 共用同一次查詢。
- 查詢在 PostgreSQL 做：來回一趟是 `trips`（前段）join `layovers` join `trips`（後段）；週期是 `layovers`（後段方向）join `trips`（前一個後段）join `trips`（前段）join `layovers`（前段方向）join `trips`（下一個後段），join 鍵是 `route_day_id`、`bus_id`、`go_back`、`end_time` 對 `layovers.end_time`，以及 `layovers.next_start_time` 對 `trips.start_time`。不選 `bus_id` 到結果裡。
- `CycleTableComponent.new(cycles:)`，用 `bin/rails g view_component:component CycleTable cycles --locale` 產生，同層 `.yml` 有 tw、zh-TW、en。輸出的 `section[data-section="cycles"]` 裡：`[data-headline]`（白話句子）、`[data-stops]`（說明，帶 `data-first-stop`、`data-last-stop`）、兩個 `[data-measure="round_trip"]` 與 `[data-measure="cycle"]` 各包一張 `table.data-table`，列帶 `data-hour`（全天那列是 `data-total`），格子依序是小時、筆數、兩個百分位數；`[data-measure-switch]` 是切換按鈕群；沒有來回時 `[data-no-round-trips]`。
- `SectionNavComponent::SECTIONS` 變成 `%w[layovers cycles buffer runtimes load mrt limits]`，`.yml` 加 `cycles: 來回與週期`／`Round trips & cycles`。
- `show.html.erb` 在 `layovers` 與 `buffer` 兩張卡之間 render `CardComponent.new(id: "cycles")`，裡面是 `CycleTableComponent.new(cycles: RoutePage::Cycles.new(route_days, ends: @ends))`。

**Failure modes**

- 涵蓋的天數沒有任何來回一趟：顯示說明與「這幾天沒有算得出來的來回」，不報數字，不會除以零。
- 有來回一趟但沒有週期：週期那張表只有全天一列、筆數 0、百分位數「—」，句子只寫來回的那一半。
- 一列只有其中一個量：另一個量的筆數 0、百分位數「—」。
- `route_day_stops` 沒有站牌（舊資料）：站名是 nil，說明用「起站」「末站」兩個詞代替站名，數字照算。
- 選的那天沒有資料：整塊不出現（`@coverage.data?` 為假時不 render）。

**Acceptance criteria**

- `spec/models/route_page/cycles_spec.rb` 用灌入的 `trips` 與 `layovers` 斷言 `round-trip-cycle` 規格的每個情境：前段方向的三種設定、合格的來回一趟、前段起點是到站時刻被排除、後段終點是離站時刻被排除、沒有 `layovers` 配對就不算、合格的週期、前一個後段終點是離站時刻被排除、下一個後段不完整不算、一台車第一個來回沒有週期、同一組配對裡週期等於折返停留加來回一趟、按發車小時分組與全天那列、百分位數的線性內插、樣本少、兩個量各自為 0 時的 nil、只查一次資料庫。
- 真實管線的 fixture：`spec/requests/route_page_fixture_spec.rb` 或 `cycles_spec.rb` 裡一個 `:duckdb` 例子，用 `RouteDayLoader` 寫入 fixture 的 2026-10-19 後，9001 的全天那列是來回一趟 7 筆、p50 113.0、p85 150.3，週期 5 筆、p10 122.6、p50 136.0（手算，依據 `bin/health-card` 對 fixture 輸出的 `trips.csv` 與 `layovers.csv`）。
- `spec/components/cycle_table_component_spec.rb` 斷言兩張表的列與格子文字、全天那列、樣本少標記、句子的數字等於全天那列的格子、沒有來回時的說明、站名出現在說明裡、切換按鈕帶 `x-cloak`、沒有合規字樣。
- `spec/requests/routes_spec.rb` 的區塊順序變成 summary、layover chart、layovers、cycles、buffer-trade、run-times、load chart、mrt-overlap、load-profile、limitations；區塊導覽七個連結；資料限制那一節仍在。`spec/requests/route_page_fixture_spec.rb` 仍沒有任何車牌、Bullet 不報 N+1。
- 真資料驗收（衍生表已有三條路線的 2026-10-19 到 10-22，不用重跑 `derived:load`）：`range=7d`、`day=2026-10-22` 的全天那列要等於下表（2026-10-23 以同一套定義在衍生表上算的）：

  | 路線 | 來回一趟 筆數 / p50 / p85 | 週期 筆數 / p10 / p50 |
  | --- | --- | --- |
  | 中山幹線 15373 | 106 / 151.3 / 169.6 | 101 / 146.8 / 181.6 |
  | 251 10712 | 141 / 150.5 / 165.2 | 110 / 164.1 / 205.3 |
  | 251區 11764 | 197 / 115.4 / 126.6 | 135 / 109.5 / 140.1 |

  說明裡的站名：中山幹線起站與末站都是職能發展學院二，251 與 251區 起站福安居、末站福安居一。

**Scope boundaries**

- 在範圍內：查詢物件、元件、路線頁位置、區塊導覽、資料限制文案、`docs/spectra/LANGUAGE.md` 的兩條新詞與一條邊界、規格與測試。
- 不在範圍內：migration、`analysis/` 的 SQL、`derived:load`、健檢卡、重點數字、首頁、班距、其他路線、排程與部署。

## Risks / Trade-offs

- [中山幹線三成去程趟次起點是到站時刻，來回一趟只剩 249 趟完整去程裡的 106 筆] → 筆數跟數字放在同一列，資料限制寫明筆數會比趟次數少；週期改用到站對到站，不受這件事影響。
- [週期含午休這類長停留，某些小時的 p50 會很大：中山幹線 15 時的 5 個週期 p50 是 310 分鐘（量到的）] → 這是真的，不是錯誤；說明寫明中間的休息都算在裡面，要看的是 p10 那一端。
- [單日每小時只有幾筆，樣本少的標記會很多] → 跟行駛時間表一樣標出來；30 天視窗是另一個 change 的事。
- [兩端都停車的路線，來回一趟含另一端的休息，讀起來像行駛時間比較長] → 說明多一句；三條已設定的路線都不是這種情況。
- [百分位數之間不能相減，讀者仍可能拿週期 p50 減來回 p50] → 文案不做這個減法，只在說明裡講「同一個來回裡，週期等於停留加來回」。
- [同一台車連跑兩趟前段方向（fixture 的 TEST-0003 連跑兩趟去程）] → `layovers` 的配對把它接到下一趟去程，後段方向不符就不算來回，也不算週期；這是定義的結果，不特別處理。
