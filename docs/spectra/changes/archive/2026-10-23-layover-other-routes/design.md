## Context

折返停留與班次串在 `analysis/30_layovers.sql` 定義，一天版的健檢卡（`bin/health-card`）與 `derived:load` 共用同一組階段檔；路線頁的折返停留、換休息試算讀的是衍生表 `layovers`，也就是同一個 `layovers` view 的結果。

已核對的現況：

- `analysis/10_load.sql` 讀 `bus_event` 時，`raw_bus_events` 只留 `RouteID` 是這條路線附屬路線的記錄；`stop_events` 再用 `routes` join。所以 `trips` 的 `route_id` 永遠是要算的那條路線。
- `layover_pairs` 依序分類 `no_last_stop`、`no_first_stop`、`other_route`（`next_route_id <> route_id`）、`negative`。`other_route` 這個條件在真資料永遠不成立；只有 `spec/analysis/layovers_spec.rb` 的「下一趟是別的路線時不算」灌了一趟 `route_id` 9100 的趟次才碰得到。
- `rest_runs` 的註解寫「不完整的趟次或換路線就切斷」。程式裡的 `route_id IS DISTINCT FROM previous_route_id` 只有在每台車第一趟（前一趟是 NULL）時成立，作用只剩讓第一趟開始一個序列。
- fixture 的對照路線 9100：TEST-0004 在 13、19、20、21、22 時各四筆（站牌 92000 到 92003），`RouteID` 0 一筆在 15:00；全部在 TEST-0004 當天最後一趟（09:03 結束）之後，不在任何兩趟之間。
- 卡的排除一行印「下一趟是別的路線 N 組」；路線頁 `LayoverTableComponent` 的說明寫「只算本趟有到末站、下一趟從起站出發的配對」。

真資料的量測（2026-10-23 用現有 SQL 在記憶體裡算，量到的）見 proposal。補充兩點：

- 兩趟之間出現別條路線記錄的配對，經過的不同站牌數只有兩種：1 個站（8 組，全在 307），或至少 57 個站（240 組）。
- 2026-10-22 中山幹線兩趟之間出現的 `RouteID` 0，站牌都是 16738（職能發展學院二，返程末站），`DutyStatus` 2，`BusStatus` 92 或 93。

詞彙依 `docs/spectra/LANGUAGE.md`：折返停留、趟次、附屬路線、路線、站牌、班次串、末站、起站。

## Goals / Non-Goals

**Goals:**

- 車在兩趟之間去跑了別條路線時，這一組不算折返停留，只計數。
- 班次串的四小時視窗不跨過這段看不到的行駛。
- 一天版的卡、衍生表、路線頁、換休息試算同時用新規則，數字彼此一致。

**Non-Goals:**

- 推算這些配對的停留，或重建別條路線的趟次。
- 以車為中心、跨路線算折返停留（307 接 307西藏三民 的情況）。
- `GetRoute.gz` 同一個附屬路線有好幾列造成的事件重複。
- 加路線、改 `config/route_page.yml`、改詞彙表「區間車」「路線」兩條。
- 查清楚 `RouteID` 0 的意思。
- 把排除計數搬上路線頁；平日與假日分開；排程與部署；重產 `docs/cards/15373-2026-10-19.md`。

## Decisions

### 別條路線的記錄在第 10 階段讀進 other_route_events，只讀這條路線的車

第 10 階段新增 table `other_route_events`：從同一份讀檔視窗的 `bus_event` 小時檔（`bus_event_files` 變數），讀 `BusID` 出現在 `bus_events` 裡的車、`RouteID` 不是 0 也不是這條路線任一附屬路線的記錄。去重方式跟 `bus_events` 一樣：每個 `(bus_id, data_time)` 留最早抓到的那一筆。欄位只留 `bus_id`、`path_attribute_id`、`stop_id`、`data_time`。`RouteID` 或 `StopID` 轉不成整數的記錄不讀。

理由：判斷只需要「這台車在這段時間經過了別條路線的哪些站」。限定這條路線的車，是因為判斷是逐車做的，別的車的記錄永遠用不到。放在第 10 階段，是因為讀原始檔只在這一階段發生，後面的階段只讀表；`bin/health-card` 與 `derived:load` 也因此自動一起改。多讀一次，307 在 10-22 的第 10 階段從約 0.85 秒變約 1.05 秒（量到的）。

