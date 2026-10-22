<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
-->

## 1. 新的成立條件

- [x] 1.1 實作 Layover definition 的修改，套用 design「折返停留只要本趟觀測到末站、下一趟觀測到起站」與「班次串不跟著放寬」：`analysis/30_layovers.sql` 的 `layover_pairs` 依序分類 `no_last_stop`、`no_first_stop`、`other_route`、`negative`、`layover`，`layover_exclusions` 改成這四類的欄位，`rest_runs` 不動；`spec/fixtures/analysis/README.md` 的「折返停留與班次串」改成 design「fixture 2026-10-19 的手算值」的 19 筆與四類計數。驗證：`spec/analysis/layovers_spec.rb` 斷言 Example「Fixture day 2026-10-19」（19 筆依車牌與順序照 design、去程結束 10 筆與返程結束 9 筆、四類計數 3、1、0、0），以灌入的趟次斷言 Scenario「Endpoints observed on incomplete trips」（`missing_start` 08:16 結束接 `missing_end` 08:30 出發得 14.0）、「Current trip without its last stop」、「Next trip without its first stop」、「Both endpoints missing」（只算 `no_last_stop`）、「Negative difference」；`spec/analysis/chains_spec.rb` 不改斷言仍全綠。
- [x] 1.2 實作卡的排除計數與說明，套用 design「量不到的配對只計數，不當證據」：`analysis/60_export.sql` 的 `layovers.exclusions` 改成 `{no_last_stop, no_first_stop, other_route, negative}`，`bin/health-card` 折返停留一節的說明改成新的成立條件，排除一行印成「本趟沒有到末站 N 組、下一趟不是從起站出發 N 組、下一趟是別的路線 N 組、差值為負 N 組」，不印量不到的配對的分鐘數。驗證：`spec/analysis/card_spec.rb` 的折返停留一節改成從 design 的 19 筆手算的筆數、p10、p50、p90、不到 15 分鐘的比例與分箱（整體、去程結束、返程結束），排除一行是「本趟沒有到末站 3 組、下一趟不是從起站出發 1 組、下一趟是別的路線 0 組、差值為負 0 組」，班次串仍是「1 串，涉及 1 台車」與同一列串表；`spec/analysis/cli_spec.rb` 的 `layovers.csv` 斷言改成 19 筆。說明文字是固定文案，做內容審查對照 design。 [after: 1.1]
- [x] 1.3 讓衍生表與路線頁用新定義：`spec/analysis/derived_export_spec.rb`、`spec/models/route_day_loader_spec.rb`、`spec/models/derived_load_command_spec.rb` 的折返停留筆數改成 19（`derived_export.sql` 與載入器的程式不用改，它們讀 `layovers` view）；`app/components/layover_table_component.yml` 的 tw 與 en 說明改成新的成立條件。驗證：上述三個 spec 全綠；`spec/models/route_page/card_consistency_spec.rb` 不改斷言仍綠（卡與頁面讀同一份結果）；說明文字做內容審查。 [after: 1.1]

## 2. 文件與真資料

- [x] 2.1 文件：`docs/spectra/LANGUAGE.md` 的「折返停留」一條補上成立條件（本趟有末站、下一趟有起站），以及「量不到的配對只計數，表面間隔不代表停留」；`analysis/README.md` 的 `layover_exclusions` 說明改成四類。驗證：內容審查對照 `layover-metrics` 的 delta spec 與 design。 [after: 1.2, 1.3]
- [x] 2.2 以真資料驗收：`TURNAROUND_DATA` 指到資料根目錄（不寫進任何檔案），執行 `bin/rails derived:load ROUTE=15373 FROM=2026-10-19 TO=2026-10-21`；三天合計的折返停留是 333 筆，與 proposal 的試算相同（不同時記下新數字與原因）；`/routes/15373?day=2026-10-21&range=7d` 的折返停留與換休息試算的涵蓋率跟著變。驗證：`bin/rails runner` 印出的筆數與分佈對照 proposal；`make test`、`bin/rubocop`（改到的 Ruby 檔）、`bin/brakeman` 全綠。 [after: 2.1]
