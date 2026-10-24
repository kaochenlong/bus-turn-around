## Context

路線頁只開給 `config/route_page.yml` 列出的路線。每條路線的兩端要先人工查證是停車還是直接折返，才寫得進設定，這是 `zhongshan-turnaround-ends` 的決定「折返點的性質是逐路線查證後寫進設定的事實，不從資料推」，目前仍然有效。它的理由與替代方案是：

- 要自動推，得先在幾條路線上看過推得對不對；當時只有一條路線，寫成規則等於拿一個樣本定門檻。
- 推錯的代價是試算整個換掉基礎，而且沒有人會發現。
- 替代方案「從閒置車 GPS 聚類推」留到設施那個 change 之後。設施那個 change（`turnaround-facilities`）已經歸檔，它的非目標「從折返停留或 GPS 推哪一端停車」是那個 change 自己的範圍限制，後面的 change 可以做。

現在有 4 條路線、8 個端點人工查證過，查證用的量法寫在 `route-251-pages` 的 design：對每一筆折返停留，取那台車在本趟末站到站與下一趟起站離站之間的每個 GPS 點，量「最遠離站」與「最長靜止」兩個數。307 的查證把最長靜止近似成「連續速度 0、相鄰兩筆相距 50 公尺內的一段」（`02-route-307-page` 任務 6.1 的查證紀錄）。8 個端點的證據：

| 路線與那一端 | 設定 | 折返停留中位數 | 最長靜止 | 出處 |
| --- | --- | --- | --- | --- |
| 中山幹線 去程結束，青年公園(馬場町) | `pass_through` | 1.9 分鐘（10-20，75 筆） | 當時沒有算最長靜止；GPS 沒有離開馬場町到青年社宅那一段 | `config/route_page.yml` 註解 |
| 中山幹線 返程結束，職能發展學院二 | `stop` | 17 分鐘（10-19 到 10-22） | 沒有紀錄 | `docs/background.md` |
| 251 去程結束，臺北車站(開封) | `pass_through` | 2.3 分鐘 | p50 0.0、最大 2.0 | `route-251-pages` design |
| 251 返程結束，福安居一 | `stop` | 44.4 分鐘 | p50 14.4、最大 266.7 | 同上 |
| 251區 去程結束，捷運公館站 | `pass_through` | 2.8 分鐘 | p50 0.0、最大 1.3 | 同上 |
| 251區 返程結束，福安居一 | `stop` | 19.7 分鐘 | p50 3.5、最大 287.3 | 同上 |
| 307 去程結束，莊敬里 | `stop` | 13.3 分鐘 | 211 筆有 GPS，168 筆靜止 2 分鐘以上，p50 4.8 | `02-route-307-page` 任務 6.1 |
| 307 返程結束，臺北客運板橋前站(藝文) | `stop` | 14.4 分鐘 | 223 筆有 GPS，198 筆靜止 2 分鐘以上，p50 11.0 | 同上 |

除了 307 是 10-22 合併兩個 Id 的資料，其餘都是 10-22 一天的查證（中山幹線兩端除外，出處寫在表裡）。`route-251-pages` 的判讀還留下一句話：市區端如果誤標成直接折返、其實是「停車但只停兩分鐘」，試算就把真正的問題排除掉了，所以不能只看折返停留的中位數。

其他事實（2026-10-24 量到的）：

- 10-22 的快照有 416 個路線 Id，398 個當天有到離站事件，其中至少 2 台車的 347 個、至少 5 台車的 229 個。11 個路線 Id 的站序只有一個方向。
- 一條路線一天照 `derived:load` 跑編號階段、`mrt_overlap.sql` 與 `turnaround_facilities.sql`，在這台筆電上是 3.0 到 3.5 秒（16111 3.5、15373 3.1、10142 3.0）。四天、約 400 條路線是約 1,600 次，估約 1.5 小時；實際時間由試跑那個任務記錄。
- 規格 `derived-tables` 的「Derived export」寫明 `bus_data` 的小時檔只由 `analysis/turnaround_facilities.sql` 讀。它建出的 `gps_reports` 是那台車在讀檔視窗內的所有 GPS 回報，每個 `(BusID, DataTime)` 一筆。
- `analysis/60_export.sql` 最後會印出健檢卡的 JSON，所以分析跑的時候不能再印別的結果，否則 `AnalysisRun.run` 讀不回 JSON；要拿結果出來，得像 `analysis/derived_export.sql` 一樣用 `COPY … TO` 寫檔。
- 10-23 的 `bus_event` 一整天約 15 MB，10-19 到 10-22 每天約 37 MB，量偏低。

這個 change 排在 `01-pass-through-wording` 之後：摘要與詞彙表用它定的「直接折返」。

## Goals / Non-Goals

**Goals:**

- 用人工查證時的同一種證據，把全路網每條路線的每一端判斷一次，判斷規則與門檻在看到全路網結果之前先寫死。
- 讓人一眼看出規則對 8 個查證過的端點對不對、全路網有多少端點分得清楚、有多少要人看、為什麼（樣本太少還是介於門檻之間）。
- 順手留下「兩趟之間跑了別的路線」的配對數，供之後判斷哪些路線 Id 要合成一頁。
- 不動任何頁面、設定、衍生表；調查可以重跑，重跑時沒變的路線日直接沿用。

**Non-Goals:**

