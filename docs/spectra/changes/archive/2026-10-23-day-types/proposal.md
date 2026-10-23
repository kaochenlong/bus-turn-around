## Why

這個 change 服務三樣交付物的第一樣「路線健檢卡」：詞彙表「健檢卡」規定月卡要收滿一個月的平日，「日型別」規定所有指標平日與假日分開算，路線頁上的數字也一樣。建在折返停留上的第二樣「換休息」試算，每天平均也跟著分開算。需要的新資料只有一份：行政院人事行政總處的「中華民國政府行政機關辦公日曆表」（data.gov.tw/dataset/14718，政府資料開放授權條款第 1 版，一年一個 CSV）。其餘資料全部已經在衍生表裡。

為什麼現在做：衍生表到目前只有平日，15373 的 2026-10-19 到 10-21（2026-10-23 查詢；10-18 只收了半天，沒有回補）。2026-10-24（六）到 10-26（一）是光復節連假，115 年辦公日曆在 10-26 寫的是「2，補假」（2026-10-23 下載的原檔，量到的）。這三天載入之後：

- 路線頁沒帶日期時顯示最新一天，日期寫成「2026-10-26（一）」。「沒有分平日與假日」那句只在最近 7 天才出現，當天模式看不出那天是假日。
- 最近 7 天會把三個假日跟平日混在一起，算出 p85 與折返停留。
- 公運處的資料分不出國定假日。2026-10-22 的快照裡（量到的），中山幹線在 `GetSemiTimeTable.gz` 的 `DateValue` 1 與 7 只有一段 05:30 到 21:00、班距 15 到 20 分鐘；2 到 6 在 06:30 到 08:00 與 16:00 到 17:30 是 4 到 6 分鐘。`DateValue` 看起來就是星期幾，照它算，10-26 就是一般的週一。`GetTimeTable.gz` 的 `DateType` 全是 0。

七個 change 的非目標都延後了「平日與假日分開」，`zhongshan-route-page` 寫的理由是「辦公日曆還沒抓，`DateType` 怎麼對到平假日待確認」。這個 change 就是把日曆抓進來。

## What Changes

- 新增 rake task `external:office_calendar`：依 `YEAR`（預設今年）下載那一年的辦公日曆 CSV，存成資料根目錄下的 `external/office-calendar/<年>/<台北日>.csv`（UTF-8、不帶 BOM、LF 換行）。寫檔前要通過以下檢查：
  - 表頭正確。
  - 天數等於那一年的天數。
  - 日期從 1 月 1 日一天接一天排到 12 月 31 日。
  - 星期欄跟日期對得上。
  - 「是否放假」只出現 0 與 2。

  每一年的下載網址寫成程式裡的常數，目前有 2026 與 2027。
- 「日型別」落地：「是否放假」是 0 就算平日，是 2 就算假日；`備註` 有字時一起帶著（例如「補假」）。補班日算平日，補假算假日；颱風停班不在日曆裡，照日曆算。
- `derived:load` 每算一天，就用那一年檔名日期最新的日曆快照，把那一天的日型別、備註和用到的快照日寫進 `route_days`。沒有那一年的快照時，那一天失敗，訊息提示先跑 `bin/rails external:office_calendar YEAR=<年>`。已經載入的日子要重跑一次 `derived:load`。
- **BREAKING**（路線頁的範圍定義）：
  - 「最近 7 天」原本是「選的那一天加上前 6 個台北日裡有資料的日子」，改成「其中跟選的那一天同類型的日子」。
  - 「涵蓋的日子」標出平日或假日，每一天帶著備註。
  - 另外放一個連結，跳到選的那一天以前（含）最近一個另一類、有資料的日子，範圍不變；找不到就不放。
  - 拿掉「沒有分平日與假日」的文案。
- 路線頁資料限制改寫那一條：平日與假日照人事行政總處的辦公日曆分，颱風停班不在日曆裡。
- 首頁路線清單在「最新資料」的日期旁標出平日或假日。
- 顯名聲明加一行辦公日曆的出處，同一份授權條款。
- 測試裡有 20 個檔各自用 `RouteDay.create!` 建路線日，加上 `spec/models/route_day_spec.rb`，全部改用一個 `route_day` factory。FactoryBot 已經設定好，只是還沒有任何 factory。日型別改成必填之後，以後 `route_days` 再加欄位只要改一處。
- 「補假日公車跑的是假日班距」這個假設，交件前沒辦法用真資料驗證：活動 2026-10-24 交件，10-26 的資料要到 2026-10-27 02:00 才有。改成在詞彙表「日型別」的邊界記一條待確認，附上驗證方法：比對一整天每個方向的趟數（原本想比 06:30 到 08:00 的發車數，但實測平日返程只有 3 到 5 趟，分不出平假日）。交件後照著補驗；對不上就另開 change 修正分法。

## Non-Goals

