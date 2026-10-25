## Context

第 20 階段（`analysis/20_trips.sql`）照 `zhongshan-first-health-card` 的決策「切趟規則：方向改變、站序回頭或中斷超過 60 分鐘就是新的一趟」，把每台車、每個路線 `Id` 的到離站事件切成段：`trip_events` 標出每筆事件屬於第幾段，`segmented_trips` 是讀檔視窗裡的每一段，`trips` 是起點落在當天的段。每一段都有 `n_stops_observed`（觀測到的不同站序數），但沒有任何地方用它。後面的階段（折返停留、班次串、載客剖面、資料品質、調度站、衍生表的匯出）全部從 `trips` 讀。

2026-10-25 的 307（16111＋19108）有 112 段只觀測到一個站（量到的，2026-10-26）：

| 位置 | 段數 |
| --- | --- |
| 端點站：板橋前站端返程末站 59、莊敬里端去程末站 38、307西藏三民 去程末站 6、兩個方向的起站各 1 | 105 |
| 端點的前一站 | 6 |
| 起站後第三站 | 1 |

其中 103 段分類成 `missing_start`（那一站是方向的末站）：51 段是那台車當天第一筆記錄，51 段是前一趟到站之後 73 到 338 分鐘（中位數 127）重新出現的第一筆，1 段在兩趟中間。那 51 段空檔裡，每一段都只有一筆記錄，是前一趟到站後 1.8 到 10.3 分鐘（中位數 10.2）同一站再報一次的到站，沒有別條路線的記錄（量到的）。

照 `layover-endpoints` 的決策「折返停留只要本趟觀測到末站、下一趟觀測到起站」，這 103 段可以跟下一趟配成折返停留，而真正的前一趟碰到它，被判成 `no_first_stop`。10-25 的 326 筆折返停留裡有 100 筆是從這種段開始的（莊敬里 43 筆、中位數 8.3 分鐘；板橋前站 57 筆、中位數 7.1 分鐘，量到的）。

量法：把 `analysis/` 複製到 scratchpad，只在 `trips` 加上「觀測站數至少 2」，用 `lib/analysis_run.rb` 的 `AnalysisRun.run` 指定那份目錄，四條頁面路線 × 10-19 到 10-22、10-25 各跑一次，跟現在的 SQL 比。結果在 proposal 的兩張表。

限制：

- 專案開了 `tdd: true`，每個行為先寫會失敗的例子。
- `spec/analysis/params_spec.rb` 檢查編號的階段檔不出現 2、3、7 等常數的字面數字，所以門檻只能用 `getvariable` 讀。
- 正式站的資料由 Mac mini 上的 `bin/nightly-load` 寫，重算要使用者自己跑。網站正在公開票選，307 的數字越早修正越好。

## Goals / Non-Goals

**Goals:**

- 趟次只算真的跑過的段：至少從一站開到另一站。
- 一條規則套用全部路線，不為 307 開特例；其他路線受影響的路線日照實際的數字變。
- 健檢卡寫出丟了幾段，讀卡的人看得到這條規則有沒有在作用。

**Non-Goals:**

- 站序倒退一站造成的切段（10-25 有 6 段、10-22 有 3 段，量到的）。它們觀測到 2 站以上，這次的門檻擋不到，也不產生假的折返停留。另開 change。
- 把幾個小時的長休息排除或另外標示；改 `layover-endpoints` 的配對規則、60 分鐘的切趟門檻、完整性的四類分法。
- 路線頁、首頁與分享文字的文案。數字跟著重算變，程式不用改。
- 查清楚 307 的車機為什麼在端點補報到站。
- 颱風日 10-23、10-24 照舊不載入；重產 `docs/cards/15373-2026-10-19.md`。

## Decisions

### 一段至少觀測到 2 個不同的站才是一趟，門檻寫在參數檔

`analysis/params.sql` 新常數 `min_trip_stops`，值是 2。一段觀測到的不同站數已經是 `segmented_trips.n_stops_observed`，達到門檻的段才是趟次。

理由：

- 詞彙表「趟次與班次」把趟次定義成一次行駛。一段只觀測到一個站，車在這一段裡沒有從一站開到另一站，不管它停在哪一站、是不是端點，都不是行駛。
- 一條規則比「唯一的站是方向末站」好講，也把另外 10 段（漏起站 1、兩端都漏 7、漏末站 2）一起處理掉，它們同樣不是行駛。
- 門檻跟 `split_gap_minutes`、`other_route_min_stops` 一樣是定義常數，照參數檔開頭「改定義只改這裡」。