- 把判斷放上路線頁、寫進衍生表、改 `config/route_page.yml`：`zhongshan-turnaround-ends` 的決定在這個 change 裡照舊有效。要不要推翻它，由使用者看過「調查結果」之後決定，推翻要在下一個 change 的 design 用 Supersedes 記下。
- 決定哪些路線 Id 合成一頁。
- 把 `gps_reports` 從 `turnaround_facilities.sql` 拆出來、把 `haversine_meters` 移到 `params.sql`，以及讓全路網跑得更快、排程、推正式站。
- 為循環路線、預約公車、區間車另外定規則。

## Decisions

### 試跑只寫檔，不寫衍生表、不改頁面與設定

調查的所有輸出都在 `OUT`（預設 `tmp/end-natures/`，`.gitignore` 已經排除 `tmp/`）：每個路線日的證據檔、設定的性質、報告。指令不碰 ActiveRecord 的寫入、不改 `config/route_page.yml`，路線頁照舊只認設定。

理由：`zhongshan-turnaround-ends` 要先看過「推得對不對」，這次就是去看，還沒到用的時候。只寫檔也讓調查可以隨便重跑、刪掉重來。

替代方案：把證據寫進衍生表（例如 `route_day_ends` 多幾欄），下一個 change 直接用。否決：那等於先決定了「判斷要放上頁面」，而且全路網的路線日會一起被 `bin/push-derived` 推上正式站（`docs/decisions.md` 第 12 條，整份換掉）。

### 每個路線日照 derived:load 的分析跑一次，再接證據檔

每個路線日跑 `params.sql`、全部編號階段、`mrt_overlap.sql`（定義 `haversine_meters`）、`turnaround_facilities.sql`（建 `gps_reports`，兩端性質都給 `unknown`，所以它的位置、公廁、靜止格都是空的），最後接兩個新檔：

- `end_nature_evidence.sql`：建證據的 view。
- `end_nature_export.sql`：把證據寫成兩個 CSV。

成員路線照 `RoutePage.member_route_ids`，跟 `derived:load` 一樣。外部快照用最新的那一份，跟 `derived:load` 一樣。

理由：

- 證據要建在頁面用的同一批趟次與折返停留上，最直接的做法就是跑同一串 SQL。
- 不把 `gps_reports` 拆出來，是因為規格 `derived-tables` 寫死了只有 `turnaround_facilities.sql` 讀 `bus_data`；這個 change 的工作是量，不是改每晚的流程。拆法留給要把性質改成從資料推的下一個 change，它本來就得重排設施那一段（位置現在要靠設定的性質決定哪一端推）。

替代方案：

- 另寫一支讀全路網、一次算完的 SQL。否決：會出現第二套趟次與折返停留的定義。
- 一天只讀一次原始檔、所有路線一起算。否決：現在的階段檔一次只處理一頁的路線，要改每一個階段，留給批次載入的 change。

### 一筆折返停留的證據沿用人工查證的量法

`end_nature_evidence.sql` 建 view `layover_evidence`，每一筆折返停留（`30_layovers.sql` 的 `layovers`，成員路線之間照樣配對）一列：

- **兩站**：本趟的路線 Id 與方向的末站，下一趟的路線 Id 與方向的起站，都從 `stops` 取 `seq` 最大與最小的那一站。兩站距離用 `haversine_meters`，取一位小數。
- **GPS 回報**：`gps_reports` 裡那台車在本趟終點到下一趟起點之間的回報，含兩端，不看 `RouteID`；沒有數字座標的不算。記下筆數。
- **最遠離站**：每一筆回報離兩站裡較近那一站的距離，取最大，一位小數。
- **最長靜止**：回報依時間排序，速度 0 的回報，如果前一筆也是速度 0 而且距離在 `standstill_radius_meters`（50 公尺）內，就接在同一段，否則開新的一段；一段從第一筆量到最後一筆，取最長那一段的分鐘數，一位小數。有回報但沒有速度 0 的是 0.0；沒有回報的，最遠離站與最長靜止都是空的。

理由：這就是 `route-251-pages` 與 `02-route-307-page` 人工查證時量的兩個數，量法相同，查證過的端點才能直接拿來對照。

- 相鄰 50 公尺的條件照 307 的查證，可以擋掉 GPS 跳點把兩個停車位置接成一段。
- 速度不是 0 的回報會切斷一段，因為車動過了。
- 回報之間的空檔不切斷一段：車停著時回報本來就稀，車機甚至可能不回報。

這樣量會比實際少，最多少一個回報間隔，見 Risks。

替代方案：

- 只看折返停留的中位數。否決：`route-251-pages` 已經說過「停兩分鐘」跟直接折返從分佈分不出來。
- 用靜止回報的筆數。否決：車機回報的頻率不一，筆數不能換成時間。

### 判斷規則與門檻事先寫進 params.sql

`analysis/params.sql` 加四個常數，判斷只在 `end_nature_survey.sql` 用它們：

| 常數 | 值 | 意思 |
| --- | --- | --- |
| `nature_still_minutes` | 2 | 最長靜止超過這個分鐘數，這筆折返停留算停下來過 |
| `nature_min_layovers` | 20 | 一端有 GPS 的折返停留少於這個數，判斷不出來（`few_layovers`） |
| `nature_pass_through_max_share` | 0.05 | 停下來過的比例不超過這個值，是直接折返 |
| `nature_stop_min_share` | 0.5 | 比例至少這個值，是停車；介於兩者之間是 `between` |

每一端把調查的所有日子合起來算。數字的根據是上面那張表：

