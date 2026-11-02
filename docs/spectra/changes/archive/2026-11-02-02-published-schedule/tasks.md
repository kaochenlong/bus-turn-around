<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
先決條件：01-rest-windows 歸檔並 commit 之後才開工（兩邊都改 RouteDayLoader 與 derived_export.sql）。
這個 change 不動任何頁面；第一個讀這些數字的是 03-monthly-card。
-->

## 1. 分析

- [x] 1.1 加 fixture：`spec/fixtures/analysis/static/2026-10-19/` 與 `2026-10-23/` 各放一份 `GetSemiTimeTable.gz`、`GetTimeTable.gz`，外層照真檔的 `EssentialInfo` 與 `BusInfo`，值都是字串。班距：附屬路線 9001 的 `DateValue` 2 到 6 各三列（0600–0800 `05`／`10`、0800–1700 `15`／`20`、1700–0000 `30`／`30`），`DateValue` 1 與 7 各一列（0600–2200 `20`／`30`）；附屬路線 9002 的 `DateValue` 2 一列（0600–0800 `05`／`10`，跟 9001 重複）；對照路線 9100 的 `DateValue` 2 一列；9001 一列 `DateType` 1、`DateValue` 20260101。定時班次：9001 的 `DateValue` 2 一列 `2230`；成員路線 9050 的 `DateValue` 2 與 6 各兩列（`0700`、`0830`）、`DateValue` 1 一列（`0900`）；9100 一列。`spec/fixtures/analysis/README.md` 寫明。驗證：內容檢查，fixture 既有的斷言照樣綠。
- [x] 1.2 [after: 1.1] 套用 design「兩支檔只由 published_schedule.sql 讀，快照沒有這兩支檔時不擋那一天」與「欄位怎麼讀：下界是 LongHeadway，到午夜算 24:00，指定日期的列不存，讀不懂就失敗」，實作 Requirement「Published schedule read from the static snapshot」。驗證：`spec/analysis/published_schedule_spec.rb` 涵蓋規格的四個情境（fixture 18 列、到午夜 1440、本路線讀不懂就失敗且訊息帶檔名與值、別條路線讀不懂不影響）。
- [x] 1.3 [after: 1.2] 套用 design「公告班距與定時班次存進衍生表，一份快照的每個 DateValue 都存」的匯出那一半：`analysis/derived_export.sql` 寫兩個 CSV，`RouteDayLoader` 的 `extra_files` 把 `published_schedule.sql` 排在 `derived_export.sql` 前面。驗證：`spec/analysis/derived_export_spec.rb` 加例子（欄位、排序、兩次匯出位元組相同），`bin/health-card` 的輸出與逐趟檔不變。

## 2. 衍生表

- [x] 2.1 建資料表：一個 migration 建 `route_day_published_headways`、`route_day_published_departures`（外鍵到 `route_days`，刪路線日時一起刪），`route_days` 加 `published_schedule_day`（date，可空）；新 model、factory 與 `RouteDay` 的關聯。驗證：跑 migration 後 annotate 更新註解，`bin/push-derived` 的衍生表清單測試列出兩張新表。
- [x] 2.2 [after: 1.3, 2.1] 實作 Requirement「Published schedule rows stored with the route day」：`RouteDayLoader` 在同一個交易裡寫入，快照缺檔時印一行並給空的 `BusInfo`。驗證：`spec/models/route_day_loader_spec.rb` 加例子（fixture 18 與 6 列、`published_schedule_day`、重載列數不變、兩支檔都缺時印兩行且當天照樣載入）。

## 3. 查詢物件

- [x] 3.1 [after: 2.1] 套用 design「每一天用哪一個 DateValue：平日用當天星期，假日的週一到週五用星期日」與「同一條路線的附屬路線合併去重」，實作 Requirement「Date value used for a route day」，以及 `RoutePage::ScheduleComparison` 的時段列。驗證：`spec/models/route_page/schedule_comparison_spec.rb` 涵蓋規格表格的六個日子與兩條附屬路線去重。
- [x] 3.2 [after: 3.1] 套用 design「量到的發車是起點落在時段裡的趟次，路上的車是每半小時有在跑的車數取平均」與「照公告要幾台是週期中位數除以公告班距」，實作 Requirement「Schedule comparison over route days」「Vehicles on the road in a period」「Vehicles needed by the published headway」。驗證：同一個 spec 涵蓋每小時發車的例子（一天與兩天）、兩格平均 2.5、到站剛好在格子開始不算下一格、週期 182.2 算出 30 到 46、沒有週期是 nil、`needs_reload?`；`cycles` 用測試替身。
- [x] 3.3 [after: 3.2] 套用 design「涵蓋日子裡公告改過就分開算」「其餘時段併成一列：定時班次與時段外的趟次」「頁面路線只比自己的趟次，成員路線另外一列」，實作 Requirement「Published schedule versions within the covered days」「Scheduled departures and trips outside the periods」「Member routes compared on their own」與 `hours`。驗證：同一個 spec 涵蓋規格的情境（中間改班距分兩版、週一週二同版、21:00 之後的定時班次、只有定時班次的路線、成員路線另外一列且不混進頁面路線）。
- [x] 3.4 [after: 2.1] 套用 design「靜態快照差異在讀取時比，不另外存」，實作 Requirement「Snapshot changes within the covered days」。驗證：`spec/models/route_page/snapshot_changes_spec.rb` 涵蓋規格的三個情境與第一天不算改動。

## 4. 顯名與文件

- [x] 4.1 套用 design「顯名聲明與資料來源文件多兩支 feed」，頁尾符合 Requirement「Attribution footer on every page」：`docs/data-sources.md`、`app/components/attribution_component.yml`、`bin/health-card` 的第一行加兩支 feed，查證表加兩列。驗證：`spec/analysis/attribution_spec.rb` 與 `spec/analysis/card_spec.rb` 綠；把第一行的 GetTimeTable 拿掉時 attribution 的例子會失敗。
- [x] 4.2 套用 design「詞彙表新增公告班距、路上的車、照公告要幾台」：`docs/spectra/LANGUAGE.md` 新增三條並改「日型別」的邊界，`analysis/README.md` 補新的 SQL、兩個檔與 `LongHeadway` 是下界這件事。驗證：內容檢查。

## 5. 驗收與收尾

- [x] 5.1 [after: 2.2, 3.3, 3.4] 套用 design「用真資料驗收：中山幹線七個平日的對照表跟 proposal 相同」：`TURNAROUND_DATA` 指向本機鏡射，把 15373 的 2026-10-19 到 22、27 到 29 與 10712 的 10-22 載入開發庫。驗證：`ScheduleComparison` 讀出 proposal 表上四個時段的班距、每小時發車（一位小數）、路上的車與照公告要幾台，週期 p50 是 182.2；10712 的 `others` 有 37 班、10-22 每個方向 36 到 38 趟；`SnapshotChanges` 沒有改動。數字記進 design。
- [x] 5.2 [after: 4.1, 4.2, 5.1] 全套檢查。驗證：`bin/rails parallel:spec` 全綠、對改到的檔案跑 `bin/rubocop` 沒有警告、`bin/brakeman` 沒有新告警，`git status` 只有這個 change 的檔案。
- [x] 5.3 [after: 5.2] 使用者 deploy 之後，在 mini 用 `!` 跑 `bin/nightly-load --recompute --load`（可以跟 `01-rest-windows` 併成一次）。驗證：log 裡沒有失敗的路線日，正式站每個路線日的 `published_schedule_day` 都有值。
