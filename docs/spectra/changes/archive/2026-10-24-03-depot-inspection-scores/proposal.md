## Why

這個 change 服務三樣交付物的第一樣路線健檢卡（路線頁）裡的「折返點設施」：現在只有公廁。公運處每期評鑑都會到每家業者的營業站實地檢查調度室、休憩室、盥洗室、禁菸、停車場，分數印在評鑑總體報告書的附錄裡，這是駕駛休息環境唯一公開、逐站、有分數的紀錄。這個 change 把它接到路線頁：每條路線的車當天從哪幾個調度站出來、那幾站在這一期評鑑拿幾分。

需要的資料有三份。第一份是既有的動態 feed：到離站事件每一筆都帶 `StationID`（車輛所屬營業站），原始檔已經在收，只是 `analysis/10_load.sql` 沒讀這個欄位。第二份是靜態快照裡的 `GetProvider.gz`（業者與營業站的名稱），n-gear 每天抓，程式還沒讀過。第三份是新的：臺北市公共運輸處公車評鑑專區 2026-07-21 公告的「115年第1期臺北市市區公車營運服務指標評鑑總體報告書」PDF（13.2 MB、607 頁），2026-10-24 下載的檔 sha256 是 `5eee1a7f2022e286018fc472db3164b1930f24548c42410b56d0f41920ecb5ec`。附錄一「臺北市公共運輸處市區公車場站檢查評分表」在印刷頁 A-3 到 A-17（PDF 第 313 到 327 頁），15 家業者 59 個營業站，每站兩欄分數、一個檢查日期，23 項檢查與總分。公運處網站的「政府網站資料開放宣告」採政府資料開放授權條款第 1 版，使用時應註明出處，所以可以用，顯名要寫。

對已有與將有路線頁的路線，2026-10-24 讀附錄查到的：307（臺北客運板橋前站 75 輛、首都客運民生站 30 輛、臺北客運民生站 10 輛，2026-10-24 快照的車輛所屬）裡臺北客運的兩站都在 A-8，板橋前 12月12日檢查、民生站 1月9日檢查，首都客運民生站不在；251 與 251區 的欣欣客運深坑站不在（A-4 的欣欣只有木柵一站、景新、木柵二站、華江、富德站，A-11 的「深坑站」是指南客運的）；265區 的三重客運與大南汽車土城站都不在。apply 開工前照 `route_day_depots` 的算法（每趟取事件裡最多的 `StationID`）重算 2026-10-19 到 10-23 每個路線頁的調度站（實測，每天的車數），補上 propose 時漏看的：已有路線頁的中山幹線，它的光華巴士天東站（11 到 26 台）在 A-7、1月2日檢查，天西站（2 到 7 台）與中和站（1 到 4 台）不在；307 另有首都客運板橋前站（每天 1 台）不在名單。所以第一條看得到分數的路線是中山幹線，不是 propose 時寫的 307。這個 change 仍排在 `02-route-307-page` 之後，因為 307 的頁面與 fixture 的成員日 `static/2026-10-23/` 由它建立；251 的頁面會寫「深坑站不在這一期的查核名單」。

## What Changes

- 衍生表多一張 `route_day_depots`：每個路線日每個調度站一列，業者名稱、營業站名稱、當天從這裡出車的車數與趟次數。調度站取每趟到離站事件裡出現最多的 `StationID`，名稱對當天 `GetProvider.gz`；快照沒有這支檔時列仍存、名稱空白。`bin/rails derived:load` 與 `bin/health-card` 共用的 SQL 多讀 `StationID` 與 `GetProvider.gz`。
- 新的 `bin/rails external:pto_assessment TERM=115-1` 把報告書 PDF 存進資料根目錄 `external/pto-assessment/115-1/`，印 sha256。
- 新的 `config/depot_inspections.yml`：這一期的來源（標題、公告頁、下載網址、sha256、附錄頁碼）、我們挑的九個項目與比重、人工對著附錄抄的分數（兩欄原值、檢查日期、頁碼），只抄有路線頁的路線的調度站；另列已經翻過整份附錄、確認不在名單裡的調度站。
- 路線頁「折返點設施」卡多一段「車輛所屬調度站」：涵蓋日子裡最新一天的每個調度站，幾台車、幾趟，在名單裡的列出九項分數與總分、檢查日期、附錄頁碼；不在名單的寫不在；設定裡沒有對過的寫還沒對。只列數字，不判定好壞，並寫明調度站不是折返點。
- 顯名：三行聲明的第一行多點名 GetProvider（`docs/data-sources.md`、頁尾、健檢卡三處同一段字，`spec/analysis/attribution_spec.rb` 與 `card_spec.rb` 會擋）；頁尾多一行報告書的顯名，引公運處網站的政府網站資料開放宣告。
- 資料限制多一條；`docs/data-sources.md` 其他外部資料多一列；`docs/spectra/LANGUAGE.md`「折返點設施」改寫、新增「調度站查核分數」。

## Non-Goals

非目標寫在 design。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `turnaround-facilities`：新增「車輛所屬調度站」的衍生資料與頁面上的查核分數一段。
- `derived-tables`：新增 `route_day_depots` 隨路線日匯出、寫入、刪除，`GetProvider.gz` 可缺。
- `site-layout`：「Attribution footer on every page」第一行多 GetProvider，多一行報告書的顯名。
- `route-page`：新增調度站查核分數的資料限制那一條。

## Impact

- 修改 `analysis/10_load.sql`（`bus_events` 讀 `StationID`、讀 `GetProvider.gz`）、新增 `analysis/depots.sql` 或併進 `turnaround_facilities.sql`、`analysis/derived_export.sql` 多 `depots.csv`；`app/models/route_day_loader.rb`、新 model `RouteDayDepot`、新 migration `create_route_day_depots`（`route_day_id` 隨路線日刪除，唯一 `(route_day_id, station_id)`）。
- 新增 `app/models/pto_assessment_snapshot.rb`、`lib/tasks/external.rake` 的 `pto_assessment`、`config/depot_inspections.yml`、`app/models/route_page/depots.rb`；修改 `app/components/turnaround_facilities_component.*`、`attribution_component.yml`、`data_limitations_component.yml`、`bin/health-card` 的顯名段、`docs/data-sources.md`、`docs/spectra/LANGUAGE.md`。
- fixture：`spec/fixtures/analysis/static/2026-10-19/GetProvider.gz`（與 `02-route-307-page` 加的成員日快照 `static/2026-10-23/`）；既有事件的 `StationID` 都是 19001。
- 依賴：`02-route-307-page`（307 的頁面與成員日 fixture）、`03-route-shape-map`（它正在改 `site-layout` 的同一條 requirement，這裡的 MODIFIED 以它歸檔後的主規格為底，apply 前先 `/spectra-drift`）。
- 資料限制與假設：指標定義不變，限制照舊：車不等於人，折返停留是駕駛休息的上限；車上人數看下車刷卡率；10 秒輪詢會漏站；跨小時檔的重複已以 `(BusID, DataTime)` 去除。這次多的：分數是公運處評鑑時對業者營業站的檢查，不是折返點的設施，車在折返停留期間有沒有回調度站，資料量不到；兩欄分數照報告書印的抄，不平均、不解讀；檢查日期報告書只印月日；名單只涵蓋 59 個營業站，不在名單不代表沒有休息設施；`StationID` 是車機登記的所屬營業站，車借調時可能跟實際出車的站不同。
