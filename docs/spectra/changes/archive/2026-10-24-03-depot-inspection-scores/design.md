## Context

路線頁的「折返點設施」卡（`TurnaroundFacilitiesComponent`，資料來自 `RoutePage::Facilities` 讀 `route_day_ends` 與 `route_day_end_toilets`）現在只報每一端 500 公尺內的公廁。詞彙表「折返點設施」寫「目前只有公廁」，「起站、末站、折返點、調度站」寫調度站是業者的營業站、`GetProvider.gz` 每列一個業者的一個營業站、事件的 `StationID` 是車輛所屬的營業站，但「折返點是不是調度站」還沒區分，`GetProvider.gz` 也沒有座標。

`analysis/10_load.sql` 讀 `bus_event` 時只取 `BusID`、`RouteID`、`GoBack`、`StopID`、`CarOnStop`、`DutyStatus`、`BusStatus`、`DataTime` 等欄位，`StationID` 與 `ProviderID` 在原始檔裡但沒讀。`DerivedLoadCommand::STATIC_FILES` 要求 `GetRoute.gz`、`GetStop.gz`、`GetPathDetail.gz`；`03-route-shape-map` 把 `GetBusShape.gz` 做成可缺的檔（缺了印一行、那一天沒有路線軌跡）。

公運處「115年第1期臺北市市區公車營運服務指標評鑑總體報告書」（2026-07-21 公告，PDF 607 頁，sha256 `5eee1a7f2022e286018fc472db3164b1930f24548c42410b56d0f41920ecb5ec`）附錄一是「臺北市公共運輸處市區公車場站檢查評分表(115 年第 1 期)」：A-1 是空白表，A-3 到 A-17 是 15 家業者 59 個營業站的分數，每站兩欄（同一個檢查日期）、23 項檢查各有比重、最後一列總分。業者印簡稱（臺北、首都、欣欣），營業站有的省略「站」字（板橋前、新店）。2026-10-24 讀到的、跟已有或將有路線頁的路線相關的：臺北客運板橋前（A-8，12月12日，兩欄：調度室環境 8、8；休憩室空間及環境 8、8；休憩室設施 6、6；盥洗室環境 5、5；禁菸環境 5、5；停車場使用情形 5、5；男女專用廁所或性別友善廁所 2、2；男女性專用休息室 2、2；總分 100、100）、臺北客運民生站（A-8，1月9日：10、10；10、10；6、6；5、5；5、5；5、5；2、2；2、2；總分 100、100）、光華巴士天東站（A-7，印作「光華 天東站」，1月2日：9、10；9、10；6、6；6、6；5、5；5、5；2、2；2、2；總分 100、100）；欣欣客運深坑站、首都客運民生站、首都客運板橋前站、光華巴士天西站、光華巴士中和站、三重客運土城站、大南汽車土城站都不在附錄裡（A-7 的光華只有天東站、北士科、洲美站；A-10 的首都只有新莊一站、三重二站、內湖站、經貿站、東園、汐止二站、士林站、社子站）。臺北客運兩站的數字是 design 寫作時讀 PDF 抄的，apply 開工前對過 PDF 第 318 頁原頁一致；天東站是 apply 開工前讀 PDF 第 317 頁原頁抄的。三站都還要照任務再對一次。

這份名單是 apply 時照 `route_day_depots` 的算法重算的：2026-10-19 到 10-23，每個路線頁每趟取事件裡最多的 `StationID`，對當天 `GetProvider.gz` 的名稱（實測，每天的車數；10-23 那天的原始檔只有平日的四成左右，數字偏低）。中山幹線（15373）：光華巴士天東站 11 到 26 台、天西站 2 到 7 台、中和站 1 到 4 台，propose 時漏看了整條；251（10712）與 251區（11764）：只有欣欣客運深坑站；307（16111＋19108）：臺北客運板橋前站 38 到 54 台、首都客運民生站 16 到 29 台、首都客運板橋前站與臺北客運民生站每天各 1 台。apply 開工前第一次是用事件層級查的，多列了首都客運東園站：2026-10-19 有一台東園站的車只有一筆事件落在 307 上，湊不成趟次，按趟算不是 307 的調度站，已經從名單與設定拿掉。名單要用按趟的結果查，不用事件層級。265區（10482）還沒有路線頁，2026-10-22 另有大南汽車北投站 3 台與三重客運蘆二站 1 台，兩站都不在附錄（A-6 的大南是內湖、北捷、關渡，A-9 的三重是迴龍、蘆洲一站、新莊、南港），留給 265區 的 change 決定要不要列。