替代方案：
- 第一次讀檔就把整個視窗的記錄全讀進來，再分兩張表。少讀一次檔，但 `raw_bus_events` 會從一條路線變成全路網，記憶體與後面的過濾都變重，否決。
- 重建別條路線的趟次，用趟次判斷。要那條路線的站序，第 10 階段得讀全部路線的 `GetStop.gz`；這次只需要「有沒有去跑」，否決。

### 至少經過 3 個不同站牌才算跑了別的路線，RouteID 0 一律不算

對每一組相鄰的趟次，取這台車 `other_route_events` 裡 `data_time` 晚於本趟終點、早於下一趟起點的記錄（兩端都不含）。不同的 `stop_id` 有 `other_route_min_stops` 個以上，就算「兩趟之間跑了別的路線」。這個常數寫在 `analysis/params.sql`，值是 3。

- `RouteID` 0 在第 10 階段就不讀。它是末站的勤務結束這類非營運記錄；回場、加油本來就算在折返停留裡（詞彙表「折返停留」）。
- 不到 3 個站的不算。那是在末站把路線碼切成別條、又切回來，車沒有離開。

理由：四條路線四天的 248 組裡，不同站牌數只有 1 或至少 57（量到的），2 到 56 之間一組都沒有，門檻落在 2 到 57 都分得開。取 3，是照討論時的結論「只有 1、2 站的不算」，也讓「真的跑了一段」的判斷盡量保守：寧可多排除一組，也不要把開車的時間當成休息。

替代方案：
- 只要有一筆就算。307 四天裡每天有 0 到 3 組正常的折返停留會被誤刪（量到的），否決。
- 用時間長度判斷（例如別條路線的記錄跨過幾分鐘）。要另外訂一個沒有量過的門檻；站數直接說明車有沒有離開，否決。

### other_route 改成「兩趟之間跑了別的路線」，排除的順序不變

`layover_pairs` 加一欄布林值 `ran_other_route`，就是上一個決策的判斷。分類照原來的順序：`no_last_stop`、`no_first_stop`、`other_route`、`negative`、`layover`。`other_route` 的條件從 `next_route_id <> route_id` 換成 `ran_other_route`；一組同時符合幾類時，仍算在列出的第一類。`layover_exclusions` 的四個欄位名不變。

理由：`next_route_id <> route_id` 在這套只讀一條路線的流程裡永遠不成立，留著它，讀程式的人會以為「換路線」已經處理了，這個問題就是這樣藏起來的。這一類本來就是為了擋「兩趟中間車不在這條路線上」，換成看得到的判斷，詞彙表與 `layover-metrics` 寫的「同一路線」才真的成立。這只改第三類的條件；`layover-endpoints` 的決策「折返停留只要本趟觀測到末站、下一趟觀測到起站」的端點規則不變。

替代方案：
- 另開第五類 `other_route_between`，保留舊的 `other_route`。兩類說的是同一件事（車離開了這條路線），卡上會多一個永遠是 0 的數字，否決。
- 兩個條件都放在 `other_route` 裡。保留了一個在真資料永遠不成立的分支，否決。

### 班次串遇到兩趟之間跑了別的路線也切斷

`rest_runs` 的序列：每台車的第一趟開始一個序列；遇到不完整的趟次，或這一趟與前一趟之間跑了別的路線（同一組配對的 `ran_other_route`），就開始新的序列。不完整的趟次照舊不在任何序列裡。四小時視窗、休息額度、併成一串的規則都不變。

理由：只把那段時間從折返停留拿掉而不切斷，視窗會跨過一段看不到的行駛，額度是 0，就會把沒有證據的段落標成不合規。fixture 的 TEST-0002 就是這樣：不切斷時，10:20 到 17:58 會多出一條 3 趟的假班次串。別條路線上有沒有休息，這裡看不到；切斷跟「遇到不完整趟次就切斷」是同一個理由，符合 `zhongshan-first-health-card` 的決策「班次串用第 19 條之 2 的四小時視窗算，重疊的視窗併成一串」與 `layover-endpoints` 的決策「班次串不跟著放寬」寫的「班次串要的是一段連續、時刻都可信的行駛」。

