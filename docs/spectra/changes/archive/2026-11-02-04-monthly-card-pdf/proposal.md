## Why

這個 change 服務三樣交付物的第一樣路線健檢卡：`03-monthly-card` 做出月卡頁之後，還要有一份不會再變的檔案可以下載、可以引用，而且每個月自動產生。需要的資料是 `03-monthly-card` 的頁面與涵蓋，加上每晚載入的狀態；排程跑在放原始檔的 Mac mini。

用瀏覽器的列印做不到這件事：頁面每次打開都從衍生表重算，定義或資料一改，同一個月的數字就變了；不同瀏覽器印出來的版面也不同；「下載」會變成叫出列印對話框。引用要的是每個人拿到同一份。Mac mini 已經裝了 Chrome（2026-11-02 查的），每小時已經在跑 `bin/nightly-load`，正式站不用多裝任何東西。

為什麼現在：第一份公開的月卡是 2026 年 10 月，接上排程就印；11-30 的資料在 12-01 清晨載入後，這個排程就要能自己印出 11 月。

## What Changes

- **推翻非目標**：`timetable-draft` 的「伺服器端產 PDF。」重開，範圍只有定稿的月卡，而且只在 Mac mini 上印。班表頁與當天調度的列印照舊用瀏覽器；`timetable-draft` 否決 Prawn、Grover 的理由（新依賴、部署要多裝東西）照舊成立，這次不加 gem、Droplet 不裝 Chrome。
- 新指令 `bin/monthly-cards`：不加參數只印計畫；`--print` 把到齊而且還沒印的月份印成 PDF，存進正式站資料庫，並在 mini 留一份；`--revise` 出更正版並寫原因；`--sample` 印一份不存的試印檔；`--restore` 在資料庫重建之後，把 mini 留的那份存回去。接在每小時的排程後面，上個月資料到齊的那一次就會印，通常是每月 1 號清晨。
- 印之前先確認頁面回 200 而且真的是那一份，印好檢查是不是 PDF。印過的版本不再改，mini 上留的那份也不會被蓋掉。
- 新頁面 `GET /routes/<路線 Id>/cards`：這條路線的月份清單，每個月的涵蓋與下載連結；還沒有檔案時寫第一份什麼時候出。`GET /routes/<路線 Id>/cards/<YYYY-MM>.pdf` 下載定稿檔。
- 月卡頁多三個 meta，寫明它是哪一份、哪個程式版本與哪些數字；數字不完整的提醒改標 `data-card-incomplete`。`cards:prepare` 拒絕已經印過的月份。
- 名稱列在路線相關的頁面多一個連結「健檢卡」，放在「當天調度」右邊；手機上縮標誌、間距與字級，390 與 360 寬都放得下。
- `docs/decisions.md` 記一條、`AGENTS.md` 加指令、`docs/spectra/LANGUAGE.md` 的健檢卡補上定稿與下載。

## Non-Goals

非目標寫在 design。

## Capabilities

### New Capabilities

- `monthly-card-pdf`：月卡的印製、定稿、更正、本機副本與還原、排程與下載，以及月份清單。

### Modified Capabilities

- `monthly-card`：「Month card page」多三個 meta 與 `data-card-incomplete`；「Preparing a route card」拒絕已印的月份。
- `site-layout`：「Site name bar on every page」多一個連結，手機上要放得下。

## Impact

- 新增 `bin/monthly-cards`、`app/models/monthly_cards_command.rb`、`app/models/production_session.rb`、`app/models/card_printer.rb`、`app/models/card_months.rb`、`app/models/route_card_pdf.rb`、`app/models/route_card_local_copy.rb`、`config/route_cards.yml`、月份清單的 view 與 ViewComponent、一個 migration（`route_cards` 加欄位、新表 `route_card_pdfs`）、對應的測試。
- 修改 `app/controllers/route_cards_controller.rb`、`config/routes.rb`、`app/models/route_card.rb`、`app/models/route_day.rb`、`app/models/route_card_prepare_command.rb`、`app/models/nightly_load_command.rb`（鎖、轉送與 migration 檢查移到 `ProductionSession`，行為不變，只有鎖的訊息改成點名兩個指令）、`app/views/route_cards/show.html.erb`、`app/frontend/stylesheets/application.css`、`app/components/site_bar_component.*`、`docs/decisions.md`、`AGENTS.md`、`docs/spectra/LANGUAGE.md`。路線頁、班表頁、當天調度頁的 controller 已經設 `@timetable_route_id`，名稱列的新連結不用改它們。
- repo 外：mini 上包一層的 `nightly-load.sh` 要接上 `bin/monthly-cards --print`，由使用者改（`docs/decisions.md` 第 14 條，排程的 script 放 repo 外）。
- 容量：一份約 2.4 MB（`03-monthly-card` 印的 15373、16111 十月是 2.37、2.41 MB，量到的）。七條路線一個月約 17 MB、一年約 200 MB（估的，用第一次真的印出來的大小確認）。字型被 Chrome 嵌成 Type 3 所以偏大，換靜態字型應該能縮小，還沒測。
- 資料限制與假設：月卡內容的限制見 `03-monthly-card`，這個 change 不改任何數字。定稿的檔案是印製當下的數字，之後定義或資料重算，舊檔不變，新的一份在逐月表上註明。
