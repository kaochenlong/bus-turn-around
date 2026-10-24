## Context

公運處資料的顯名聲明是三行，原文在 `docs/data-sources.md` 的「授權」一節（三段 `> ` 引文），另外逐字出現在兩個地方：

- `bin/health-card` 的 `ATTRIBUTION`：健檢卡的「資料來源與授權」一節。`spec/analysis/card_spec.rb` 的「資料來源與授權一節逐字收錄……」取 `docs/data-sources.md` 授權那一節以 `> ` 開頭的行，檢查每一行都在卡裡。
- `app/components/attribution_component.yml` 的 `statement`（tw 定義，zh-TW 與 en 共用同一段原文）：layout 的頁尾，每一頁都有。`spec/requests/site_layout_spec.rb` 只檢查頁尾存在、底圖那一行，沒有檢查這三行。

已核對的事實（2026-10-24）：

- 程式讀的公運處 feed 有六支：`analysis/10_load.sql` 以 `day_files('bus_event', …)`、`day_files('bus_seat_event', …)` 讀兩支動態 feed 的小時檔，以 `read_json(… '/GetRoute.gz')`、`'/GetStop.gz'`、`'/GetPathDetail.gz'` 讀三支靜態檔；`analysis/turnaround_facilities.sql` 以 `day_files('bus_data', …)` 讀 GPS。`bin/health-card` 與 `app/models/derived_load_command.rb` 也寫到同樣三個靜態檔名（檢查檔案在不在）。程式碼與 SQL 裡沒有出現其他以 `Get` 開頭的 `.gz` 檔名。
- data.gov.tw 的資料集頁面見 proposal 的表。「臺北市路線」（129024）與「臺北市附屬路線與路線對應資訊」（128741）頁面上的 JSON 是 `TstRoute.json`、`TstPathDetail.json`，跟 n-gear 照 API 說明文件 V6.3 抓的 `GetRoute.gz`、`GetPathDetail.gz` 同一個主機（`tcgbusfs.blob.core.windows.net/blobbus/`）、同一個機關。
- 首頁的「資料從哪裡來」（`DataSourcesComponent`）照 `home-page` 的 Data sources block 只列三個連結，這次不動。

詞彙照 `docs/spectra/LANGUAGE.md`：顯名聲明、動態 feed、靜態 feed、衍生表、健檢卡。不新增詞。

## Goals / Non-Goals

**Goals:**

- 聲明點名程式讀到的每一支公運處 feed，網站、健檢卡、文件三處一字不差。
- 以後加 feed 時，沒補上顯名會有測試失敗。

**Non-Goals:**

- 首頁「資料從哪裡來」、重產舊的一天版卡、GetBusShape（由 03-route-shape-map 加）、其他資料集的顯名行、法律意見。理由見 proposal 的 Non-Goals。

## Decisions

### 一段聲明點名六支 feed，拿掉「即時」

第一行改成「臺北市公共運輸處 2026 臺北市公車開放資料：定時車機資訊（GetBusData）、定點車機資訊（GetBusEvent）、公車車上擁擠度（BusSeatEvent）、路線（GetRoute）、站牌（GetStop）、附屬路線與路線對應（GetPathDetail），見 Data.Taipei 平台 API 說明文件 V6.3」，第二、三行不變。先列原本的三支動態 feed、再列靜態的，名稱用 API 說明文件的名稱（n-gear 的 `title_zh`）；原本第一行的「公車車上擁擠度」照舊。

理由：六支都是同一個機關、同一份 API 說明文件、同一個授權，條款附件的格式是「提供機關、年份、資料名稱」，一段列完讀的人最清楚，聲明也維持三行，`site-layout` 那條規格「三行聲明」的寫法不用改。「即時」拿掉，因為這一行開始包含一天一份的靜態資料。

替代方案：靜態另起一行「臺北市公車靜態資料：……」（同一個機關分兩段，聲明變四行，健檢卡與頁尾的測試都要跟著改結構，否決）；保留「即時」再加「與靜態」（字變長，沒有多傳達什麼，否決）。

### 頁尾逐字對照文件，跟健檢卡同一個做法

`spec/requests/site_layout_spec.rb` 加一個例子：取 `docs/data-sources.md` 授權那一節以 `> ` 開頭的三行（取法照 `spec/analysis/card_spec.rb`），跟首頁頁尾聲明的三個 `p` 的文字依序比對，要完全相同。再加一個例子：第一行含六個代碼、不含「即時」。

理由：頁尾是最多人看到的地方，卻是三處裡唯一沒有被測試綁住的。照健檢卡已經在用的取法，兩邊用同一套規則，`docs/data-sources.md` 一改，兩邊的測試都會檢查。

替代方案：頁尾直接讀 `docs/data-sources.md`（執行期讀 docs 檔，部署的映像檔要帶 docs，否決）；只斷言含某些字（文件與頁尾在其他地方分歧時抓不到，否決）。

### 用測試把聲明跟程式讀的 feed 綁在一起

新增 `spec/analysis/attribution_spec.rb`（不需要 DuckDB）：

1. 從 `analysis/*.sql` 收集傳給 `day_files('…'` 的 feed 資料夾名，照固定的對照轉成代碼：`bus_event` → GetBusEvent、`bus_seat_event` → BusSeatEvent、`bus_data` → GetBusData。遇到對照裡沒有的資料夾名，測試失敗，訊息寫出那個名字，要人去補對照與顯名。
2. 從 `analysis/*.sql`、`app/**/*.rb`、`lib/**/*.rb`、`bin/*` 收集符合 `Get` 開頭、`.gz` 結尾的檔名，去掉 `.gz` 就是代碼。
3. 斷言兩者的聯集，每一個代碼都出現在 `docs/data-sources.md` 授權那一節的第一段引文裡；失敗訊息列出缺的代碼。

