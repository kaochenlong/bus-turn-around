## Why

這個 change 服務三樣交付物的第一樣路線健檢卡：每條路線每月一份、可以印、可以引用的文件。需要的資料都在衍生表（趟次、折返停留、`01-rest-windows` 的連續 4／6 小時視窗、`02-published-schedule` 的公告班距），再加上辦公日曆、`config/derived_days.yml` 與原始檔的檢查，用來交代這個月涵蓋了哪幾天、少了哪幾天。

路線頁給人看某一天與最近 7 天，健檢卡要回答的是另一件事：這條路線一整個月的休息與班表是什麼樣子，跟上個月比有沒有變。`docs/use-cases.md` 從一開始就把節奏定成每月一份，詞彙表的健檢卡也定義成每月定稿一版，但目前只有給定義測試用的一天版 Markdown（`bin/health-card`）。公運處的動態資料約十分鐘就消失，跨月的比較只有自己收下來的資料做得到，這是路線頁與公開資料都沒有的部分。

內容在 2026-11-02 用中山幹線 10 月的試印看過一輪，留下直指駕駛休息與班表的區塊，拿掉折返點設施、調度站查核分數、捷運重疊與車上人數，資料限制改寫在各區塊的內文。

為什麼現在：第一份公開的月卡是 2026 年 11 月，要在 12 月初印出來。這個 change 先做出頁面，印製、存檔與下載是 `04-monthly-card-pdf`。

## What Changes

- 新表 `route_cards`：一條路線一個月一列，存這個月的涵蓋（這個月有幾個平日與假日、載入了幾個、少了哪幾天與原因）。不參照 `route_days`，`bin/push-derived` 不會動它。
- `RouteCardCoverage` 把一個月的每一天歸成四種：已載入、在跳過名單、原始檔不齊、還在等；有還在等的日子就不算到齊。新 rake task `bin/rails cards:prepare ROUTE=<路線 Id> MONTH=<YYYY-MM>` 算好涵蓋並寫一列。
- 新頁面 `GET /routes/<路線 Id>/cards/<YYYY-MM>`：照 A4 直式排的月卡，內容依序是摘要、折返停留、連續行駛、班表對照、來回一趟與週期、行駛時間與站間車速、換休息試算、歷史、資料來源與顯名聲明。平日與假日分開，數字來自既有的查詢物件，一個月就是一組路線日。
- 新查詢物件：`RoutePage::LayoverHours`（依車回來的小時）、`MonthDays`（逐日）、`SlowLegs`（站間車速最慢的幾段）、`MonthFindings`（第 1 頁「這個月看到的事」的句子）、`CardTrend`（逐月表）。
- `docs/spectra/LANGUAGE.md` 改「健檢卡」「資料限制」的定義，新增「月卡」的涵蓋與部分月份。

## Non-Goals

非目標寫在 design。

## Capabilities

### New Capabilities

- `monthly-card`：一條路線一個月的健檢卡：涵蓋怎麼算、頁面有哪些區塊與數字、哪些區塊不放。

### Modified Capabilities

（無）

## Impact

- 新增 `app/models/route_card.rb`、`app/models/route_card_coverage.rb`、`app/models/route_page/month_card.rb`、`layover_hours.rb`、`month_days.rb`、`slow_legs.rb`、`month_findings.rb`、`card_trend.rb`、`app/controllers/route_cards_controller.rb`、`lib/tasks/cards.rake`、`app/views/route_cards/`、月卡各區塊的 ViewComponent、`config/routes.rb` 一條路由、`app/frontend/stylesheets/application.css` 的列印規則、一個 migration 與對應的測試。
- 修改 `docs/spectra/LANGUAGE.md`。
- 先決條件：`01-rest-windows` 與 `02-published-schedule` 都歸檔並 commit。
- 網站上看不到入口：名稱列的連結在 `04-monthly-card-pdf`。沒有 `route_cards` 那一列的月份回 404，所以 deploy 這個 change 不會多出公開內容。
- 資料限制與假設：車不等於人，雙班制下一台車兩個人開，這些數字對不到某一個駕駛；折返停留是駕駛休息的上限，不是工時；10 秒輪詢會漏站，不完整的趟次會切斷連續行駛的序列；跨小時檔的重複已以 `(BusID, DataTime)` 去除；這份卡不報車上人數，刷卡率不影響。公開資料沒有排定的行駛時間、核定班次與配車數，所以比不出「班表給了幾分鐘」，也判斷不了是否脫班；事故與投訴不在公開資料裡。這些限制改寫在各區塊內文，所以「資料限制」那一條的邊界要跟著改（見 design）。
