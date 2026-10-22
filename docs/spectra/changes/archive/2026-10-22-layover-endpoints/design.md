## Context

折返停留是專案兩個核心證據之一（「折返點實際能休幾分鐘」），一天版的健檢卡（`bin/health-card`）、路線頁的折返停留一塊、換休息試算都讀它。它在 `analysis/30_layovers.sql` 定義：`layover_pairs` 把每台車相鄰兩趟配成一組，依序判斷「有一趟不完整」「下一趟是別的路線」「差值為負」，都不是才算進 `layovers`；`layover_exclusions` 給三類的計數，`analysis/60_export.sql` 把它放進卡的 JSON，`bin/health-card` 印成「不算折返停留的相鄰配對」一行。`derived_export.sql` 把 `layovers` 寫進衍生表，路線頁與試算從衍生表讀。

已核對的事實：

- 趟次的起點取起站最晚一次離站，終點取末站最早一次到站（`analysis/20_trips.sql` 的 `segmented_trips`）。所以一趟只要觀測到方向的末站，它的終點就是末站到站；只要觀測到方向的起站，它的起點就是起站離站。完整度分類：`complete`、`missing_start`（有末站、沒起站）、`missing_end`（有起站、沒末站）、`missing_both`（`trip-reconstruction` 的分類規則）。
- 班次串的序列 `rest_runs` 只收完整趟次，遇到不完整就切斷；休息額度用 `layovers` 依 `trip_id` 接上，只取序列內位置小於視窗最後一趟的那些趟次的折返停留。
- 中山幹線 15373 三天的配對分佈（量到的）見 proposal；放寬後 247 → 333 筆，剩下 75 組量不到，它們的表面間隔中位數約 41 分鐘。

詞彙依 `docs/spectra/LANGUAGE.md`：折返停留、趟次、漏站、起站、末站、班次串。「折返停留」一條的「在資料或程式碼裡」目前只寫「相鄰兩個趟次的衍生值」，這個 change 補上成立條件。

## Goals / Non-Goals

**Goals:**

- 折返停留只要求它真正用到的兩個時刻：本趟的末站到站、下一趟的起站離站。
- 量不到的配對按「缺哪一端」計數，資料品質看得出原因。
- 一天版的卡、路線頁、換休息試算同時用新定義，數字彼此一致。

**Non-Goals:**

- 推算或補值量不到的配對。
- 改變行駛時間、班次串、趟次重建與完整度分類。
- 把班次串或排除計數搬上路線頁；平日與假日分開；其他路線；排程與部署。

## Decisions

### 折返停留只要本趟觀測到末站、下一趟觀測到起站

**Supersedes**: zhongshan-first-health-card / 折返停留只算同一車牌相鄰兩個完整趟次，最後一趟不算

對每個車牌把趟次依起點時刻排序，相鄰兩趟成一組。一組算一筆折返停留的條件：本趟的完整度是 `complete` 或 `missing_start`（有觀測到末站），下一趟是 `complete` 或 `missing_end`（有觀測到起站），兩趟同一路線 `Id`，下一趟起點不早於本趟終點。分鐘數仍是下一趟起點減本趟終點。當天最後一趟沒有折返停留。

不成立的配對分四類，一組同時符合幾類時算在列出的第一類：

1. `no_last_stop`：本趟沒有到末站（`missing_end` 或 `missing_both`）。
2. `no_first_stop`：下一趟不是從起站出發（`missing_start` 或 `missing_both`）。
3. `other_route`：下一趟是別的路線。
4. `negative`：差值為負。

理由：折返停留的兩個端點只依賴本趟的末站與下一趟的起站，另一端漏站不影響這兩個時刻。舊規則要求兩趟都完整，在中山幹線三天擋掉了 86 組兩個端點都量到的配對（佔所有配對的 21%，量到的）。被推翻的決策當時沒有寫理由與替代方案。

替代方案：維持兩趟都完整（樣本少三分之一，沒有對應的好處）；把任何不完整的配對都算進來（漏的是端點時，間隔是拿中途某一站代替端點量的，會比實際長）。

### 量不到的配對只計數，不當證據

剩下量不到的配對缺的正是端點，表面間隔不代表停留。卡只報四類的組數，不報它們的分鐘數；詞彙表的「折返停留」一條寫明這一點。

### 班次串不跟著放寬

`rest_runs` 仍只收完整趟次。新規則多出的配對，至少有一趟不完整：本趟不完整時它不在任何序列裡；本趟完整而下一趟不完整時，本趟是序列的最後一趟，休息額度只取位置小於視窗最後一趟的折返停留，不會取到它。所以班次串的結果不變。

理由：班次串要的是一段連續、時刻都可信的行駛，漏站的那一趟起點或終點不在端點上，四小時視窗會算錯。

### fixture 2026-10-19 的手算值

新規則在 fixture 多出 3 筆（依 `spec/fixtures/analysis/README.md` 的趟次表手算）：

