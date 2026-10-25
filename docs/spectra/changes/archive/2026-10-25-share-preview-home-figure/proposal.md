## Why

這個 change 服務第一樣交付物「路線健檢卡」在網站上的呈現：路線頁 `/routes/:route_id` 與首頁 `/`。不新增任何資料，讀的仍是衍生表 `route_days`、`route_day_stops` 與 `layovers`；用到的數字是折返停留表已經有的停車端「不到 15 分鐘的比例」、筆數與中位數（`RoutePage::LayoverStats` 的列），不牽涉指標定義。

2026-10-25 `/spectra-discuss` 的結論（選項 A）。黑客松「市政 debug 松」剩下的階段是線上票選，2026-10-31 18:00 截止，不設評審；投票的人點的是作品網址，看到的是首頁，轉貼出去的是路線頁的連結。兩個缺口：

- 路線頁沒有自己的 `<title>` 與分享文字。2026-10-25 查正式站，`/routes/15373` 與 `/routes/16111` 的 `<title>`、`og:title`、`og:description` 跟首頁一字不差（`app/views/routes/show.html.erb` 沒有設 `content_for :title`），轉貼到 LINE、Facebook、Threads 的預覽看不出是哪條路線、量到什麼。`home-page` 與 `site-easter-eggs` 兩次把「路線頁專屬的 `<title>`」列為非目標，理由都是當時那個檔在別的 change 裡改，不是拒絕。
- 首頁沒有任何網站自己量到的結果，只有起點區塊引用報導的「10 分鐘」。要知道中山幹線停車端有幾成停不到 15 分鐘，得點進路線頁讀一整頁。

## What Changes

- 路線頁涵蓋到資料時設自己的 `<title>`：路線名加站名，例如「中山幹線｜折返點 TurnAround」；layout 的 `og:title` 與 `twitter:title` 已經讀 `content_for(:title)`，跟著變。選的那一天沒有資料、或路線還沒有任何資料時，title 照舊是站名，`site-layout` 既有的情境不變。
- 路線頁涵蓋到資料時設自己的分享文字：layout 的 `meta name="description"`、`og:description`、`twitter:description` 改讀 `content_for(:description)`，沒有設時退回 `site.description`。那句話由新的查詢物件組成：起迄、涵蓋的日子與日型別，接著每一個停車端的末站、筆數、中位數與不到 15 分鐘的比例，數字跟摘要的重點數字出自同一個 `RoutePage::LayoverStats` 列、同一個格式；兩端都直接折返時寫沒有停車的一端；句尾寫折返停留是駕駛休息的上限。不出現門檻、合不合規、建議。
- 首頁每張有資料的路線卡多一個數字：每個停車端一行，「停車端停不到 15 分鐘的比例」加「末站・共 N 次折返」，取那條路線最新一天，也就是點進去預設看到的那一天，所以卡上的數字跟點進去後摘要的重點數字相同。沒有停車端的路線寫「兩端都是直接折返，沒有停車的一端」；停車端那天沒有折返停留時數字是「—」、筆數 0。所有路線最新一天的筆數與比例用一個查詢一起算，不逐路線查。卡仍然是一個連到 `/routes/<Id>` 的連結。清單下方的說明補一句這個數字是什麼、折返停留是休息的上限。
- 推翻 `home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」裡「不放指標」那一半：首頁放且只放這一個數字；日期仍全從 `route_days` 讀、不暗示更新頻率。design 用 Supersedes 記下。
- `docs/spectra/LANGUAGE.md`「首頁」條目的邊界跟著改。
- 規格：`home-page`（內容與順序、路線清單）、`site-layout`（title 與分享文字）、`route-page`（新增 title 與分享文字的要求）。

## Non-Goals

- 逐路線產 `og:image`：維持 layout 的通用分享圖。
- 首頁放其他數字：p50、趟次、捷運重疊、換休息試算都不放。
- 首頁的卡排序、篩選、搜尋、排行榜。
- 用顏色或門檻標示數字的好壞（`route-page-charts` 起四次非目標照舊）。
- 改站名、把路線名放進 `og:site_name`；title 加顏文字、切走分頁換 title（`site-easter-eggs` 的決定照舊）。
- 改 `RoutePage::LayoverStats` 與任何指標的定義、`analysis/`、衍生表、`bin/health-card`。
- 投票呼籲、黑客松標章、候選人或政見的任何元素（`home-origin-story` 與 `site-easter-eggs` 的決定照舊）。
- 全路網、其他路線、排程與部署。
- 404 頁與 400 回應的 title 與分享文字。

資料限制與假設。這個 change 不改定義，只把既有的數字放到新的位置，所以限制跟折返停留表相同，要寫在數字旁邊：

- 車不等於人：折返停留是駕駛休息的上限，不是工時。分享文字的句尾與首頁清單的說明都寫出來。
- 只算量得到的折返停留（本趟有到末站、下一趟從起站出發、中間沒跑別的路線）；10 秒輪詢漏站會讓一部分折返停留量不到，比例的分母是量到的筆數，所以筆數一定跟比例一起出現。
- 首頁取最新一天，一天的筆數比最近 7 天少：中山幹線停車端 2026-10-22 當天 36 筆、52.8% 不到 15 分鐘，最近 7 天（四個平日）154 筆、45.5%（2026-10-25 從開發資料庫算的）。
- 跨小時檔的重複在衍生表之前已經去掉，這裡不另外處理。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `home-page`: 「Home page content and order」從「不放任何指標」改成只放一個：每張有資料的路線卡放每個停車端最新一天的不到 15 分鐘比例與筆數，其餘不放；「Route list」的條目內容加上這一行與沒有停車端、沒有折返停留的寫法。
- `site-layout`: 「Document title carries the site name」容許頁面自己設 title（路線頁設「路線名｜站名」）；新增分享文字的要求：description、og、twitter 三組跟著頁面的 title 與 description，頁面沒設時用站名與站的描述。
- `route-page`: 新增要求「Document title and share text」：涵蓋到資料時 title 與分享文字的內容、沒有資料時退回站名與站的描述。

## Impact

- Affected specs: home-page, site-layout, route-page
- Affected code:
  - New: app/models/route_page/share_preview.rb（組路線頁的 title 與分享文字）、app/models/home_page/stop_end_figures.rb（所有路線最新一天每個停車端的筆數與比例，一次查詢）、spec/models/route_page/share_preview_spec.rb、spec/models/home_page/stop_end_figures_spec.rb
  - Modified: app/views/layouts/application.html.erb、app/views/routes/show.html.erb、app/models/home_page/route_list.rb、app/components/route_list_component.rb、app/components/route_list_component.html.erb、app/components/route_list_component.yml、app/controllers/pages_controller.rb（只改註解）、config/locales/tw.yml、config/locales/en.yml、docs/spectra/LANGUAGE.md、spec/requests/routes_spec.rb、spec/requests/site_layout_spec.rb、spec/requests/pages_spec.rb、spec/components/route_list_component_spec.rb、spec/models/home_page/route_list_spec.rb
  - Removed: (none)
- Compatibility: 網址、參數、衍生表、路線頁既有區塊都不變。首頁多讀 `layovers` 與 `route_day_stops`，對所有路線的最新一天一次算完，test 環境的 Bullet 不會看到逐路線查詢。
- 部署：不用重跑 `derived:load` 或 `bin/push-derived`，deploy 之後就生效。
- 跟工作區裡 `small-sample-grey`（done，未歸檔、未 commit）沒有共用的檔。