公運處網站的「政府網站資料開放宣告」：採政府資料開放授權條款第 1 版，以無償、非專屬、得再授權的方式提供公眾使用，使用時應註明出處，不代表機關推薦或贊同。

## Goals / Non-Goals

**Goals:**

- 每個路線日存下車輛所屬的調度站與車數，頁面列出來。
- 評鑑附錄裡跟駕駛休息有關的分數，照原值、附頁碼與日期，掛在對應的調度站旁。
- 不在名單的調度站也講清楚，不留空白讓讀者猜。
- 顯名補齊：GetProvider 與報告書。

**Non-Goals:**

- 判斷折返點是不是調度站、車在折返停留期間有沒有回站：`zhongshan-turnaround-ends` 與 `turnaround-facilities` 的非目標照舊，`GetProvider.gz` 沒有座標。
- 用程式解析 PDF 的表格：有路線頁的四頁只需要十列，人工抄、附頁碼、兩個人核對比解析器可靠；全市要做時再換。
- 抄全部 23 項、或把分數平均、換算、評等。
- 歷期評鑑（114 年以前）、下一期自動更新：下一期公告時人工加一個 term。
- 業者層級的評鑑總分、其他指標（準點率、肇事率）。
- 調度站的座標與地圖。
- 健檢卡（`bin/health-card`）印調度站與分數：卡只跟著顯名第一行改字。

## Decisions

### 調度站從每趟事件的 StationID 取，名稱對 GetProvider.gz，存成 route_day_depots

`analysis/10_load.sql` 的 `bus_events` 多讀 `StationID`（VARCHAR 再 TRY_CAST 成整數），每趟的調度站是這趟事件裡出現最多的 `StationID`（同票取較小的）；每個路線日按調度站算 `n_buses`（不同車牌數）與 `n_trips`。名稱對當天靜態快照的 `GetProvider.gz`：`stationId` 對 `nameZn`（業者）與 `stationNameZn`（營業站）；這支檔跟 `GetBusShape.gz` 一樣可缺，缺了印一行「靜態快照沒有 GetProvider.gz，路線 X 這一天的調度站沒有名稱」，列照存、兩個名稱空白。匯出 `depots.csv`（`station_id, provider_name, station_name, n_buses, n_trips`），`RouteDayLoader` 寫進新表 `route_day_depots`（`route_day_id` 隨路線日刪除，唯一 `(route_day_id, station_id)`）。

理由：`StationID` 每筆事件都有，不用再對 `GetCarInfo.gz`；按趟取多數票是因為同一台車一天內 `StationID` 不會變、但偶爾有錯值。`GetProvider.gz` 可缺是因為它只給名稱，缺了頁面寫「營業站 Id 16280」還能用。替代方案：在頁面讀取時對名稱（否決：Rails 不碰原始檔，決定 2）；只存車牌對調度站（否決：衍生表不存車牌層級的新東西，頁面也不顯示車牌）。

### 查核分數人工對著附錄抄進 config/depot_inspections.yml，附頁碼與兩欄原值，只抄有路線頁的路線的調度站

`config/depot_inspections.yml` 用 `Rails.application.config_for`，`shared` 放真資料、`test` 放 fixture 的。結構：`terms` 底下一個 `115-1`：`title`、`announced_on`（2026-07-21）、`page_url`（公車評鑑專區的公告頁）、`download_url`、`sha256`、`appendix_pages`（A-3 到 A-17）、`items`（九個項目，每項 `name` 與 `weight`）、`depots`（清單，每個 `provider`（`GetProvider.gz` 的 `nameZn` 全名，例如 臺北客運）、`station`（`stationNameZn` 全名，例如 板橋前站）、`printed_as`（附錄印的字，例如 臺北 板橋前）、`inspected_on`（照印的「12月12日」，不補年份）、`printed_page`（A-8）、`scores`（每個項目兩欄原值的陣列））、`not_in_appendix`（清單，`provider` 與 `station`，是翻過整份附錄確認不在的）。對照規則：`provider` 與 `station` 跟 `route_day_depots` 的名稱完全相等才算同一站，不做模糊比對。