| 車牌 | 本趟 | 下一趟 | 分鐘 | 結束那趟方向 |
| --- | --- | --- | ---: | --- |
| TEST-0002 | 返程 07:40:30–08:16:00，`missing_start` | 去程 08:30:00 起，`missing_end` | 14.0 | 返程 |
| TEST-0003 | 去程 08:08:00–08:56:00，`complete` | 返程 09:10:00 起，`missing_end` | 14.0 | 去程 |
| TEST-0003 | 返程 10:28:00–10:52:00，`missing_start` | 去程 11:15:00 起，`complete` | 23.0 | 返程 |

折返停留共 19 筆，每台車依結束時刻：TEST-0001 不變（10.0、12.0、13.0、10.0、56.0、21.0、25.0、85.0）；TEST-0002 是 14.0、12.0、302.0、12.0、282.0；TEST-0003 是 15.0、14.0、23.0、17.0；TEST-0004 不變（17.0、12.0）。去程結束 10 筆（原 9 筆加 14.0），返程結束 9 筆（原 7 筆加 14.0、23.0）。

量不到的配對 4 組：`no_last_stop` 3 組（TEST-0002 去程 08:30 起那趟接 09:30:30 那趟、09:30:30 那趟接 10:20 那趟；TEST-0003 返程 09:10 起那趟接 10:28 那趟），`no_first_stop` 1 組（TEST-0002 06:35 那趟接 07:40:30 那趟），`other_route` 與 `negative` 都是 0。班次串仍只有一條：TEST-0001 06:00 到 11:30，5 趟。

## Implementation Contract

**Behavior**

- `bin/health-card` 對 fixture 2026-10-19 的卡：折返停留整體 19 筆，去程結束 10 筆、返程結束 9 筆；「不算折返停留的相鄰配對」一行是「本趟沒有到末站 3 組、下一趟不是從起站出發 1 組、下一趟是別的路線 0 組、差值為負 0 組」；班次串 1 串、涉及 1 台車，與現在相同。說明文字改成新的成立條件。
- `derived:load` 寫入 fixture 2026-10-19：趟次 27、折返停留 19、趟次站 96。
- 路線頁折返停留一塊的筆數與百分位數，等於卡上同一天的值（既有的一致性測試）；說明文字改成新的條件。
- 中山幹線重跑 2026-10-19 到 10-21 後，三天合計的折返停留是 333 筆。

**Interface / data shape**

- `layover_pairs.category` 的值：`layover`、`no_last_stop`、`no_first_stop`、`other_route`、`negative`。
- `layover_exclusions` 的欄位：`no_last_stop`、`no_first_stop`、`other_route`、`negative`（移除 `incomplete`）。
- 卡的 JSON：`layovers.exclusions` 是 `{no_last_stop, no_first_stop, other_route, negative}`。
- `layovers` view 與衍生表 `layovers` 的欄位不變。

**Failure modes**

- 沒有任何配對時，四類都是 0，折返停留 0 筆，跟現在一樣。
- `missing_both` 的趟次永遠不會出現在任何一筆折返停留裡。

**Acceptance criteria**

- `spec/analysis/layovers_spec.rb`：fixture 的 19 筆依車牌與順序、四類排除計數；灌入的趟次各一例斷言本趟 `missing_start` 接下一趟 `missing_end` 算一筆、本趟 `missing_end` 不算（`no_last_stop`）、下一趟 `missing_start` 不算（`no_first_stop`）、兩端都缺時算在 `no_last_stop`。
- `spec/analysis/chains_spec.rb` 與卡的班次串斷言不改仍綠。
- `spec/analysis/card_spec.rb`、`spec/analysis/cli_spec.rb`、`spec/analysis/derived_export_spec.rb`、`spec/models/route_day_loader_spec.rb`、`spec/models/derived_load_command_spec.rb` 的筆數與分佈改成從上面 19 筆手算的值。
- `make test`、`bin/rubocop`（改到的 Ruby 檔）、`bin/brakeman` 全綠。

**Scope boundaries**

- 在範圍內：`analysis/30_layovers.sql`、`analysis/60_export.sql`、`bin/health-card` 的折返停留一節、`app/components/layover_table_component.yml` 的說明、上面列的測試與 fixture 說明、`docs/spectra/LANGUAGE.md` 的「折返停留」、`analysis/README.md`、重跑中山幹線三天的 `derived:load`。
- 不在範圍內：`analysis/20_trips.sql`、行駛時間、`rest_runs` 與班次串的計算、migration、路線頁新增區塊。

## Risks / Trade-offs

- [新的配對多半是短停留（中位數約 2 分鐘），折返停留的分佈整體變短] → 這是把原本量得到卻被擋掉的資料算進來，不是偏誤；被擋掉的 86 組與原本 247 組的中位數接近（2.0 到 2.2 對 2.8 分鐘，量到的）。剩下量不到的 75 組不能判斷它們的真實長短，資料限制已寫明折返停留只算量到的。
- [卡與頁面的數字跟上一版不同，已經截圖或引用的舊數字會對不上] → 一天版的卡本來就標明不能引用；這個 change 在詞彙表與卡的說明寫明新定義。
- [`missing_start` 的趟次可能是車從中途進入營運，它的「末站到站」仍是真的末站，但它前面那一組配對量不到] → 那一組算在 `no_first_stop`，不影響本筆。
