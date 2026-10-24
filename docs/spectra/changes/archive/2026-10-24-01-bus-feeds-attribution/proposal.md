## Problem

這個 change 不直接做三樣交付物裡的哪一樣，而是三樣共用的前提：網站每一頁、健檢卡、之後的月報與釋出檔都要帶的顯名聲明。不需要新的資料，改的是怎麼標示已經在用的資料；資料集頁面的查證來源是 data.gov.tw。

衍生表與健檢卡是從臺北市公共運輸處的六支 feed 算出來的：三支動態的 GetBusData、GetBusEvent、BusSeatEvent，以及三支靜態的 GetRoute、GetStop、GetPathDetail（`analysis/10_load.sql` 讀它們，取路線名稱與起迄、站牌與座標、附屬路線的站序）。顯名聲明卻只點名三支動態的。政府資料開放授權條款第三條規定，未盡顯名義務者，視為自始未取得授權。

同一段聲明逐字出現在三個地方：

- `docs/data-sources.md` 的「授權」一節，是原文所在。
- `bin/health-card` 的 `ATTRIBUTION`，`spec/analysis/card_spec.rb` 會拿它跟 `docs/data-sources.md` 比。
- `app/components/attribution_component.yml` 的 `statement`，網站每一頁的頁尾；沒有任何測試拿它跟 `docs/data-sources.md` 比。

`docs/data-sources.md` 還有兩處過時：

- 寫著「到離站那支……沒找到單獨頁面，授權依同系列推定」，但 data.gov.tw 有「臺北市定點車機資訊」（data.gov.tw/dataset/128739，2026-10-24 查到）。
- 靜態那一節的標題寫「尚未採集」，n-gear 其實每天 04:30 都會抓一份靜態快照。

2026-10-24 在 data.gov.tw 查到的資料集頁面，提供機關都是臺北市公共運輸處，授權都是政府資料開放授權條款第 1 版：

| feed | 資料集頁面 |
| --- | --- |
| GetBusData 定時車機資訊 | data.gov.tw/dataset/128710（文件裡已有） |
| GetBusEvent 定點車機資訊 | data.gov.tw/dataset/128739 |
| BusSeatEvent 公車車上擁擠度 | data.gov.tw/dataset/175726（文件裡已有） |
| GetRoute 路線 | data.gov.tw/dataset/129024「臺北市路線」，頁面列的檔名是 TstRoute.json |
| GetPathDetail 附屬路線與路線對應 | data.gov.tw/dataset/128741「臺北市附屬路線與路線對應資訊」，頁面列的檔名是 TstPathDetail.json |
| GetStop 站牌 | 還沒查到，第一個任務查 |

## Root Cause

這段聲明是 2026-10-18 整理 `docs/data-sources.md` 時寫的。當時主資料只寫了動態 feed，靜態 feed 標成「尚未採集」。之後 `analysis/10_load.sql` 開始讀三支靜態檔，卻沒有人回頭改聲明。也沒有任何東西把「聲明點名了哪些 feed」跟「SQL 實際讀了哪些 feed」綁在一起：`spec/analysis/card_spec.rb` 只檢查健檢卡跟文件一致，網站頁尾連跟文件一致都沒有檢查。

## Proposed Solution

- **聲明第一行點名六支 feed**，拿掉「即時」兩個字，因為這一行也包含靜態資料。新的第一行是：「臺北市公共運輸處 2026 臺北市公車開放資料：定時車機資訊（GetBusData）、定點車機資訊（GetBusEvent）、公車車上擁擠度（BusSeatEvent）、路線（GetRoute）、站牌（GetStop）、附屬路線與路線對應（GetPathDetail），見 Data.Taipei 平台 API 說明文件 V6.3」。第二、三行不變。名稱用 API 說明文件的名稱，跟 n-gear 的 `title_zh` 一致。
- **三個地方改成同一段字**：`docs/data-sources.md`、`app/components/attribution_component.yml`（tw 與 en 同一段原文）、`bin/health-card` 的 `ATTRIBUTION`。
- **`docs/data-sources.md`**：「授權」一節列出六支 feed 的資料集頁面與查證日期，拿掉到離站的「推定」；靜態那一節改寫成已經在收，寫出衍生表讀哪三支，並註明資料集頁面列的是 TstRoute.json 這類檔名，n-gear 抓的是 API 說明文件 V6.3 的 GetRoute.gz，同一個主機、同一個機關。
- **兩個新測試**，把根因綁住：
  - 頁尾的三行聲明要跟 `docs/data-sources.md` 授權那一節的三段引文逐字相同，跟 `spec/analysis/card_spec.rb` 對健檢卡的做法一樣。
  - 聲明第一行要點名程式實際讀到的每一支公運處 feed：`analysis/` 的 SQL 傳給 `day_files` 的動態 feed，以及 `analysis/`、`app/`、`lib/`、`bin/` 裡寫到的、以 Get 開頭的 .gz 檔名（例如 `GetRoute.gz`）。03-route-shape-map 之後讀 GetBusShape.gz 時，沒有補上顯名這個測試就會失敗。