理由：有路線頁的四頁只需要十列（三站有分數、七站不在名單），人工抄附頁碼可以逐筆回查；兩欄照抄不平均，是因為報告書沒有說兩欄是什麼關係（兩位委員或兩次），我們不替它解讀。`not_in_appendix` 要明寫，是因為「設定裡沒有」有兩種意思，不在名單跟還沒對過要分開講。替代方案：解析 PDF（非目標）；抄全部 59 站（否決：九項乘兩欄乘 59 站上千個數字，錯一個就是對某家業者的錯話）。

### 挑跟休息有關的八項與總分，不抄全部 23 項

九個項目：調度室環境（10%）、休憩室空間及環境（10%）、休憩室設施（6%）、盥洗室環境（6%）、禁菸環境（5%）、停車場使用情形（5%）、男女專用廁所或性別友善廁所（2%）、男女性專用休息室（2%）、總分（100%）。名稱照附錄一的表頭原字。

理由：前五項是駕駛在調度站休息會碰到的環境；停車場使用情形對應處理原則五(六)的「起迄點應設停車場」，看得出車是停場內還是路邊；性別友善那兩項是女性駕駛的休息條件；總分讓讀者知道這一站整體在哪。酒測器、鑰匙管制、綠美化、洗車、資源回收、ADAS 跟休息無關，不抄。

### 報告書 PDF 當外部快照存進資料根目錄，sha256 記在設定裡

新 `bin/rails external:pto_assessment TERM=115-1`（`PtoAssessmentSnapshot`，照 `PublicToiletsSnapshot` 的樣子，用 `HttpFetcher`，測試注入假的 fetcher）：讀 `config/depot_inspections.yml` 該 term 的 `download_url`，存到 `TURNAROUND_DATA/external/pto-assessment/<term>/report.pdf`，印 sha256；下載到的 sha256 跟設定不同時仍存檔但印警告，因為那表示公運處換了檔，要重抄。沒有 `TURNAROUND_DATA` 印用法。

理由：分數的出處要能回查，PDF 放資料根目錄跟其他外部快照一致；sha256 寫在設定裡，是把「這些分數抄自哪一個檔」綁死。替代方案：PDF 進 git（否決：13 MB 二進位檔，而且公運處的出版品不該由我們再散布原檔）。

### 頁面在折返點設施卡加「車輛所屬調度站」一段，只列數字與原值

`RoutePage::Depots.new(route_days)` 讀涵蓋日子裡最新一天的 `route_day_depots`，依 `n_buses` 多到少排，每列對 `config/depot_inspections.yml` 的 term（目前只有 115-1）分成三種：有分數（`scores`）、不在附錄（`not_in_appendix`）、還沒對（兩邊都沒有）。`TurnaroundFacilitiesComponent` 在兩端那兩欄之後加一段，小標「車輛所屬調度站」，一句說明「調度站是車輛所屬、駕駛報到的營業站，不一定是折返點。分數是公運處 115 年第 1 期評鑑到站檢查的結果，照報告書附錄抄錄」，然後每個調度站一塊：「臺北客運 板橋前站・75 輛・N 趟」，有分數的列九個項目各「8／8」（兩欄不同時兩個都寫、相同時寫一次，例如「8」）、「檢查日期 12月12日・附錄 A-8」與報告書公告頁的連結；不在附錄的寫「不在 115 年第 1 期的查核名單」；還沒對的寫「這個調度站還沒對過查核名單」。名稱空白的列寫「營業站 Id 16280」。不上色、不判定夠不夠，跟公廁那一段同一個態度。