- 「超過」2 分鐘：三個直接折返的端點最長靜止都沒有超過 2.0 分鐘（251 臺北車站端剛好 2.0），用「超過」讓它留在門檻下。
- 停車至少 50%：307 兩端停 2 分鐘以上的比例是 168／211 與 198／223；251 與 251區 停車端的最長靜止中位數 14.4 與 3.5，都超過 2，所以超過一半。
- 直接折返不超過 5%：三個直接折返端點的比例都是 0。留 5% 給偶爾等一下的車，不再放寬，因為把「只停兩分鐘」的端點判成直接折返，正是 `route-251-pages` 說的那種會把問題藏起來的錯。
- 至少 20 筆：四天的調查等於每天至少 5 筆。少於 20 筆時，一筆就佔 5 個百分點，跟直接折返的門檻一樣大。

中山幹線停車端沒有最長靜止的紀錄，這次調查會補上。

理由：先寫死規則與門檻，再看全路網，結果才算是檢驗，不是事後挑門檻。調查之後要改門檻，用 `/spectra-ingest` 改這一節，並寫明看到什麼才改。

替代方案：先跑全路網、看分佈再定門檻。否決：那就變成拿要檢驗的資料來定規則，正是 `zhongshan-turnaround-ends` 擔心的事。

### 每一端另外記配對的排除數

`end_nature_evidence.sql` 另建 view `end_pair_counts`：頁面路線每個方向一列，數結束在那個方向的趟次配對，照 `layover_pairs.category` 分成 `layover`、`no_last_stop`、`no_first_stop`、`other_route`、`negative`。

理由：

- 307 合成一頁，是因為分開算時大量配對被判成「兩趟之間跑了別的路線」，全是去跑 307西藏三民。全路網哪些路線像 307，這個數字直接看得出來，而且同一次執行就算得到。
- 一端樣本太少時，也看得出是班次少，還是配對被排除掉了。

只記數字，不判斷要不要合併。

### 證據按路線日存檔，分析沒變就沿用

每個路線日的輸出放在 `<OUT>/evidence/<台北日>/<路線 Id>/`：`layovers.csv`、`ends.csv`，以及 `fingerprint`。

- **指紋**：`fingerprint` 是這次分析的 SQL 全文（`AnalysisRun.sql` 不帶變數時組出的文字）加上這次的路線 Id 清單，取 SHA-256。
- **原子寫入**：DuckDB 先寫到同一層的暫存目錄，整個路線日成功才換成正式的目錄名。
- **沿用與重跑**：再跑時，目錄在、而且指紋相同，就沿用；指紋不同（改了 SQL、`params.sql` 或成員路線），就重跑並換掉。
- **報告**：每次都從所有日子的證據重算。

理由：

- 全路網四天約 1.5 小時（估計），門檻與報告的格式之後可能會改，不該每次都重跑分析。
- 指紋讓「改了 SQL 卻沿用舊證據」不會悄悄發生。

### 找快照與檢查日子的程式抽出來共用

- **`NewestSnapshot`**：`RouteDayLoader` 找「檔名日期最新的外部快照」的私有方法抽成 `NewestSnapshot.find(data_root:, directory:, label:, task:)`，回傳 `NewestSnapshot::Snapshot`（`path`、`day`）。找不到時丟 `NewestSnapshot::Missing`，訊息照舊是「沒有…快照：先跑 …」。`RouteDayLoader` 改用它，接住後照舊丟自己的 `Error`。
- **`RawDayCheck`**：`DerivedLoadCommand` 檢查一天能不能算的私有方法（那一天有 `bus_event` 小時檔、隔天的 01 時檔已經在、那一天有 `bus_data` 小時檔、靜態快照三支檔都在）抽成 `RawDayCheck.check!(data_root:, day:)`，不符時丟 `RawDayCheck::Failure`，訊息與檢查順序不變。`DerivedLoadCommand` 改用它。

理由：調查要的就是 `derived:load` 這兩個規則，複製一份會讓兩邊各自漂移。訊息不變，`derived-tables` 的情境與 `spec/models/derived_load_command_spec.rb`、`spec/models/route_day_loader_spec.rb` 原樣通過，就證明行為沒變。

### AnalysisRun 多一個不跑編號階段的用法

`AnalysisRun.sql` 與 `AnalysisRun.run` 多一個關鍵字參數 `stages:`，預設 `true`，行為照舊；給 `false` 時只組 `params.sql` 加 `extra_files`。報告那一步用它跑 `end_nature_survey.sql`，那一步只讀證據檔，不需要也不能跑編號階段（沒有路線變數）。

### 報告與摘要的欄位與文字

`end_nature_survey.sql` 讀這次所有日子的 `layovers.csv` 與 `ends.csv`（檔案清單由指令給），以及 `<OUT>/configured.csv`（指令寫的，設定裡每條路線每個方向一列：`route_id`、`go_back`、`nature`），寫 `<OUT>/report-<FROM>_<TO>.csv`。欄位照規格 Survey report 的順序，欄名：`route_id`、`route_ids`、`route_name`、`go_back`、`end_stop_name`、`n_days`、`n_pairs`、`n_layovers`、`n_other_route`、`n_with_gps`、`n_stood_still`、`layover_p10`、`layover_p50`、`layover_p90`、`stop_gap_p50`、`still_p50`、`still_max`、`stood_still_share`、`farthest_p50`、`farthest_p90`、`farthest_max`、`nature`、`reason`、`configured_nature`、`agrees`。

指令印出的文字，數字與名稱照實際值：