替代方案：不切斷，讓視窗跨過去、這段不給額度。會把別條路線上的行駛算成這條路線的連續駕駛，又沒有那段的休息資料，否決。

### 卡與路線頁的說明寫出別條路線的規則

- `bin/health-card` 折返停留一節的說明改成：「同一車牌相鄰兩趟，本趟有到末站、下一趟從起站出發，而且兩趟之間沒有去跑別的路線，下一趟起點減本趟終點，單位分鐘；另一端漏站不影響，每台車當天最後一趟沒有折返停留。兩趟之間跑了別的路線，指這台車在兩趟之間有 `RouteID` 不是 0、也不是這條路線附屬路線的到離站事件，經過至少 N 個站。它包含回場、加油、等發車在內的一切，是駕駛休息的上限。百分位數在順序統計量之間線性內插。」其中 N 讀卡的 JSON 裡的 `layovers.other_route_min_stops`。
- 排除一行印成「本趟沒有到末站 N 組、下一趟不是從起站出發 N 組、兩趟之間跑了別的路線 N 組、差值為負 N 組」。
- 班次串的說明「只用相鄰完整趟次接成的序列，遇到不完整趟次就切斷。」改成「只用相鄰完整趟次接成的序列，遇到不完整趟次、或兩趟之間跑了別的路線，就切斷。」
- 路線頁 `LayoverTableComponent` 的 `note`：
  - tw：「同一台車本趟末站到站到下一趟起站離站的分鐘數，只算本趟有到末站、下一趟從起站出發，而且兩趟之間沒有去跑別的路線的配對（另一端漏站不影響），依結束那趟的方向分列。它包含回場、加油、等發車在內的一切，是駕駛休息的上限。」
  - en：「Minutes from a trip's arrival at its last stop to the same vehicle leaving the first stop of its next trip, for pairs where the trip reached its last stop, the next one left its first stop and the vehicle ran no other route in between (a missed stop at the other end does not matter), by the direction of the ending trip. It includes returning to the depot, refuelling and waiting, so it is an upper bound on rest.」

理由：卡是定義文件，門檻要寫出來，而且從 JSON 讀，改 `params.sql` 時卡跟著變。路線頁不寫門檻數字：頁面讀不到 `params.sql`，寫死會多一個要同步的地方；細節在卡與詞彙表。

### fixture 2026-10-19 的手算值

**Supersedes**: layover-endpoints / fixture 2026-10-19 的手算值

fixture 加兩段對照路線 9100 的到離站記錄，格式照現有的 9100 記錄（`ProviderID` 9999、`StationID` 19001、`DutyStatus` 1、`BusStatus` 0，`_fetched_at` 是 `DataTime` 加 4 秒換成 UTC）：

| 車牌 | 記錄（`DataTime`、站牌、`GoBack`、`CarOnStop`） | 小時檔 | 夾在哪兩趟之間 | 結果 |
| --- | --- | --- | --- | --- |
| TEST-0002 | 14:10:00 92000 0 離站；14:20:00 92001 0 到站；14:30:00 92002 1 離站 | 2026-10-19/14 | 返程 11:20–12:08 與去程 17:10 起 | 3 個站，算跑了別的路線 |
| TEST-0001 | 15:50:00 92000 0 到站；15:51:00 92000 0 離站；15:55:00 92001 0 到站 | 2026-10-19/15 | 返程 14:50–15:40 與去程 17:05 起 | 2 個站，不算 |

手算結果（依 `spec/fixtures/analysis/README.md` 的趟次表）：

- `other_route_events` 26 筆，全部是 9100：TEST-0004 20 筆、TEST-0002 3 筆、TEST-0001 3 筆。TEST-0004 15:00 的 `RouteID` 0 不在裡面。
- 折返停留 18 筆，每台車依結束時刻：
  - TEST-0001：10.0、12.0、13.0、10.0、56.0、21.0、25.0、85.0（不變，85.0 那筆中間只有 2 個站）。
  - TEST-0002：14.0、12.0、12.0、282.0（少了 12:08 到 17:10 的 302.0）。
  - TEST-0003：15.0、14.0、23.0、17.0（不變）。
  - TEST-0004：17.0、12.0（不變）。