理由：放在設施卡裡，是因為詞彙表把「折返點設施」定義成「每一端的折返點位置附近有什麼」，調度站是它最接近的鄰居；另開一張卡會多一個區塊連結，`route-page` 的「Section links」要改。替代方案：放在摘要（否決：摘要只放關鍵數字）；畫成表格一列一站（否決：九項乘兩欄在手機上放不下，一站一塊可以直排）。

### 顯名：第一行點名 GetProvider，另加一行報告書的顯名，引網站的資料開放宣告

三行聲明的第一行在「公車路線軌跡（GetBusShape）」之後加「業者營運基本資料（GetProvider）」，`docs/data-sources.md` 授權那一節、`attribution_component.yml`、`bin/health-card` 三處同一段字。名稱照 `01-bus-feeds-attribution` 的慣例用 API 說明文件的名稱（n-gear 的 `title_zh`），也就是 data.gov.tw 資料集 129032「臺北市業者營運基本資料」的標題；2026-10-24 查證，提供機關是臺北市公共運輸處、授權方式是政府資料開放授權條款第 1 版，頁面列的 JSON 是同一個主機上的 `TstProvider.json`。頁尾在公廁那一行之後、底圖那一行之前多一行：「臺北市公共運輸處 115年第1期臺北市市區公車營運服務指標評鑑總體報告書（pto.gov.taipei 公車評鑑專區），依該網站政府網站資料開放宣告（政府資料開放授權條款第 1 版）利用」，tw 與 en 同文。`docs/data-sources.md` 其他外部資料的表多一列，寫清楚這份不是 data.gov.tw 的資料集，授權依據是網站的宣告，查證日期 2026-10-24。

理由：`spec/analysis/attribution_spec.rb` 要求程式讀到的每一支 `Get*.gz` 都在第一行被點名；報告書不在 data.gov.tw，顯名要寫它實際的授權依據。

### 資料限制多一條

`DataLimitationsComponent` 的路線頁清單多一條：「調度站查核分數是公運處評鑑時到業者營業站檢查的結果，不是折返點的設施；車在折返停留期間有沒有回調度站，資料量不到。分數照報告書附錄抄錄，兩欄是報告書印的兩欄，不平均、不解讀；名單只有這一期受檢的營業站，不在名單不代表沒有休息設施。」每個路線頁都有這一條，因為每一頁都有調度站那一段。

### 詞彙表：折返點設施不再只有公廁，新增「調度站查核分數」

「折返點設施」的定義改成「每一端的折返點位置附近有什麼，以及這條路線的車從哪些調度站出來、那些調度站在評鑑裡拿幾分」，不要用那一行刪掉「（目前只有公廁）」。新增一條「調度站查核分數」：定義（公運處評鑑總體報告書附錄一的場站檢查評分表，我們抄跟休息有關的八項與總分，照原值、兩欄分開）、在資料或程式碼裡（`config/depot_inspections.yml`、`route_day_depots`、`RoutePage::Depots`）、邊界（分數是營業站的，不是折返點的；一期一份，下一期人工加；兩欄不平均）、不要用（場站評分、評鑑總分單獨出現時容易跟業者總分混、休息室評比）。

### 測試資料：fixture 的 GetProvider.gz 與 depot_inspections 的 test 區

`spec/fixtures/analysis/static/2026-10-19/GetProvider.gz`（以及 `02-route-307-page` 建的成員日快照 `static/2026-10-23/`）照真檔包 `EssentialInfo` 與 `BusInfo`，一列：`id` 9999、`nameZn` 測試客運、`stationId` 19001、`stationNameZn` 測試站；fixture 事件的 `StationID` 本來就都是 19001，所以 2026-10-19 的路線日有一個調度站、4 台車、趟次數等於當天趟次。`config/depot_inspections.yml` 的 `test` 區：term `115-1`，`depots` 一筆 測試客運 測試站（`printed_as` 測試 測試站、`inspected_on` 12月2日、`printed_page` A-99、九項分數 `[8, 9]`、`[7, 7]`、`[6, 6]`、`[5, 4]`、`[5, 5]`、`[5, 5]`、`[2, 2]`、`[2, 2]`、`[98, 97]`），`not_in_appendix` 一筆 測試客運 測試二站。元件測試用 factory 造 `route_day_depots` 的三種情形。

## Implementation Contract