- 每天一行：「2026-10-19：路線 2 條，跑完 2、沿用 0、失敗 0」。
- 有失敗時：「跑失敗的路線日：」，接著每個一行「  2026-10-19 路線 9999：<DuckDB 訊息的第一行>」。
- 摘要：「端點 4 個：停車 0、直接折返 0、待查證 4（樣本太少 4、介於兩個門檻之間 0）」。
- 「設定裡的端點：」，接著每端一行，例如「  9001 去程結束在戊站：設定 停車，判斷 待查證（樣本太少），停下來過 3／4 筆」。方向 0 寫去程、1 寫返程；性質寫停車、直接折返、待查證；理由寫樣本太少、介於兩個門檻之間。
- 最後一行：「報告：<路徑>」。
- 沒有任何路線日成功時，印「沒有任何路線日跑成功，沒有寫報告」，結束碼不是 0。

用法說明：

```
用法：bin/rails survey:end_natures FROM=<YYYY-MM-DD> TO=<YYYY-MM-DD> [ROUTES=<路線 Id,…>] [OUT=<目錄>]
原始檔的資料根目錄由環境變數 TURNAROUND_DATA 給；OUT 省略時是 tmp/end-natures。
```

### 用 2026-10-19 到 10-22 試跑，八個查證過的端點全對才算通過

真資料的調查用 `FROM=2026-10-19 TO=2026-10-22`，資料根目錄指向本機的備份（路徑不寫進 repo）。10-23 的資料量只有平日的四成左右，不用。

通過的條件是設定裡 8 個端點的 `agrees` 全是 `true`。任何一個不是，就先停下來，帶著那一端的證據回報使用者，用 `/spectra-ingest` 改規則或門檻，並寫明為什麼改；不改設定去遷就規則。通過之後，在這份 design 新增一節「調查結果」，寫下：

- 實際跑的時間。
- 三種判斷各幾端，待查證拆成兩種理由。
- 8 個端點的證據對照表（同上面那張表的欄位）。
- 停下來過的比例分佈：0%、0 到 5%、5 到 25%、25 到 50%、50 到 75%、75% 以上各幾端。
- `other_route` 配對比例最高的路線前 20 名。
- 跑失敗的路線日與原因。

要不要開下一個 change（把判斷放上頁面），由使用者看過這一節之後決定。

### 詞彙表補「最長靜止」、「最遠離站」與「待查證」

`docs/spectra/LANGUAGE.md` 的「指標」底下加兩條，「起站、末站、折返點、調度站」的邊界補一句：

- **最長靜止**：一筆折返停留裡，車連續回報速度 0、而且相鄰兩筆相距 50 公尺內的那一段，從第一筆到最後一筆經過的時間，取最長的一段。
  - 在資料或程式碼裡：`layover_evidence.longest_still_minutes`（`analysis/end_nature_evidence.sql`），距離門檻是 `standstill_radius_meters`。
  - 邊界：GPS 回報有間隔，一段從第一筆量到最後一筆，會比實際停的時間短，最多短一個回報間隔。沒有回報的折返停留沒有最長靜止；有回報但沒有一筆速度 0 是 0.0。超過 2 分鐘（`nature_still_minutes`）才算停下來過，剛好 2.0 不算。
  - 不要用：休息時間、停車時間、待命時間。
- **最遠離站**：一筆折返停留裡，每一筆 GPS 回報離「本趟末站、下一趟起站」兩站裡較近那一站的直線距離，取最大的那個。
  - 在資料或程式碼裡：`layover_evidence.farthest_meters`。
  - 邊界：回報有空檔時，車開過的地方可能沒有點，所以會比實際短（251區 公館端兩站相距 616 公尺，最遠離站只到 139 公尺，就是這個原因）。它不進判斷規則，只給人看。
  - 不要用：離站距離、偏離距離。
- 「起站、末站、折返點、調度站」的邊界補：全路網試跑（`bin/rails survey:end_natures`）用最長靜止判斷每一端，判斷不出來的叫待查證（`undetermined`），理由分樣本太少（`few_layovers`）與介於兩個門檻之間（`between`）；待查證只出現在試跑的報告裡，路線頁仍然只認設定裡人工查證的性質。

## Implementation Contract

**行為**：操作的人跑 `TURNAROUND_DATA=<資料根目錄> bin/rails survey:end_natures FROM=2026-10-19 TO=2026-10-22`。結束後：

- `tmp/end-natures/evidence/<台北日>/<路線 Id>/` 每個路線日一個目錄。
- `tmp/end-natures/report-2026-10-19_2026-10-22.csv` 一端一列。
- 終端機上有每天一行的進度、失敗清單與摘要。

資料庫、設定、路線頁都跟跑之前一樣。再跑一次同樣的指令，沒變的路線日都沿用，幾秒內重寫報告。

**介面與資料形狀**：

- rake task `survey:end_natures`，由 `EndNatureSurveyCommand.new(ENV.to_h).run` 實作（跟 `derived:load` 交給 `DerivedLoadCommand` 一樣），回傳結束碼。環境變數：`FROM`、`TO`、選用的 `ROUTES`、`OUT`，以及 `TURNAROUND_DATA`。
- 前置檢查依序是：參數格式、`TURNAROUND_DATA`、DuckDB、`ROUTES` 裡的成員路線、每一天的 `RawDayCheck.check!`、兩份外部快照的 `NewestSnapshot.find`。任何一項不過，就印原因、結束碼 1，不建立 `OUT` 底下的任何東西。
- 路線清單：每一天讀 `static/<台北日>/GetRoute.gz` 的 `BusInfo[].Id`，去掉重複，由小到大；有 `ROUTES` 就用它；再去掉 `RoutePage.member_of` 不是 `nil` 的 Id。
- 每個路線日的變數：
  - `data_root`、`route_id`、`member_route_ids`（`RoutePage.member_route_ids`）、`day`、`static_day`（等於 `day`）。
  - `inspect_dir` 與 `derived_dir` 都是暫存目錄，跑完丟掉。
  - `mrt_exits_path`、`mrt_exits_day`、`public_toilets_path`、`public_toilets_day`。
  - `end_nature_0` 與 `end_nature_1` 都是 `unknown`。
  - `survey_dir`：`end_nature_export.sql` 寫檔的暫存目錄。