- 颱風等天然災害停班日：辦公日曆是前一年就公布的年曆，不含當天由縣市政府宣布的停班。這次照日曆算，寫進資料限制；第一次碰到時再加人工維護的例外清單。
- 把補班日、連假、春節另外分類：2026 與 2027 的日曆都沒有補班日（量到的），分成兩類就夠回答現在的問題。
- 班表對照（脫班、班距達成），包括 `GetSemiTimeTable.gz` 的 `DateValue` 與 `GetSpecTimeTable.gz`（業者機動預排班表）：這次只在詞彙表記下 `DateValue` 的觀察。
- 最近一個月與月卡：天數是參數，之後改成 30 天時沿用同一套「選的那一天決定類型」。
- Markdown 健檢卡（`bin/health-card`）：一天版只有一天，不需要分類。
- 首頁放任何指標；首頁資料來源那一塊的三個連結也不變，因為辦公日曆不是公車的 feed。
- 修改趟次、折返停留、行駛時間、載客剖面、捷運重疊、換休息試算的定義；其他路線；排程與部署。
- 交件前用真資料驗證「補假日跑假日班距」：資料要到 2026-10-27 02:00 才有，晚於交件期限。這個 change 只記下待確認與驗證方法。

## Capabilities

### New Capabilities

- `day-types`: 辦公日曆快照的下載、檢查與存放；怎麼從快照讀出一個台北日的日型別與備註；邊界案例（補假、補班、颱風停班、跨午夜的趟次）。

### Modified Capabilities

- `derived-tables`: 可算條件多一項「那一年至少有一份辦公日曆快照」；路線日帶著日型別、備註與用到的快照日。
- `route-page`: 最近 7 天只涵蓋跟選的那一天同類型的日子；涵蓋的日子標出類型與備註；跳到另一類的連結；資料限制那一條改寫。
- `home-page`: 路線清單的最新資料日帶著日型別。
- `site-layout`: 顯名聲明多一行辦公日曆。

## Impact

- 新增：app/models/office_calendar_snapshot.rb（下載、檢查、寫檔、查一天）、app/models/http_fetcher.rb（從 app/models/mrt_exits_snapshot.rb 抽出來共用的下載器）、兩個 migration（先加可以為空的欄位，重載之後再改成必填）、spec/factories/route_days.rb、spec/models/office_calendar_snapshot_spec.rb、spec/models/http_fetcher_spec.rb、spec/models/route_page/coverage_spec.rb、spec/components/application_component_spec.rb、spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv（真的 2026 年日曆轉成快照格式）。
- 修改：
  - 下載與載入：app/models/mrt_exits_snapshot.rb（改用共用下載器，行為不變）、lib/tasks/external.rake（加 `external:office_calendar`）、app/models/route_day_loader.rb、app/models/route_day.rb（schema 註解）、db/schema.rb。
  - 頁面：app/models/route_page/coverage.rb、app/components/route_coverage_component.rb、app/components/route_coverage_component.html.erb、app/components/route_coverage_component.yml、app/components/application_component.rb（日型別的顯示名稱）、config/locales/tw.yml、config/locales/en.yml、app/components/route_list_component.html.erb、app/components/route_list_component.yml、app/components/data_limitations_component.yml（`items` 那一條）、app/components/attribution_component.html.erb、app/components/attribution_component.yml。
  - 測試：20 個用 `RouteDay.create!` 的 spec 與 spec/models/route_day_spec.rb 改用 factory；另外修改 spec/models/route_day_loader_spec.rb、spec/models/derived_load_command_spec.rb、spec/components/route_coverage_component_spec.rb、spec/requests/routes_spec.rb、spec/components/route_list_component_spec.rb、spec/analysis/fixtures_spec.rb、spec/fixtures/analysis/README.md。footer 新加的那一行與拿掉的「沒有分平日與假日」都是固定文案，照測試範圍規則用內容審查確認，所以 spec/requests/site_layout_spec.rb 不改。
- 文件：docs/spectra/LANGUAGE.md 的「日型別」一條；docs/data-sources.md 辦公日曆那一列改成已抓。
- 不改 `analysis/` 的 SQL、`bin/health-card`、Gemfile，不加前端套件。
- 資料限制與假設：
  - 這個 change 不改任何指標的定義，只改哪些日子放在一起算。車不等於人、車上人數看刷卡率、10 秒輪詢會漏站、跨小時檔有重複，這四條照舊。
  - 日型別照的是人事行政總處的辦公日曆，那是機關上班的日曆，不是公車的營運日曆。「補假日跑假日班距」要用 10-26 的資料驗證；交件前做不到，記在詞彙表的待確認，交件後補驗。在那之前，10-26 照日曆標成假日。
  - 颱風停班照日曆算。
  - 7 天裡的假日通常只有 2 到 3 天（照日曆推算，不是量到的：一週固定有 2 天週末，遇到國定假日或補假才多），樣本少，照用現有「趟數少於 5 標成樣本少」的標示。
  - 跨午夜的趟次歸發車那一天，所以帶的是發車那一天的日型別。