- 去程結束 10 筆（不變）：10.0、13.0、56.0、25.0、12.0、12.0、15.0、14.0、17.0、12.0。返程結束 8 筆：12.0、10.0、21.0、85.0、14.0、282.0、23.0、17.0。
- 排除的配對：`no_last_stop` 3、`no_first_stop` 1（跟原來同一批）、`other_route` 1（TEST-0002 12:08 結束那趟接 17:10 那趟）、`negative` 0。
- 卡上的分佈（筆數、p10、p50、p90、不到 15 分鐘的比例）：全部 18、11.4、14.5、64.7、50.0%；去程結束 10、11.8、13.5、28.1、60.0%（不變）；返程結束 8、11.4、19.0、144.1、37.5%。分箱（0–5、5–10、10–15、15–30、30–60、60 以上）：全部 0、0、9、6、1、2；去程結束 0、0、6、3、1、0；返程結束 0、0、3、3、0、2。百分位數用 DuckDB 的 `quantile_cont` 對上面的分鐘數算過。
- 班次串仍只有 TEST-0001 06:00 到 11:30 一串、5 趟；被標的視窗仍是 TEST-0001 06:00 與 07:00 起的兩個。TEST-0002 的序列在 12:08 與 17:10 之間切斷：10:20 與 11:20 兩趟只有 108 分鐘，不到 240 分鐘，沒有視窗。不切斷的話，10:20 與 11:20 起的視窗都會因為額度 0 被標，多出一條 10:20 到 17:58、3 趟的串。

理由：一個案例落在門檻上方（3 個站），一個落在門檻下方（2 個站），兩邊的邊界都由 fixture 端到端守住；TEST-0002 那一組同時守住班次串的切斷。兩段都避開空的 16 時檔，也不碰其他案例用到的時段。

## Implementation Contract

**Behavior**

- `bin/health-card` 對 fixture 2026-10-19 的卡：折返停留與分箱的數字照上一個決策；排除一行是「本趟沒有到末站 3 組、下一趟不是從起站出發 1 組、兩趟之間跑了別的路線 1 組、差值為負 0 組」；班次串「1 串，涉及 1 台車」與同一列串表；說明文字照「卡與路線頁的說明寫出別條路線的規則」，門檻印 3。
- `derived:load` 寫入 fixture 2026-10-19：趟次 27、折返停留 18、趟次站 96。
- 真資料 2026-10-22：`bin/health-card --route 15373` 折返停留 105 筆、`other_route` 1 組；`bin/health-card --route 16111` 折返停留 312 筆、`other_route` 60 組。
- 中山幹線重跑 `derived:load` 之後，10-19 到 10-21 三天合計 332 筆（現在 333）。

**Interface / data shape**

- `analysis/params.sql`：`other_route_min_stops`，值 3，註解寫明 RouteID 0 不算、只經過 1、2 個站是在末站切路線碼，以及 248 組的量測。
- 第 10 階段新增 table `other_route_events(bus_id, path_attribute_id, stop_id, data_time)`，每個 `(bus_id, data_time)` 一列；檔頭註解的建立清單加上它。
- 第 30 階段：`layover_pairs` 多一欄 `ran_other_route`；`category` 的值不變（`layover`、`no_last_stop`、`no_first_stop`、`other_route`、`negative`）；`layover_exclusions` 的欄位不變；`rest_runs` 依 `ran_other_route` 切斷。
- 卡的 JSON：`layovers` 多一個鍵 `other_route_min_stops`；`layovers.exclusions` 的鍵不變。
- 衍生表的欄位不變，不加 migration。
- 測試輔助：`spec/support/duckdb.rb` 加一個把 `other_route_events` 換成指定記錄的 SQL 產生器（每筆是車牌、時刻、站牌，路線預設 9100；空陣列給出同樣欄位的空表）。灌入趟次的 example 同時把 `other_route_events` 換掉，預設是空的，fixture 的記錄不會漏進來。

**Failure modes**