- `layovers.csv` 的欄位依序：`route_id`、`day`、`go_back`、`bus_id`、`end_time`、`next_start_time`（台北時間，寫成 `YYYY-MM-DD HH:MM:SS`；`derived_export.sql` 的 `taipei_text` 在調查時不會跑，這裡直接用 `strftime`）、`minutes`、`next_route_id`、`next_go_back`、`stop_gap_meters`、`n_reports`、`longest_still_minutes`、`farthest_meters`。依 `go_back`、`end_time`、`bus_id` 排序。
- `ends.csv` 的欄位依序：`route_id`、`route_ids`（用「・」接）、`day`、`go_back`、`route_name`、`end_stop_name`、`n_pairs`、`n_layovers`、`n_no_last_stop`、`n_no_first_stop`、`n_other_route`、`n_negative`，頁面路線每個方向一列，依 `go_back` 排序。
- `fingerprint`：一行 64 個十六進位字元。
- 報告欄位見「報告與摘要的欄位與文字」。

**失敗模式**：

- 前置檢查不過：結束碼 1，不寫任何東西。
- 單一路線日的 DuckDB 錯誤：記下、繼續，不留下那個路線日的目錄與暫存目錄。
- 報告那一步的 DuckDB 錯誤：印出錯誤，結束碼 1，已經寫好的證據目錄留著，下次沿用。
- 沒有任何路線日成功：見上一節。

**驗收**：

- 新增的測試：`spec/analysis/end_nature_evidence_spec.rb`（規格 Layover evidence 的情境，用 fixture 與 `spec/analysis/turnaround_facilities_spec.rb` 那種換掉 `trips` 與 `gps_reports` 的寫法）、`spec/analysis/end_nature_export_spec.rb`、`spec/analysis/end_nature_survey_spec.rb`（規格 Inferred end nature 的範例表，用測試裡寫的證據 CSV）、`spec/models/end_nature_survey_command_spec.rb`（Survey task invocation、Routes surveyed、Survey report 的情境，資料根目錄用 `spec/fixtures/analysis`，`OUT` 用測試自己的暫存目錄）、`spec/models/newest_snapshot_spec.rb`、`spec/models/raw_day_check_spec.rb`。
- 既有的 `spec/models/derived_load_command_spec.rb`、`spec/models/route_day_loader_spec.rb`、`spec/analysis/analysis_run_spec.rb`、`spec/analysis/params_spec.rb` 全綠。
- `bin/rails parallel:spec` 全綠。
- 真資料的調查照「用 2026-10-19 到 10-22 試跑，八個查證過的端點全對才算通過」完成，結果寫進這份 design。

**範圍**：

- 在範圍內：三個新的 SQL 檔、`params.sql` 的四個常數、`AnalysisRun` 的 `stages:`、兩個抽出來的類別與兩個呼叫端、新的指令與 rake task、測試、詞彙表與 `analysis/README.md`。
- 不在範圍內：任何 `app/components/`、`app/views/`、`app/controllers/`、`RoutePage` 底下的查詢物件、`config/route_page.yml`、migration、`bin/health-card`、`bin/push-derived`，以及 `analysis/` 裡既有的 SQL 檔。

## Risks / Trade-offs

- [最長靜止會量少，判斷偏向直接折返] → 門檻用「超過 2 分鐘」與「不超過 5%」兩道保守的線；報告每一端都列最長靜止的中位數與最大值，判成直接折返的端點，人看得到它是不是常常停 1.9 分鐘。
- [門檻來自 8 個端點，正是 `zhongshan-turnaround-ends` 擔心的小樣本] → 規則在看到全路網之前寫死；8 個端點全對才通過；「調查結果」列出完整分佈，分佈在門檻附近擠成一團，就表示規則不能用，這也是一種答案。
- [設定裡的路線用 `unknown` 跑 `turnaround_facilities.sql`，跟 `derived:load` 不同] → 那個檔在 `unknown` 時只是不產生位置、公廁、靜止格，`gps_reports` 照樣建；證據只讀 `gps_reports` 與 `layovers`，跟性質無關。
- [全路網要跑約 1.5 小時（估計）] → 證據按路線日存檔、可以中斷後接著跑；實際時間記進「調查結果」，作為批次載入那個 change 的依據。
- [循環路線（站序只有一個方向）與預約公車的結果很怪] → 照樣進報告，`ends.csv` 只有一個方向的列，樣本太少的歸 `few_layovers`；不為它們另外寫規則。
- [`gps_reports` 只收當天有折返停留的車，讀整個讀檔視窗] → 跟 `derived:load` 一樣，不另外處理。
- [另一個 session 同時改 `analysis/README.md` 或詞彙表] → 動手前重讀；標任務完成時用 `spectra task done … --file` 列出這條任務改的檔。

## 調查結果

2026-10-24 照「用 2026-10-19 到 10-22 試跑，八個查證過的端點全對才算通過」跑了全路網：`TURNAROUND_DATA=<本機備份> bin/rails survey:end_natures FROM=2026-10-19 TO=2026-10-22`，結束碼 0。設定裡 8 個端點的判斷全部跟設定相同，規則通過，門檻不用改。