替代方案：

- 只丟唯一的站是方向末站的段。否決：剩下的單站段一樣不是行駛，規則還多一個條件。
- 在配對時擋，本趟要觀測到 2 站以上才配。否決：趟次數與班表工具的預設發車數照樣多算，那一段也照樣夾在前一趟與下一趟中間，真正的長休息還是量不到。
- 把端點補報併進前一趟：同一站、同方向的到站，不管隔多久都接在前一趟後面。否決：等於改掉 60 分鐘中斷規則的意思；當天第一筆前面沒有趟次可以併，還要再一條規則。
- 加大 60 分鐘的切趟門檻。否決：那 51 段空檔是 73 到 338 分鐘，門檻大到能蓋過，會把真的分開的兩趟接成一趟；當天第一筆也照樣留著。
- 用 `DutyStatus` 切。否決：詞彙表寫它能不能拿來切趟次還待確認。
- 門檻 3 站。否決：觀測到 2 站已經是從一站開到另一站，fixture 的 TEST-0003 09:10 那趟就是 2 站的 `missing_end`。

### 過濾放在 trips，segmented_trips 照舊列出每一段

`trips` 本來就在篩「起點落在當天」，觀測站數的條件加在同一個 WHERE。`trip_id` 在篩完之後編，所以照舊連續。`segmented_trips` 不動，仍是讀檔視窗裡的每一段，`spec/analysis/trips_spec.rb` 檢查跨日段的例子讀的就是它。新 view `few_stop_segments` 列出起點落在當天、觀測站數不到門檻的段，欄位跟 `segmented_trips` 相同，只給資料品質計數。

理由：後面的階段全部從 `trips` 讀，只改這一處，折返停留、班次串、載客剖面、資料品質的完整性與首末趟、調度站、衍生表就全部跟著變，不會有某個階段漏改。

`spec/analysis/trips_spec.rb` 的「切趟」那一組每例只灌兩筆事件，方向改變、站序回頭、中斷 65 分鐘、同站先到後離四例切出來的段都只有一個站，照新規則一趟都不剩。這一組測的是切法，不是哪些段算趟次，所以改讀 `segmented_trips`：預期的段數 1、2、2、2、1 不變，例子名稱的「切成 N 趟」改成「切成 N 段」。Trip segmentation 這條需求不用改，新增的 Segments observing too few stops are not trips 已經寫明切出來的是段、達到門檻的段才是趟次。

替代方案：

- 在 `segmented_trips` 就丟掉。否決：要另外重算一次才數得到丟了幾段，跨日段的檢查也看不到原始的切法。
- 每個讀 `trips` 的階段各自篩。否決：五個以上的地方，漏一處就有兩套趟次。

### 長休息照現有規則算成折返停留，不另外排除

那一段不再是趟次之後，同一台車的前一趟與下一趟相鄰，照 `layover-endpoints` 的規則配成一組。10-25 這樣新配出來的有莊敬里 22 組、板橋前站 30 組，中位數 170 與 127 分鐘；10-22 是 30 組與 26 組，中位數 146 與 120 分鐘（量到的，原型）。這些空檔裡沒有別條路線的記錄，`other_route` 五天都是 0（量到的，原型）。

理由：

- 詞彙表「折返停留」寫明它包含回場、加油、洗車、等發車在內的一切，是駕駛休息的上限。車停兩個小時、車機關掉，正是這種情況。
- 其他路線車停很久再發車時一直這樣算：下一趟直接從起站離站，前一趟就跟它配成一組，不管隔多久。307 只是多了一筆補報，把這一組擋掉了。
- 摘要報的是中位數與不到 15 分鐘的比例，長的那一端只影響筆數，不會被一兩個極端值帶走。

替代方案：

- 空檔裡沒有記錄超過一定時間就不算。否決：這會改全部路線的定義，而且「車機關掉」跟「停在場站、車機關掉」分不出來，兩種都是休息的機會。
- 算進 `other_route` 或另一類排除。否決：車沒有去跑別的路線，`layover-endpoints` 的決策「量不到的配對只計數，不當證據」講的是端點量不到，這裡兩個端點都量得到。

### 不算趟次的段數只在健檢卡的資料品質一節報

`analysis/50_quality.sql` 的 `quality` 多一列 metric `few_stop_segments`、subject 空字串、value 是 `few_stop_segments` 的列數。卡的 JSON 在 `quality` 底下多兩個鍵：`few_stop_segments`（段數）與 `min_trip_stops`（門檻）。`bin/health-card` 資料品質一節照「健檢卡的文案」印一行。衍生表與路線頁不放。