理由：根因是「SQL 開始讀新的 feed，沒人回頭改聲明」，只有把兩邊綁在一起才算修好。03-route-shape-map 之後在 `RouteDayLoader` 寫到 `GetBusShape.gz`，這個測試就會要求聲明點名 GetBusShape。掃 Ruby 與 SQL 而不是只掃 SQL，是因為 03-route-shape-map 的路徑由 Ruby 決定。

替代方案：在測試裡寫死六個代碼（下一支 feed 照樣會漏，否決）；從 n-gear 的 `Feeds` 讀（網站不載入 n-gear，而且 n-gear 列的是採集的 23 支，不是網站用的，否決）。

### 資料集頁面先查證，查不到就記推定

第一個任務逐一打開六支 feed 在 data.gov.tw 的資料集頁面（站牌那支要先找到），確認提供機關是臺北市公共運輸處、授權是政府資料開放授權條款第 1 版，把名稱、網址與查證日期寫進 `docs/data-sources.md` 授權那一節。站牌找不到頁面時，照原本對到離站的寫法記「同一份 API 說明文件、同一個主機，授權依同系列推定」。查到哪一支的授權不是第 1 版，或提供機關不同，就停下回報，不把它寫進這一行。

理由：聲明寫的是對條款的承諾，先查再寫。

替代方案：直接照推定寫（三支已經查得到頁面，沒有理由用推定，否決）。

### 03-route-shape-map 跟著改：GetBusShape 寫進同一行

這個 change 歸檔之後，`site-layout` 的主規格是這裡的版本。暫存的 03-route-shape-map 要用 `/spectra-ingest 03-route-shape-map` 跟著改：

- 它的 `site-layout` delta 改以這裡的版本為底，在第一行的代碼表加上 GetBusShape，不再另起一行。
- 它的 design 決定「頁尾多一行公車路線軌跡的顯名，授權先查證」改成「GetBusShape 寫進公運處聲明的第一行」，原本的否決理由（第一行寫著「即時」）不再成立。
- 它的任務 1.2 不用再改寫靜態那一節。

歸檔順序是 01-bus-feeds-attribution 先、03-route-shape-map 後。這個 change 本身不改 03-route-shape-map 的任何檔。

理由：同一條 requirement 被兩個 change 修改，後歸檔的要寫在前一個的版本上，才不會把它的字吃掉；新的測試也會讓「另起一行」的做法失敗。

## Implementation Contract

**行為**：

- 每一頁頁尾的公運處聲明第一行點名六支 feed，不再寫「即時」；`bin/health-card` 產出的卡同一段；`docs/data-sources.md` 授權那一節是同一段，並列出六支 feed 的資料集頁面與查證日期。
- `docs/data-sources.md` 靜態那一節寫明已經在收、衍生表讀哪三支。
- 程式之後讀到新的公運處 feed、聲明沒有點名時，`spec/analysis/attribution_spec.rb` 失敗並寫出缺的代碼。

**介面與資料形狀**：

- `app/components/attribution_component.yml` 的 `statement` 第一個元素換成新的第一行；`AttributionComponent` 的 `.rb` 與 `.html.erb` 不改。
- `bin/health-card` 的 `ATTRIBUTION` 第一段換成同一行。
- `spec/analysis/attribution_spec.rb`：資料夾名到代碼的對照寫在 spec 裡（三個）；掃描的範圍是 `analysis/*.sql`、`app/**/*.rb`、`lib/**/*.rb`、`bin/*`。

**失敗模式**：

- 對照裡沒有的 `day_files` 資料夾名：測試失敗，訊息寫出資料夾名。
- 某支 feed 查證時授權或機關不對：任務停下回報，不寫進聲明。

**驗收**：

- `bundle exec rspec spec/requests/site_layout_spec.rb spec/analysis/attribution_spec.rb spec/analysis/card_spec.rb` 全過；新加的例子在改聲明之前先失敗。
- `bin/rails parallel:spec` 全過；`bin/rubocop bin/health-card spec/requests/site_layout_spec.rb spec/analysis/attribution_spec.rb` 沒有 offense。
- `docs/data-sources.md` 的資料集頁面逐一對照 data.gov.tw 做內容審查。

**範圍邊界**：範圍內是三處聲明的第一行、`docs/data-sources.md` 的授權與靜態兩節、兩個測試、兩份規格。範圍外是首頁「資料從哪裡來」、其他顯名行、`docs/cards/` 的舊卡、03-route-shape-map 的檔、部署。

## Risks / Trade-offs

- [掃描抓到註解裡提到、但沒有真的讀的檔名] → 現在程式與 SQL 裡出現的 `Get*.gz` 只有那三個（2026-10-24 查過）；真的遇到時，要嘛補顯名，要嘛改註解的寫法，兩者都是有意識的決定。
- [資料集頁面列的檔名（TstRoute.json）跟 n-gear 抓的（GetRoute.gz）不同] → 同一個機關、同一個主機、同一份 API 說明文件；寫進 `docs/data-sources.md`，讓之後的人知道這是查過的。
- [03-route-shape-map 忘了跟著改] → 新的測試會讓它在 apply 時失敗；proposal 與這份 design 都寫明要先 ingest。

## Migration Plan

- 沒有 migration，不重載資料。部署之後頁尾就是新的字。
- 回退：還原三處聲明與兩份文件，拿掉兩個測試。