跑的時間與失敗的路線日取自指令的輸出。其餘都是實測值：大多從報告 `tmp/end-natures/report-2026-10-19_2026-10-22.csv` 算出來，算法是本節最後的查詢 Q1 到 Q7；251 那一段對照用的數字不是從報告算的，算法是 Q8 與查詢後面那段說明。在 repo 根目錄重跑，會得到同樣的數字。

**跑的時間與失敗的路線日**

- 22:14:38 開始，23:34:43 結束，共 80 分 4 秒。四天每天 415 條路線（19108 掛在 16111 底下一起跑，不另外算），跑了 1,644 個路線日，沿用 16 個（設定裡的 4 條路線，先前用 `ROUTES` 跑過同樣的四天），平均一個路線日約 2.9 秒。這段時間同一台筆電上還跑了驗證用的指令與測試，所以比單獨跑時略長。
- 跑失敗的路線日：0 個。

**三種判斷**

415 條路線裡有 11 條的站序只有一個方向，所以是 819 端（Q1）：

| 判斷 | 端點數 |
| --- | --- |
| 停車 | 211 |
| 直接折返 | 248 |
| 待查證，介於兩個門檻之間 | 82 |
| 待查證，樣本太少 | 278 |

樣本太少的 278 端分成三種（Q2；第二種的配對類別讀的是證據檔，Q3）：

- 65 端一組配對都沒有：四天裡，沒有一台車在這一端結束一趟之後又接下一趟。兩端都是這樣的路線有 27 條。
- 66 端有配對，但沒有一組算成折返停留：2,922 組配對裡，本趟沒有到末站 2,572 組，下一趟不是從起站出發 218 組，兩趟之間跑了別的路線 132 組。
- 147 端的折返停留只有 1 到 19 筆，四天合計 1,287 筆。

沒有一端是「折返停留至少 20 筆，有 GPS 回報的卻不到 20 筆」。

**設定裡的 8 個端點**

四天合計（Q4）。「停下來過」是最長靜止超過 2 分鐘的筆數，斜線後面是有 GPS 回報的筆數，括號裡是比例：

| 路線與那一端 | 設定 | 判斷 | 停下來過 | 折返停留中位數 | 最長靜止 p50、最大 | 最遠離站 p90、最大 |
| --- | --- | --- | --- | --- | --- | --- |
| 中山幹線 去程結束，青年公園(馬場町) | `pass_through` | `pass_through` | 6／282（0.021） | 1.9 分鐘 | 0.0、5.7 分鐘 | 94.6、99.9 公尺 |
| 中山幹線 返程結束，職能發展學院二 | `stop` | `stop` | 109／154（0.708） | 17.1 分鐘 | 5.0、94.0 分鐘 | 297.0、327.1 公尺 |
| 251 去程結束，臺北車站(開封) | `pass_through` | `pass_through` | 0／143（0.000） | 2.3 分鐘 | 0.0、1.7 分鐘 | 110.6、138.7 公尺 |
| 251 返程結束，福安居一 | `stop` | `stop` | 81／115（0.704） | 53.4 分鐘 | 14.3、331.1 分鐘 | 128.9、151.0 公尺 |
| 251區 去程結束，捷運公館站 | `pass_through` | `pass_through` | 0／212（0.000） | 2.5 分鐘 | 0.0、1.6 分鐘 | 123.2、206.4 公尺 |
| 251區 返程結束，福安居一 | `stop` | `stop` | 79／138（0.572） | 24.6 分鐘 | 2.7、287.3 分鐘 | 122.3、138.1 公尺 |
| 307 去程結束，莊敬里 | `stop` | `stop` | 641／857（0.748） | 13.0 分鐘 | 4.4、237.3 分鐘 | 414.5、788.9 公尺 |
| 307 返程結束，臺北客運板橋前站(藝文) | `stop` | `stop` | 741／879（0.843） | 14.6 分鐘 | 8.6、163.0 分鐘 | 253.9、552.7 公尺 |

跟 Context 那張表對照：

- 那張表多半是 10-22 一天的數字，這裡是四天合計，中位數不會完全一樣。
- 中山幹線兩端在那張表裡沒有最長靜止，這次有了。青年公園端四天 282 筆裡有 6 筆停超過 2 分鐘，比例 0.021，仍在直接折返的 5% 以內。
- 251 的最長靜止跟 `route-251-pages` 的數字不同，原因是量法。那次只看連續速度 0 的回報，這次照 307 的查證，多了「相鄰兩筆相距 50 公尺內」這個條件。用同一套 SQL 只算 10-22 的 251、把這個條件放寬到不限距離時，兩端是 0.0、2.0 與 14.4、266.7 分鐘，跟 `route-251-pages` 的表一樣；照這次的量法是 0.0、0.7 與 13.3、266.7 分鐘。臺北車站端那個 2.0 是 10-22 09:26:08 到站、09:28:44 發下一趟的那一筆：09:26:25 與 09:28:05 兩筆回報都是速度 0，但相距 74.4 公尺，車其實從臺北車站(開封)往重慶南路一段移動；照這次的量法，這一筆的最長靜止是 0.3 分鐘。
- 「判斷規則與門檻事先寫進 params.sql」的根據寫「三個直接折返的端點最長靜止都沒有超過 2.0 分鐘（251 臺北車站端剛好 2.0）」。那個 2.0 是舊量法的數字，中山幹線那一端當時也沒有算最長靜止。照這次採用的量法，三個直接折返端四天的最大值是 1.7（251）、1.6（251區）、5.7（中山幹線）分鐘；中山幹線超過 2 分鐘的 6 筆沒有讓判斷改變。

**停下來過的比例分佈**

