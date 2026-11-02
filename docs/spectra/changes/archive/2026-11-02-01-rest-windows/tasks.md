<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
這個 change 不動任何頁面；第一個讀這些數字的是 03-monthly-card。
-->

## 1. 分析

- [x] 1.1 套用 design「連續 6 小時視窗：一次停滿 45 分鐘才算數，常數放 params.sql」與「當天行駛超過 10 小時只存成一個標記，門檻只放 params.sql」的常數與 view，實作 Requirement「Six-hour rest windows」：`analysis/params.sql` 加三個常數，`analysis/30_layovers.sql` 的 `rest_windows` 多 `longest_layover_minutes`、新增 `long_rest_windows`。驗證：`spec/analysis/chains_spec.rb` 加例子（沒有一次達 45 分鐘、剛好 45 分鐘、序列不滿 6 小時、fixture 7 個視窗 0 個標出且第一個是 06:00 到 13:14），既有的班次串例子與 `spec/analysis/card_spec.rb` 不改照樣綠。
- [x] 1.2 [after: 1.1] 套用 design「連續行駛段：中間沒有 15 分鐘以上停留的完整趟次接成一段」，實作 Requirement「Continuous driving stretches」：`analysis/30_layovers.sql` 新增 `driving_stretches`。驗證：`spec/analysis/chains_spec.rb` 加例子（10 分鐘接成一段、剛好 15 分鐘切開、跑別的路線切開、fixture 15 段且最長是 06:00 到 11:30、5 趟）。
- [x] 1.3 [after: 1.2] 套用 design「視窗與連續行駛段照舊在 DuckDB 算，匯出進衍生表，Rails 不再算一次」的匯出那一半：`analysis/derived_export.sql` 寫 `rest_windows.csv`、`driving_stretches.csv`，欄位與排序照 Requirement「Rest window rows stored with the route day」，`over_daily_driving` 超過 600 分鐘才是 true。驗證：`spec/analysis/derived_export_spec.rb` 加例子（欄位順序、兩次匯出位元組相同、fixture 列數、601 與 600 分鐘的邊界），`bin/health-card` 的逐趟檔不變。

## 2. 衍生表

- [x] 2.1 套用 design「兩條規則存同一張表 route_day_rest_windows，一個視窗一列」與「route_days.rest_windows_loaded 分得出沒重算的日子」的資料表那一半：一個 migration 建 `route_day_rest_windows`、`route_day_driving_stretches`（外鍵到 `route_days`，刪路線日時一起刪，唯一鍵照 design），`route_days` 加 `rest_windows_loaded`（boolean，預設 false，不可空）；新 model 與 factory。驗證：`bin/rails db:migrate` 後 annotate 更新 schema 註解，`spec/models/` 的新例子確認唯一鍵與 `RouteDay` 的關聯，`bin/push-derived` 的衍生表清單測試列出兩張新表。
- [x] 2.2 [after: 1.3, 2.1] 實作 Requirement「Rest window rows stored with the route day」的載入：`RouteDayLoader` 的 `STAGING`、`STAGING_TABLES` 加兩個檔，同一個交易裡寫入，路線日設 `rest_windows_loaded` true，`summary` 那一行不變。驗證：`spec/models/route_day_loader_spec.rb` 加例子（fixture 2026-10-19 的 9 加 7 列與 15 列、重載列數不變、寫入失敗時舊資料不變），`spec/models/derived_load_command_spec.rb` 不改照樣綠。

## 3. 查詢物件

- [x] 3.1 [after: 2.1] 套用 design「RoutePage::RestWindows 只給數字，比例的分母是能判斷的視窗」，實作 Requirement「Rest window figures over route days」。驗證：`spec/models/route_page/rest_windows_spec.rb` 涵蓋規格的每個情境（兩天的比例與逐日範圍、沒有視窗的日子、完全沒有視窗、連續行駛段的百分位數、`needs_reload?`、回傳值沒有車牌），傳排序過與沒排序的 relation 結果相同。
- [x] 3.2 [after: 2.2, 3.1] 確認衍生表跟健檢卡是同一套定義：fixture 2026-10-19 載入後，`RoutePage::RestWindows` 的 `four_hours` 標出的視窗，時間範圍等於健檢卡 JSON 那條班次串的起訖。驗證：`spec/models/route_page/card_consistency_spec.rb` 加一個例子。
- [x] 3.3 套用 design「取「最新一天」一律用 reorder，測試傳排序過的 relation」：`LayoverStats`、`LayoverDistribution`、`LoadProfile`、`MrtOverlap` 接在 `RouteDay.order(:day)` 後面也取到最新一天。驗證：四個物件的 spec 各加一個傳排序過 relation 的例子，把 `reorder` 換回 `order` 時那個例子會失敗。

## 4. 文字與文件

- [x] 4.1 套用 design「班次串的文字拿掉「不合規」」與「詞彙表新增連續 4／6 小時視窗與連續行駛段，班次串不改名」：`bin/health-card` 的說明、`docs/spectra/LANGUAGE.md` 改寫與新增，`analysis/README.md` 補新的 view、常數與兩個檔。驗證：內容檢查，`rg "不合規" bin analysis docs/spectra/LANGUAGE.md` 沒有結果，`spec/analysis/card_spec.rb` 照樣綠。

## 5. 驗收與收尾

- [x] 5.1 [after: 2.2, 3.1] 套用 design「用真資料驗收：中山幹線 2026-10-22 的視窗數與試算相同」：`TURNAROUND_DATA` 指向本機鏡射，`bin/rails derived:load ROUTE=15373 DAY=2026-10-22` 寫進開發庫。驗證：`RoutePage::RestWindows` 讀到 4 小時 32 個視窗、19 個標出；6 小時 15 個視窗、5 個標出；連續行駛段 66 段；數字記進 design。
- [x] 5.2 [after: 3.2, 3.3, 4.1, 5.1] 全套檢查。驗證：`bin/rails parallel:spec` 全綠、對改到的檔案跑 `bin/rubocop` 沒有警告、`bin/brakeman` 沒有新告警，`git status` 只有這個 change 的檔案。
- [x] 5.3 [after: 5.2] 使用者 deploy 之後，在 mini 用 `!` 跑 `bin/nightly-load --recompute --load`。驗證：log 裡沒有失敗的路線日，記下每個路線日的秒數取代 proposal 的估計；正式站每個路線日的 `rest_windows_loaded` 都是 true。
