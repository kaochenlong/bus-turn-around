## Problem

這個 change 服務三樣交付物的第一樣與第二樣：路線健檢卡（一天版的卡與路線頁）的折返停留與班次串，以及建在折返停留上的換休息試算。需要的資料全部是 n-gear 已經在收的 `bus_event`（公運處 blob 的 GetBusEvent），不用新的資料來源；要改的是讀的範圍：同一台車在別條路線上的到離站事件也要讀進來。

同一台車在兩趟之間去開了別條路線，現在會被算成一次很長的折返停留。2026-10-22 的中山幹線 15373（量到的）：一台車返程 11:53 到職能發展學院二，接著去開 206、經過 79 個站，18:01 才從職能發展學院二發下一趟去程；現在的算法把它記成一次 368 分鐘的折返停留。

用現有的 `analysis/` SQL 在記憶體裡重算 2026-10-19 到 10-22 四天（量到的，2026-10-23 查詢）：

| 路線 | 每天量到的折返停留 | 其中兩趟之間跑了別條路線 |
| --- | --- | --- |
| 中山幹線 15373 | 108、112、113、106 | 0、1、0、1 |
| 307 16111 | 364、371、352、372 | 54、62、59、60 |
| 251區 11764 | 92、82、87、92 | 1、0、1、1 |

- 中山幹線受影響的兩筆都在停車端，分別是 313 與 368 分鐘。停車端不少於 15 分鐘的比例，10-20 從 51.4% 變 50.0%，10-22 從 48.6% 變 47.2%（量到的）。影響小，但方向是把休息算多，路線頁換休息試算的休息達成率跟著偏高。
- 307 四天裡約 16% 的折返停留是這種（量到的）。要加其他路線，得先修這個。
- 班次串也受影響：這段時間現在被當成休息額度，跨過它的四小時視窗不會被標。

## Root Cause

詞彙表「折返停留」與 `layover-metrics` 都規定相鄰兩趟要同一路線 `Id`。`analysis/30_layovers.sql` 為此留了 `other_route` 這一類（下一趟是別的路線），班次串的 `rest_runs` 也寫了換路線就切斷。但 `analysis/10_load.sql` 讀檔時只留這條路線附屬路線的事件，別條路線的事件在第一步就丟掉了。趟次永遠只有這條路線，這兩個條件永遠不成立，車在兩趟之間做了什麼，後面的階段看不到。fixture 與真資料的 `other_route` 計數一直是 0。

## Proposed Solution

讓後面的階段看得到車在兩趟之間有沒有去開別條路線。這是從根因修，不是事後修數字：

- **第 10 階段多讀一張表**：這條路線的車，在同一個讀檔視窗裡，`RouteID` 不是 0、也不是這條路線附屬路線的 `bus_event` 記錄，照 `(BusID, DataTime)` 去重。
- **定義「兩趟之間跑了別的路線」**：這些記錄裡，`DataTime` 在本趟終點之後、下一趟起點之前的，經過至少 3 個不同的站牌。門檻寫在 `analysis/params.sql`。
  - `RouteID` 0 一律不算。2026-10-22 中山幹線兩趟之間出現的 0，都是職能發展學院二（站牌 16738）上的勤務結束記錄（`DutyStatus` 2，量到的）；回場本來就算在折返停留裡。
  - 只經過 1、2 個站的不算，那是在末站切了路線碼。上表三條路線加 251（10712）四天裡，兩趟之間出現別條路線事件的配對共 248 組：8 組只有 1 個站，240 組至少 57 個站，沒有落在 2 到 56 之間的（量到的）。
- **BREAKING（數字變更），折返停留**：這種配對不量、只計數，算在 `other_route`。這一類的意思從「下一趟是別的路線」改成「兩趟之間跑了別的路線」，照 `layover-endpoints` 的決策「量不到的配對只計數，不當證據」。
- **BREAKING（數字變更），班次串**：序列原本遇到不完整趟次就切斷，現在遇到「兩趟之間跑了別的路線」也切斷。
- **說明文字跟著改**：健檢卡的折返停留一節、路線頁折返停留的說明、詞彙表的「折返停留」與「班次串」。
- **fixture 加兩段別條路線的事件**：手算的折返停留從 19 筆變 18 筆。
- **重載**：已經載入的中山幹線日子重跑 `derived:load`。

## Non-Goals