- **規格**：`site-layout` 的 Attribution footer on every page 寫明聲明第一行要點名衍生表用到的每一支公運處 feed；`health-card` 的 Limitations and attribution text 那個情境改成新的開頭。

這是從根因修：聲明跟程式讀的 feed 之間多了一道測試，頁尾跟文件之間也多了一道，以後加 feed 時不會再漏。

## Non-Goals

- 首頁「資料從哪裡來」那一塊：`home-page` 的 Data sources block 刻意只寫三支 feed、三個連結。要不要加上定點車機資訊（128739）或靜態資料集，另開 change。
- 重產 `docs/cards/15373-2026-10-19.md`：那是第一個 change 留下的一天版紀錄，layover-other-routes 也沒有重產。
- GetBusShape 的顯名：由 03-route-shape-map 加進這一行，見 Impact。
- 捷運、辦公日曆、公廁、底圖那幾行；法律意見（`docs/data-sources.md` 原本就寫明「以上是對條款的理解，不是法律意見」）。

## Success Criteria

- `spec/requests/site_layout_spec.rb`：首頁頁尾的三行聲明跟 `docs/data-sources.md` 授權那一節的三段引文逐字相同；第一行含 GetBusData、GetBusEvent、BusSeatEvent、GetRoute、GetStop、GetPathDetail，而且不含「即時」。
- 新的 `spec/analysis/attribution_spec.rb`：程式讀到的每一支公運處 feed，聲明第一行都有點名。
- `spec/analysis/card_spec.rb` 的「資料來源與授權一節逐字收錄……」照舊通過（`ATTRIBUTION` 跟著改）。
- `docs/data-sources.md` 的資料集頁面表逐一對照 data.gov.tw 的頁面做內容審查，記下查證日期；GetStop 有頁面就列，沒有就照原本到離站的寫法記「授權依同系列推定」。
- `bin/rails parallel:spec` 全過；`bin/rubocop bin/health-card spec/requests/site_layout_spec.rb spec/analysis/attribution_spec.rb` 沒有 offense。

## Impact

- Affected specs: `site-layout`（修改 Attribution footer on every page）、`health-card`（修改 Limitations and attribution text）
- Affected code:
  - Modified: docs/data-sources.md, app/components/attribution_component.yml, bin/health-card, spec/requests/site_layout_spec.rb
  - New: spec/analysis/attribution_spec.rb
  - Removed: (none)
- 沒有 migration、不重載資料、不加相依。頁尾的字下次部署就會更新。
- 跟暫存的 03-route-shape-map 有關，要一起處理：
  - 它的 `site-layout` delta 是以這個 change 之前的版本寫的。
  - 它的 design 決定「頁尾多一行公車路線軌跡的顯名」把 GetBusShape 放成獨立一行，理由是第一行寫著「即時」。這個 change 之後理由不成立，新的測試也會要求 GetBusShape 寫進第一行。
  - 它的任務 1.2 要改寫的靜態那一節，這裡就改了。
  - 所以這個 change 要排在 03-route-shape-map 之前歸檔，03-route-shape-map 要用 `/spectra-ingest 03-route-shape-map` 跟著改。
- 跟其他進行中或暫存的 change 不衝突：home-hero-samoyed-out-of-service、02-route-stop-sequence、load-chart-stretch-markers 都沒碰這四個檔。
- 資料限制與假設：這次不牽涉指標的定義。