理由：這是資料品質的數字，照 `zhongshan-route-page` 的非目標「班次串、歸零檢查、資料品質數字搬上頁面」，它們留在健檢卡。頁面上的趟次、折返停留本身已經是對的數字。

替代方案：在 `route_days` 加欄位、放進路線頁的資料限制。否決：要 migration，頁面也多一句讀者不需要的話。

### 健檢卡的文案

資料品質一節，完整性的表格之後、漏站率那一行之前，加一段說明與一行數字，門檻從 JSON 讀：

- 說明：「切出來的段至少要觀測到 {min_trip_stops} 個不同的站才算一趟，觀測到的站比這少的段不在上面的表裡，也不跟前後的趟次配成折返停留。」
- 數字：「- 觀測到的站少於 {min_trip_stops} 站、不算趟次的段：{few_stop_segments} 段」

fixture 2026-10-19 印出「- 觀測到的站少於 2 站、不算趟次的段：0 段」。不寫 307 或端點補報：卡是每條路線共用的，原因寫在詞彙表與這個 change。

### 測試用灌入的事件，fixture 不動

fixture 2026-10-19 與成員日 2026-10-23 跑路線 9001 時都沒有只觀測到一站的段，最少的是 TEST-0003 09:10 那趟的 2 站（量到的）。新行為用 `spec/support/duckdb.rb` 的 `replace_stop_events_sql` 灌事件，第 20 階段以後的 view 會從這些事件重建：

| 例子 | 灌入的事件（TEST-0001，2026-10-19，路線 9001） | 預期 |
| --- | --- | --- |
| 當天第一筆是補報 | 06:09 去程 seq 4 到站；06:19 返程 seq 5 離站、06:50 seq 7 到站、07:41 seq 9 到站 | 趟次只有 06:19 那趟，`few_stop_segments` 1 段（06:09） |
| 隔一段時間的補報 | 07:59 去程 seq 0 離站、08:40 seq 2 到站、09:30 seq 4 到站、09:40 seq 4 到站、13:01 seq 4 到站；13:14 返程 seq 5 離站、14:10 seq 7 到站、15:05 seq 9 到站 | 趟次是 07:59 與 13:14 兩趟，都完整；`few_stop_segments` 1 段（13:01）；折返停留一筆 224.0 分鐘，結束在去程；沒有折返停留結束在 13:01 |
| 2 站照舊是趟次 | 08:00 返程 seq 5 離站、08:05 seq 6 到站 | 一趟，`missing_end`，`n_stops_observed` 2 |
| 同一站先到後離 | 13:01 去程 seq 4 到站、13:05 seq 4 離站 | 不是趟次，`few_stop_segments` 1 段 |

折返停留的例子用 `replace_other_route_events_sql([])` 清掉 fixture 別條路線的記錄。路線 9001 的 fixture 斷言（27 趟、18 筆折返停留、班次串、資料品質、衍生表與卡一致）全部不改、仍要綠，證明這條規則對沒有單站段的資料不起作用。

既有的灌事件例子：只有「切趟」那一組要改讀 `segmented_trips`（上一條）。`spec/analysis/quality_spec.rb` 與 `spec/analysis/depots_spec.rb` 灌的每一段都至少 2 站，不受影響；其他 spec 灌的是趟次（`replace_trips_sql`），不經過這個過濾。fixture 拿 2026-10-20 當資料日、用 10-19 的快照時，TEST-0004 隔天 02:10 那一筆會自成一段、只有一站，照新規則不算趟次；用到 10-20 的例子只檢查卡頭（`spec/analysis/card_spec.rb`）與結束碼、產出的檔案（`spec/analysis/cli_spec.rb`），不受影響（量到的，2026-10-26）。

例外是對照路線 9100 自己被當成一條路線跑的時候。`bin/rails survey:end_natures` 對 fixture 會跑 9001 與 9100 兩條路線，TEST-0002 在 9100 的三筆記錄（14:10、14:20 在去程的兩站，14:30 在返程起站）切成兩段：14:10–14:20 是一趟完整的去程，結束在丑站；14:30 那一段只觀測到一站。照新規則它不是趟次，14:10–14:20 那趟就沒有下一趟可配，`end-nature-survey` 的 fixture 報告裡 9100 丑站的折返停留從 6 筆變 5 筆，其他格不變（量到的，2026-10-26 apply 時 `make test` 只有 `spec/models/end_nature_survey_command_spec.rb` 的這一格不同）。這三筆是給 9001 測「兩趟之間在別條路線經過 3 個站」用的，所以 fixture 照樣不動，改 Survey report 的 Example 與那個測試的預期值。