- 車在兩趟之間沒有別條路線的記錄：結果跟改之前一樣。
- `RouteID` 或 `StopID` 轉不成整數的記錄不讀，不報錯。
- 讀檔視窗沒有任何 `bus_event` 小時檔時，執行檔跟現在一樣在跑 SQL 之前擋下。
- 負值配對的區間是空的，`ran_other_route` 一定是 false，仍算在 `negative`。

**Acceptance criteria**

- `spec/analysis/load_spec.rb`：`other_route_events` 的 26 筆，以及沒有 `RouteID` 0、沒有 9001、9002、9003。
- `spec/analysis/layovers_spec.rb`：fixture 的折返停留、四類計數與按方向的筆數和中位數，照決策「fixture 2026-10-19 的手算值」；灌入的趟次與記錄斷言 3 個站算 `other_route`、1 個站仍算 12.0 分鐘、2 與 3 個站的門檻邊界、本趟漏末站時只算 `no_last_stop`。原本「下一趟是別的路線時不算」那一例改成灌入記錄的版本。
- `spec/analysis/chains_spec.rb`：fixture 的班次串與被標的視窗不改斷言仍綠；灌入的趟次斷言「Another route cuts the run」沒有任何視窗。
- `spec/analysis/card_spec.rb`、`spec/analysis/cli_spec.rb`、`spec/analysis/derived_export_spec.rb`、`spec/models/route_day_loader_spec.rb`、`spec/models/derived_load_command_spec.rb` 的筆數與分佈改成上一個決策的值。
- `spec/analysis/fixtures_spec.rb`：新加的兩段記錄各一例。
- `spec/models/route_page/card_consistency_spec.rb` 不改斷言仍綠。
- `make test`、`bin/rubocop`（改到的 Ruby 檔）、`bin/brakeman` 全綠。

**Scope boundaries**

- 在範圍內：`analysis/params.sql`、`analysis/10_load.sql` 的 `other_route_events`、`analysis/30_layovers.sql` 的 `layover_pairs`、`layover_exclusions`、`rest_runs`、`analysis/60_export.sql` 的門檻、`bin/health-card` 的折返停留一節、`app/components/layover_table_component.yml`、fixture 的兩個小時檔與 README、上面列的測試與 `spec/support/duckdb.rb`、`docs/spectra/LANGUAGE.md` 的「折返停留」與「班次串」、`analysis/README.md`、中山幹線重跑 `derived:load`。
- 不在範圍內：`analysis/20_trips.sql`、`analysis/40_load_profile.sql`、`analysis/50_quality.sql`、`analysis/derived_export.sql`、`app/models/` 底下的程式、migration、路線頁其他元件、`config/route_page.yml`。

## Risks / Trade-offs

- [門檻 3 只在四條路線、四天上看過] → 量到的 248 組裡沒有一組落在 2 到 56 之間；門檻是 `params.sql` 的常數，卡上印出來。之後加路線時，查證的 change 照同樣方法再看一次分佈。
- [排除之後量到的折返停留變少，307 每天少約 16%] → 換休息試算本來就報「量到幾次、同期幾趟」的涵蓋率，照 `zhongshan-buffer-trade` 的決策「只報量到的折返停留，標出涵蓋率」，不推算。
- [被排除的配對裡，可能藏著真的折返（307 接 307西藏三民、在同一個末站）] → 這次只計數。以車為中心的算法要先決定 307 怎麼算，另開 change；中山幹線與 251區 每天 0 到 1 組（量到的）。
- [班次串切斷後，跨過別條路線行駛的違規看不到] → 別條路線上的休息本來就看不到，切斷是不拿沒有證據的段落下結論，跟遇到不完整趟次一樣。
- [卡與頁面的數字跟上一版不同] → 一天版的卡本來就標明不能引用；這個 change 改了詞彙表與卡的說明。
- [`day-types` 也在改 fixture 的 README、`spec/analysis/fixtures_spec.rb`、詞彙表與兩個載入的 spec] → 等 `day-types` archive 之後再 apply。

## Migration Plan

1. 實作與測試照 tasks。
2. `TURNAROUND_DATA` 指到資料根目錄（不寫進任何檔案），執行 `bin/rails derived:load ROUTE=15373 FROM=2026-10-19 TO=<讀檔視窗已經結束的最新一天>`。
3. 退回：還原程式之後用同一個指令重跑，衍生表回到舊定義。沒有 schema 變更。