- 推算這些配對的停留，或重建別條路線的趟次。車在 206 上跑了幾趟、在那邊停了多久，這次都不看，只計數。
- 以車為中心、跨路線算折返停留，例如 307 接 307西藏三民、在同一個末站的停留。加 307 之前要先決定這件事，另開 change。
- `GetRoute.gz` 同一個附屬路線有好幾列，造成事件被重複算（307 每筆變 4 筆）。另開 change，排在加 307 之前。
- 加任何路線、改 `config/route_page.yml`；詞彙表「區間車」「路線」兩條跟資料對不上的地方，等加 251區、307 的 change 再改。
- 查清楚 `RouteID` 0 代表什麼。這次只確定它不算別條路線。
- 把排除計數搬上路線頁（`layover-endpoints` 的非目標）；平日與假日分開（`day-types`）；排程與部署。
- 重產 `docs/cards/15373-2026-10-19.md`：那是第一個 change 留下的一天版紀錄，`layover-endpoints` 之後也沒有重產。

## Success Criteria

- `bin/health-card` 對 fixture 2026-10-19：
  - 折返停留 18 筆，去程結束 10 筆、返程結束 8 筆。
  - 排除的配對：`no_last_stop` 3、`no_first_stop` 1、`other_route` 1、`negative` 0；排除一行印出「兩趟之間跑了別的路線 1 組」。
  - TEST-0001 15:40 結束、17:05 出發的 85.0 分鐘仍算，中間只有 2 個站的別條路線事件。
  - 班次串仍只有 TEST-0001 06:00 到 11:30 一串、5 趟。
- 真資料（2026-10-22）：`bin/health-card --route 15373` 的折返停留從 106 筆變 105 筆、`other_route` 1 組；`--route 16111` 從 372 筆變 312 筆、`other_route` 60 組。
- 中山幹線重跑 `derived:load` 之後，10-19 到 10-21 三天合計 332 筆折返停留（現在 333，量到的），少的是 10-20 那筆 313 分鐘；10-22 如果已經載入，從 106 筆變 105 筆。
- `make test` 全綠，`bin/rubocop` 對改到的 Ruby 檔沒有 offense。

## Impact

- Affected specs: `layover-metrics`（修改 Layover definition、Rest-rule windows and chains；新增 Runs on other routes between trips）
- Affected code:
  - Modified: analysis/params.sql, analysis/10_load.sql, analysis/30_layovers.sql, analysis/60_export.sql, analysis/README.md, bin/health-card, app/components/layover_table_component.yml, docs/spectra/LANGUAGE.md, spec/support/duckdb.rb, spec/analysis/load_spec.rb, spec/analysis/layovers_spec.rb, spec/analysis/chains_spec.rb, spec/analysis/card_spec.rb, spec/analysis/cli_spec.rb, spec/analysis/derived_export_spec.rb, spec/analysis/fixtures_spec.rb, spec/models/route_day_loader_spec.rb, spec/models/derived_load_command_spec.rb, spec/fixtures/analysis/README.md, spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl, spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - New: (none)
  - Removed: (none)
- 不加 migration，衍生表的欄位不變，`layovers` 只是列數變少。`analysis/derived_export.sql` 與 `app/models/route_day_loader.rb` 讀的是 `layovers` view，不用改。
- 效能：307 在 10-22 的第 10 階段，多讀這張表之後從約 0.85 秒變約 1.05 秒（各跑三次，量到的）。
- 排程：`day-types` 也在改 `spec/fixtures/analysis/README.md`、`spec/analysis/fixtures_spec.rb`、`docs/spectra/LANGUAGE.md`、`spec/models/route_day_loader_spec.rb`、`spec/models/derived_load_command_spec.rb`，它的任務 4.2 也會重載中山幹線。這個 change 等 `day-types` archive 之後再 apply。`route-page-visual-refresh` 改的是 `app/components/layover_table_component.html.erb`，這個 change 只改同一個元件的 `.yml`，不衝突。
- 資料限制與假設：
  - 車不等於人。折返停留仍是駕駛休息的上限。車去開別條路線時，可能是同一個人開，也可能換了人，這裡分不出來，所以這一組不量。
  - 車上人數與刷卡率不牽涉這個定義。
  - 10 秒輪詢會漏站，別條路線的那一趟也會漏。門檻只要 3 個站，真的跑一趟至少 57 個站（量到的），不會因為漏站掉到門檻以下。
  - 跨小時檔的重複：別條路線的記錄一樣照 `(BusID, DataTime)` 去重；而且算的是不同站牌數，重複本來就不影響。