比例是停下來過的筆數除以有 GPS 回報的筆數（Q5）。「0 到 5%」不含 0、含 5%（直接折返的門檻），「50 到 75%」含 50%（停車的門檻），其餘各格含下界、不含上界。有 GPS 回報的不到 20 筆時，一筆就超過 5%，所以「不到 20 筆」那一欄的「0 到 5%」是 0。

| 比例 | 有 GPS 的折返停留至少 20 筆 | 不到 20 筆 | 合計 |
| --- | --- | --- | --- |
| 0% | 150 | 50 | 200 |
| 0 到 5% | 98 | 0 | 98 |
| 5 到 25% | 39 | 8 | 47 |
| 25 到 50% | 43 | 14 | 57 |
| 50 到 75% | 95 | 26 | 121 |
| 75% 以上 | 116 | 48 | 164 |
| 合計 | 541 | 146 | 687 |

另外 132 端沒有任何一筆有 GPS 回報的折返停留，不在表裡（819 減 687）。

有 GPS 的折返停留至少 20 筆的 541 端裡（Q6）：

- 直接折返的 248 端，有 98 端不是 0%，靠 5% 的容許才判成直接折返。
- 落在門檻兩側 5 個百分點內的有 39 端：超過 5% 到 10% 有 18 端，45% 到不到 50% 有 10 端，50% 到不到 55% 有 11 端。

**兩趟之間跑了別的路線的配對**

比例最高的前 20 條路線（Q7）。比例是兩端合計的 `other_route` 配對除以配對數；配對不到 20 組的路線不排，免得一組裡有一組就排到第一。這裡只記數字，不判斷要不要合成一頁。307（16111 跟 19108 一起跑）四天 2,196 組配對，`other_route` 是 0。

| 路線 Id | 路線名稱 | 配對 | 跑了別的路線 | 比例 |
| --- | --- | --- | --- | --- |
| 15698 | 南軟通勤專車雙和線 | 25 | 16 | 0.640 |
| 18658 | 通勤21 | 20 | 8 | 0.400 |
| 16163 | 貓空左線(動物園) | 92 | 34 | 0.370 |
| 11055 | 小2 | 56 | 17 | 0.304 |
| 17952 | 617副 | 23 | 7 | 0.304 |
| 10744 | 棕15 | 133 | 38 | 0.286 |
| 10253 | 內科通勤專車22 | 34 | 9 | 0.265 |
| 11059 | 小5 | 48 | 12 | 0.250 |
| 17801 | 臺北觀光巴士藍線 | 30 | 6 | 0.200 |
| 15151 | 308 | 20 | 4 | 0.200 |
| 10823 | 260 | 80 | 15 | 0.188 |
| 11232 | 211 | 43 | 8 | 0.186 |
| 15522 | 227區 | 23 | 4 | 0.174 |
| 15686 | 內科通勤專車20 | 23 | 4 | 0.174 |
| 10752 | 278 | 170 | 29 | 0.171 |
| 16184 | 680 | 24 | 4 | 0.167 |
| 11061 | 小5區 | 68 | 11 | 0.162 |
| 10783 | 254 | 408 | 62 | 0.152 |
| 15702 | 內科快線1 | 128 | 18 | 0.141 |
| 15172 | 556 | 58 | 8 | 0.138 |

**查詢**

在 repo 根目錄用 `duckdb` 執行。Q3 讀的是證據檔，其餘讀報告。