- SQL：`bus_events` 多欄 `station_id`；新檢視 `trip_depots`（每趟多數票的 `station_id`）與 `route_day_depots`（`station_id, provider_name, station_name, n_buses, n_trips`）；`GetProvider.gz` 缺時 `provider_name`、`station_name` 是空字串並印那一行。
- 匯出與表：`depots.csv` 欄位 `station_id, provider_name, station_name, n_buses, n_trips`，依 `n_buses` 多到少、`station_id` 小到大；`route_day_depots` 欄位同名，`route_day_id` 外鍵隨路線日刪除。fixture 2026-10-19：一列 `19001, 測試客運, 測試站, 4, <當天趟次數>`。
- 設定：`config/depot_inspections.yml` 的結構如上；`RoutePage::Depots::Row` 帶 `provider_name, station_name, station_id, n_buses, n_trips, status (:scored | :not_in_appendix | :unchecked), inspection (term, printed_as, inspected_on, printed_page, scores)`。
- 頁面：`section[data-section="facilities"]` 裡多一個 `div[data-depots]`，每站 `div[data-depot][data-depot-status="scored|not_in_appendix|unchecked"]`，分數 `span[data-score="調度室環境"]` 這類以項目名為值的標記，文字「8／8」或「8」。
- 顯名：`AttributionComponent` 第一行含「業者營運基本資料（GetProvider）」，多一個 `p` 含「115年第1期臺北市市區公車營運服務指標評鑑總體報告書」與「政府網站資料開放宣告」；`bin/health-card` 的三行同字；`spec/analysis/attribution_spec.rb`、`card_spec.rb`、`spec/requests/site_layout_spec.rb` 的顯名例子過。
- `bin/rails external:pto_assessment TERM=115-1`：寫 `external/pto-assessment/115-1/report.pdf`，印路徑與 sha256；沒有 TERM 或設定裡沒有那個 term 印用法；HTTP 非 200 不寫檔、非零結束。
- 驗收：中山幹線的頁面列出光華巴士天東站（有分數、1月2日、A-7）、天西站與中和站（不在名單）；307 的頁面列出臺北客運板橋前站與民生站（有分數、12月12日 與 1月9日、A-8）、首都客運民生站與首都客運板橋前站（不在名單）；251 的頁面列出欣欣客運深坑站（不在名單）。
- 範圍外：折返點是否為調度站、座標、歷期、解析 PDF、其他指標。

## Risks / Trade-offs

- [人工抄錯分數] → 兩欄原值與頁碼都進設定，任務要求第二個人（或同一人隔天）對一次；sha256 綁檔。
- [GetProvider 的名稱跟附錄印的不同（板橋前 對 板橋前站）] → 設定的 `printed_as` 記附錄原字，對照用 `GetProvider.gz` 的全名，不做模糊比對，對不上就是還沒對過。
- [`StationID` 是登記的所屬站，不是當天實際出車的站] → 資料限制寫明；頁面稱「車輛所屬調度站」不稱「出車站」。
- [03-route-shape-map 同時改 site-layout 的同一條 requirement] → 這裡的 MODIFIED 以它歸檔後的主規格為底，apply 前 `/spectra-drift`，不同就重抄再改。
- [下一期公告後這一期的分數過時] → 頁面寫明期別與檢查日期；新期別是加一個 term 與重抄。
- [路線頁的調度站會變：新增路線頁、業者調車] → 設定沒列的站頁面寫「還沒對過查核名單」，不會被當成不在名單；新增路線頁時照 Context 的查法（幾天的趟次按 `route_day_depots` 的算法取調度站，對當天 `GetProvider.gz`）重查一次再補設定。事件層級會混進零星的別站 `StationID`（首都客運東園站就是這樣多列的），不能拿來定名單。

## Migration Plan

1. migration 建 `route_day_depots`；既有路線日沒有列，頁面寫「這幾天的資料還沒有調度站，重新執行 derived:load 後就會出現」（照公廁的 `needs_reload` 做法）。
2. 重跑有路線頁的路線最近幾天的 `derived:load`。
3. 回滾：drop table，頁面那一段消失，其餘不受影響。

## Open Questions

- 無。