替代方案：

- fixture 加一台有補報的車。否決：十幾個 spec 的手算值（折返停留 18 筆、資料品質、班次串、衍生表列數）都要跟著改，測到的東西跟灌事件一樣。
- 改 fixture，讓 9100 沒有單站段。否決：9100 一個方向只有 2 站，三筆經過 3 個不同的站，一定有一個方向只有一站，跑 9100 時那一站就自成一段；改成四筆、經過 4 個站，9001 那邊「3 個站」的例子、fixture README 與 `layover-metrics` 寫到 3 個站的情境都要跟著改。

### 正式站四條路線全部重算

這個 change commit、push 之後，使用者在 Mac mini 的 website checkout 拉到新程式，先跑 `bin/nightly-load --recompute` 看計畫，再跑 `bin/nightly-load --recompute --load`，照 `nightly-derived-load` 的決策「bin/nightly-load 不加參數只印計畫，--load 才寫，--recompute 重算」。不加 `ROUTE`，四條路線的 20 個路線日全部重算。筆電的開發資料庫用 `derived:load` 重算四條路線的 10-19 到 10-22，本機頁面才跟程式一致。

理由：其他三條路線也有三個路線日的數字會變（proposal）。只算 307，正式站就同時存在兩套定義算出來的數字。

時間：10-26 02:36 那次寫 4 個路線日共 41 秒，沒有要載入的那幾次是 6 到 7 秒（量到的，`_nightly-load.out`）；20 個路線日估計 3 分鐘左右，那次執行自己的開頭與結尾時間戳就是量測，沒有決定依賴這個估計。

### 307 兩端的查證註解補一句 change 之後的數字

`config/route_page.yml` 16111 兩端的註解保留原本的查證證據，各補一句：這個 change 之後同一天（2026-10-22）的折返停留筆數與中位數，以及去掉的配對是從只觀測到一站的段開始、而且是短的那些，所以結論不變。數字取自 change 之後的 `bin/health-card`，預期莊敬里 188 筆、中位數 16.4，板橋前站 185 筆、中位數 17.8。

理由：去掉的配對是短的（10-22 中位數 9.9 與 8.8 分鐘），新配出來的是長的（中位數 146 與 120 分鐘），「停車」的證據只會更強，不用重做一次 GPS 查證。原本的數字是當時用當時的定義量的，留著才對得上 `02-route-307-page` 的紀錄。

替代方案：用 `bin/rails survey:end_natures` 重算靜止時間，整段改寫。否決：結論不會變，改寫反而對不上當時的查證紀錄。

## Implementation Contract

**行為**

- 任何路線日，`trips` 與建在它上面的一切只含觀測到至少 `min_trip_stops` 個不同站的段。觀測站數不到門檻的段，不進趟次數、完整性、首末趟、折返停留的配對、班次串的序列、載客剖面、調度站，也不寫進衍生表。
- 同一台車夾著那種段的前後兩趟，在配對上是相鄰的兩趟，照原本的規則算折返停留。
- 健檢卡的資料品質一節寫出不算趟次的段數；fixture 是 0 段。

**介面與資料形狀**

- `analysis/params.sql`：`SET VARIABLE min_trip_stops = 2;`，註解寫一段至少觀測到這麼多個不同的站才是一趟，一個站不是行駛。
- `analysis/20_trips.sql`：`trips` 的條件多 `n_stops_observed >= getvariable('min_trip_stops')`；新 view `few_stop_segments`，欄位同 `segmented_trips`，只留起點落在 `day`、`n_stops_observed` 小於門檻的段；檔頭的 view 清單補上它，`segmented_trips` 的註解寫明它是每一段、不全是趟次。
- `analysis/50_quality.sql`：`quality` 多一列 `('few_stop_segments', '', 段數)`；檔頭的讀取清單補上 `few_stop_segments`。
- `analysis/60_export.sql`：卡的 JSON `quality.few_stop_segments`（整數）、`quality.min_trip_stops`（整數）。
- `bin/health-card`：資料品質一節照「健檢卡的文案」。
- 輸出：`quality.csv` 多一列；受影響路線日的 `trips.csv`、`layovers.csv`、`chains.csv`、`profile.csv` 列數跟著變。衍生表欄位不變，不加 migration。
- 文件：詞彙表「趟次與班次」的邊界、`analysis/README.md` 第 20 階段與資料品質的說明。

