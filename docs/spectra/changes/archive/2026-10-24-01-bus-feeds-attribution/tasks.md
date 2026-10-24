<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
兩個任務都改 docs/data-sources.md，所以 1.2 接在 1.1 之後。
標任務完成時用明確的檔案清單（--file），不讓同時在工作的其他 session 的檔算進來。
-->

## 1. 查證與補上顯名

- [x] 1.1 套用 design「資料集頁面先查證，查不到就記推定」：逐一打開六支 feed 在 data.gov.tw 的資料集頁面（定時車機資訊 128710、定點車機資訊 128739、公車車上擁擠度 175726、路線 129024、附屬路線與路線對應資訊 128741，以及先要找到的站牌），確認提供機關是臺北市公共運輸處、授權是政府資料開放授權條款第 1 版；在 `docs/data-sources.md` 授權那一節列出六支的資料集名稱、網址與查證日期，拿掉到離站那支「沒找到單獨頁面，授權依同系列推定」；站牌找不到頁面時照那句的寫法記推定；把靜態那一節的「尚未採集」改寫成已經在收，寫出衍生表讀 GetRoute、GetStop、GetPathDetail 三支，並註明資料集頁面列的是 TstRoute.json 這類檔名、n-gear 照 API 說明文件 V6.3 抓 GetRoute.gz，同一個主機、同一個機關。授權或機關不對的那一支就停下回報，不往下做。這一步不改三行聲明本身。驗證：`docs/data-sources.md` 的每一列逐一對照 data.gov.tw 的頁面做內容審查；`spec/analysis/card_spec.rb` 照舊通過（引文還沒動）。
- [x] 1.2 實作 Attribution footer on every page 與 Limitations and attribution text 的修改，套用 design「一段聲明點名六支 feed，拿掉「即時」」「頁尾逐字對照文件，跟健檢卡同一個做法」與「用測試把聲明跟程式讀的 feed 綁在一起」：先寫測試——`spec/requests/site_layout_spec.rb` 加兩個例子（首頁頁尾聲明的三個 `p` 依序等於 `docs/data-sources.md` 授權那一節以 `> ` 開頭的三行；第一行含 GetBusData、GetBusEvent、BusSeatEvent、GetRoute、GetStop、GetPathDetail 而且不含「即時」），新增 `spec/analysis/attribution_spec.rb`（`analysis/*.sql` 傳給 `day_files` 的資料夾名照 `bus_event`、`bus_seat_event`、`bus_data` 對到代碼，對照裡沒有的名字讓測試失敗並寫出名字；`analysis/*.sql`、`app/**/*.rb`、`lib/**/*.rb`、`bin/*` 裡以 `Get` 開頭、`.gz` 結尾的檔名去掉副檔名；每個代碼都要出現在授權那一節的第一段引文，失敗時列出缺的代碼），確認新例子先失敗；再把新的第一行同時寫進 `docs/data-sources.md` 授權那一節的引文、`app/components/attribution_component.yml` 的 `statement` 與 `bin/health-card` 的 `ATTRIBUTION`，第二、三行不動。驗證：`bundle exec rspec spec/requests/site_layout_spec.rb spec/analysis/attribution_spec.rb spec/analysis/card_spec.rb` 全過（`card_spec.rb` 的「資料來源與授權一節逐字收錄……」對應 Scenario「Attribution reproduced」，`site_layout_spec.rb` 的兩個例子對應 Scenario「Statement as recorded」，`attribution_spec.rb` 對應 Scenario「Every bus feed named」）；`bin/rails parallel:spec` 全過；`bin/rubocop bin/health-card spec/requests/site_layout_spec.rb spec/analysis/attribution_spec.rb` 沒有 offense。 [after: 1.1]

## 2. 讓 03-route-shape-map 跟上

- [x] 2.1 套用 design「03-route-shape-map 跟著改：GetBusShape 寫進同一行」：在這個 change 歸檔之前，提醒使用者對暫存的 03-route-shape-map 跑 `/spectra-ingest 03-route-shape-map`，讓它的 `site-layout` delta 以這裡的版本為底、在第一行加上 GetBusShape，design 的顯名決定與任務 1.2 跟著改；這個任務本身不改 03-route-shape-map 的檔。驗證：`spectra validate 03-route-shape-map` 通過，而且它的 `specs/site-layout/spec.md` 含 Scenario「Every bus feed named」與 GetBusShape（ingest 之後做內容審查）。 [after: 1.2]