```sql
-- Q1 三種判斷各幾端；路線數、端點數與只有一個方向的路線
SELECT nature, reason, count(*) AS n_ends
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
GROUP BY ALL ORDER BY nature, reason;

SELECT count(DISTINCT route_id) AS n_routes, count(*) AS n_ends,
       (SELECT count(*) FROM (SELECT route_id FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
                              GROUP BY route_id HAVING count(*) = 1)) AS one_direction_routes
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true);

-- Q2 樣本太少的端點，依原因；兩端都一組配對都沒有的路線
SELECT CASE WHEN n_pairs = 0 THEN '1 一組配對都沒有'
            WHEN n_layovers = 0 THEN '2 有配對，但沒有一組算成折返停留'
            WHEN n_layovers < 20 THEN '3 折返停留 1 到 19 筆'
            ELSE '4 折返停留至少 20 筆，有 GPS 回報的不到 20 筆' END AS cause,
       count(*) AS n_ends, sum(n_pairs) AS n_pairs, sum(n_layovers) AS n_layovers
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
WHERE reason = 'few_layovers'
GROUP BY cause ORDER BY cause;

SELECT count(*) AS routes_without_pairs
FROM (SELECT route_id FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
      GROUP BY route_id HAVING sum(n_pairs) = 0);

-- Q3 有配對、但沒有一組算成折返停留的端點，配對照類別合計（讀證據檔）
WITH ends AS (
    SELECT route_id, go_back, sum(n_pairs) AS n_pairs, sum(n_layovers) AS n_layovers, sum(n_no_last_stop) AS n_no_last_stop,
           sum(n_no_first_stop) AS n_no_first_stop, sum(n_other_route) AS n_other_route, sum(n_negative) AS n_negative
    FROM read_csv('tmp/end-natures/evidence/*/*/ends.csv', header = true, columns = {
        'route_id': 'INTEGER', 'route_ids': 'VARCHAR', 'day': 'DATE', 'go_back': 'INTEGER', 'route_name': 'VARCHAR',
        'end_stop_name': 'VARCHAR', 'n_pairs': 'INTEGER', 'n_layovers': 'INTEGER', 'n_no_last_stop': 'INTEGER',
        'n_no_first_stop': 'INTEGER', 'n_other_route': 'INTEGER', 'n_negative': 'INTEGER'})
    GROUP BY route_id, go_back
)
SELECT count(*) AS n_ends, sum(n_pairs) AS n_pairs, sum(n_no_last_stop) AS no_last_stop, sum(n_no_first_stop) AS no_first_stop,
       sum(n_other_route) AS other_route, sum(n_negative) AS negative
FROM ends
WHERE n_pairs > 0 AND n_layovers = 0;

-- Q4 設定裡的 8 個端點
SELECT route_id, go_back, end_stop_name, configured_nature, nature, n_stood_still, n_with_gps, stood_still_share,
       layover_p50, still_p50, still_max, farthest_p90, farthest_max, agrees
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true, types = {'stood_still_share': 'VARCHAR'})
WHERE configured_nature IS NOT NULL
ORDER BY route_id, go_back;

-- Q5 停下來過的比例分佈
SELECT CASE WHEN n_stood_still = 0 THEN '0%'
            WHEN n_stood_still <= n_with_gps * 0.05 THEN '0 到 5%'
            WHEN n_stood_still < n_with_gps * 0.25 THEN '5 到 25%'
            WHEN n_stood_still < n_with_gps * 0.5 THEN '25 到 50%'
            WHEN n_stood_still < n_with_gps * 0.75 THEN '50 到 75%'
            ELSE '75% 以上' END AS share_bin,
       count(*) FILTER (WHERE n_with_gps >= 20) AS ends_20_or_more,
       count(*) FILTER (WHERE n_with_gps < 20) AS ends_under_20,
       count(*) AS ends_with_gps
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
WHERE n_with_gps > 0
GROUP BY share_bin
ORDER BY min(n_stood_still / n_with_gps);

-- Q6 有 GPS 的折返停留至少 20 筆的端點：不是 0% 的直接折返端，與門檻兩側 5 個百分點內的端點
SELECT count(*) AS ends_20_or_more,
       count(*) FILTER (WHERE n_stood_still > 0 AND n_stood_still <= n_with_gps * 0.05) AS pass_through_not_zero,
       count(*) FILTER (WHERE n_stood_still > n_with_gps * 0.05 AND n_stood_still <= n_with_gps * 0.10) AS above_5_to_10,
       count(*) FILTER (WHERE n_stood_still >= n_with_gps * 0.45 AND n_stood_still < n_with_gps * 0.5) AS from_45_below_50,
       count(*) FILTER (WHERE n_stood_still >= n_with_gps * 0.5 AND n_stood_still < n_with_gps * 0.55) AS from_50_below_55
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
WHERE n_with_gps >= 20;

-- Q7 兩趟之間跑了別的路線的配對，比例最高的前 20 條路線（配對至少 20 組）；307 的配對
SELECT route_id, any_value(route_name) AS route_name, sum(n_pairs) AS n_pairs, sum(n_other_route) AS n_other_route,
       CAST(round(sum(n_other_route) / sum(n_pairs), 3) AS DECIMAL(4, 3)) AS other_share
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
GROUP BY route_id
HAVING sum(n_pairs) >= 20
ORDER BY other_share DESC, n_other_route DESC, route_id
LIMIT 20;

SELECT any_value(route_ids) AS route_ids, sum(n_pairs) AS n_pairs, sum(n_other_route) AS n_other_route
FROM read_csv('tmp/end-natures/report-2026-10-19_2026-10-22.csv', header = true)
WHERE route_id = 16111;

-- Q8 251 臺北車站端 10-22 09:26:08 到站那一筆的原始回報。車牌不寫進文件，從本機的證據檔取。
WITH layover AS (
    SELECT bus_id, end_time, next_start_time
    FROM read_csv('tmp/end-natures/evidence/2026-10-22/10712/layovers.csv', header = true, all_varchar = true)
    WHERE go_back = '0' AND end_time = '2026-10-22 09:26:08'
),
reports AS (
    SELECT DISTINCT r.DataTime, r.Speed, CAST(r.Latitude AS DOUBLE) AS lat, CAST(r.Longitude AS DOUBLE) AS lon
    FROM read_json(getenv('TURNAROUND_DATA') || '/bus_data/2026-10-22/09.jsonl*', format = 'newline_delimited',
                   columns = {BusID: 'VARCHAR', DataTime: 'VARCHAR', Speed: 'VARCHAR', Latitude: 'VARCHAR', Longitude: 'VARCHAR'}) r
    JOIN layover l ON r.BusID = l.bus_id AND r.DataTime BETWEEN l.end_time AND l.next_start_time
)
SELECT DataTime, Speed, lat, lon,
       round(2 * 6371000 * asin(sqrt(pow(sin(radians(lat - lag(lat) OVER w) / 2), 2)
             + cos(radians(lag(lat) OVER w)) * cos(radians(lat)) * pow(sin(radians(lon - lag(lon) OVER w) / 2), 2))), 1) AS meters_from_previous
FROM reports
WINDOW w AS (ORDER BY DataTime)
ORDER BY DataTime;
```

Q8 要先設好環境變數 `TURNAROUND_DATA`。251 在 10-22 不限距離的最長靜止（0.0、2.0 與 14.4、266.7 分鐘）不是從報告算的：照路線日的變數組出 10712 在 10-22 的分析（`params.sql`、編號階段 10 到 50、`mrt_overlap.sql`、`turnaround_facilities.sql`、`end_nature_evidence.sql`），最後加 `SET VARIABLE standstill_radius_meters = 1000000000;`，再對 `layover_evidence` 依方向取 `longest_still_minutes` 的中位數與最大值；不加那一行，得到的就是照這次量法的 0.0、0.7 與 13.3、266.7 分鐘。