**失敗模式**

沒有新的。門檻讀不到時 `n_stops_observed >= NULL` 會讓 `trips` 變空，`spec/analysis/params_spec.rb` 的新例子與 fixture 的 27 趟都會失敗。

**驗收**

- `spec/analysis/params_spec.rb`：`min_trip_stops` 是 2；既有「其他 SQL 檔不出現這些常數的字面數字」仍綠。
- `spec/analysis/trips_spec.rb`、`spec/analysis/layovers_spec.rb`、`spec/analysis/quality_spec.rb`：「測試用灌入的事件，fixture 不動」那張表的四個例子。
- `spec/analysis/card_spec.rb`：資料品質一節有「觀測到的站少於 2 站、不算趟次的段」，值是「0 段」。
- `spec/analysis/trips_spec.rb` 的「切趟」那一組改讀 `segmented_trips`，預期段數不變。
- `spec/models/end_nature_survey_command_spec.rb`：fixture 報告裡 9100 丑站的折返停留是 5 筆，其他格照 `end-nature-survey` 的 Example。
- 其他既有的 fixture 斷言全部不改、仍綠；`make test` 全綠；`bin/rubocop` 對改到的 Ruby 檔沒有 offense。
- 真資料：`bin/health-card` 對四條路線五天的趟次與兩端折返停留，等於 proposal 兩張表的原型數字；307 的 `few_stop_segments` 10-25 是 112、10-22 是 149；20 個路線日的完整趟次不變，班次串只有中山幹線 10-20 從 11 串變 12 串。
- 正式站重算後，`/routes/16111?day=2026-10-25` 的趟次卡是 372 趟，兩端的中位數與比例照 proposal。

**範圍**

- 在範圍內：第 20、50、60 階段與參數檔、健檢卡的資料品質一節、詞彙表與 `analysis/README.md`、307 的查證註解、兩端性質調查 fixture 報告的預期值（`end-nature-survey` 的 Example 一格）、筆電開發資料庫與正式站的重算。
- 不在範圍內：路線頁與首頁的程式與文案、站序倒退的切段、配對規則與切趟門檻、長休息的處理、衍生表的欄位。

## Risks / Trade-offs

- [真的跑過的一趟只觀測到一站，會被丟掉] → 307 一個方向 61 到 66 站、10-25 完整趟次的漏站率 1.6%（量到的），一整趟只抓到一站不合理；卡上有段數，數字突然變大看得出來。
- [307 停車端的中位數一下子變長，例如 10-25 板橋前站 14.2 → 27.4 分鐘] → 這是現有定義下正確的數字；頁面的資料限制已經寫明折返停留是休息的上限。
- [正式站在使用者重算之前還是舊數字] → 每個路線日在一個交易裡整個換掉（`derived-tables` 的 Replace one route day atomically），不會有半新半舊的路線日；重算排在 push 之後馬上做。
- [其他三條路線有三個路線日的數字跟著變] → proposal 列出每一個，重算全部路線日。
- [夾著單站段的兩趟完整趟次在班次串裡變成相鄰，原本被切斷的序列接起來，可能多出不合規的串] → 這是 Implementation Contract 寫的行為：那種段不進班次串的序列。2026-10-26 apply 時 20 個路線日只有中山幹線 10-20 多一串（11 → 12，量到的）：一筆被站序倒退切出來的單站段原本切斷序列，拿掉之後 15:36–20:56 四趟完整趟次相鄰，達到 15 分鐘的休息只有 21.0 分鐘一段。卡與路線頁照實報，proposal 的 Problem 寫了原因。
- [`timetable-sheet-touchups` 也在改 `docs/spectra/LANGUAGE.md`] → 改的是不同條目；commit 時只帶這個 change 的修改。

## Migration Plan

1. 照 tasks 實作、測試，筆電重算開發資料庫。
2. 使用者 commit、push。
3. 使用者在 Mac mini 的 website checkout 拉到新程式，跑 `bin/nightly-load --recompute`（只印計畫，應列出 20 個路線日），再跑 `bin/nightly-load --recompute --load`。
4. 檢查正式站 `/routes/16111?day=2026-10-25` 等頁面。

退回：revert 這個 commit、push，在 Mac mini 上跑同一組重算，衍生表就回到舊定義。
