## Why

這個 change 服務第一樣交付物「路線健檢卡」在網站上的入口。路線頁 `/routes/:route_id` 已經有了，但根路徑 `/` 還是 Rails 範本的小火車頁，要到路線頁只能直接打網址，第一次打開網站的人看不出這是什麼、有哪些路線、數字能信到哪。它需要的資料只有衍生表 `route_days`：每條有路線頁的路線最新寫入的台北日與路線名、起迄；路線清單來自 `config/route_page.yml`。不新增任何資料來源，不讀原始檔。

兩件首頁一上線就會被看到的事一起修。第一，`docs/data-sources.md` 寫明凡是用公運處這批資料做出來的東西都要帶顯名聲明，條款第三條規定未盡顯名義務者視為自始未取得授權，但 layout 與路線頁目前都沒有。第二，layout 的 `<title>` 與 `application-name` 兩頁都還是範本的「Website」。

首頁的插圖用 three.js 在瀏覽器裡播一次動畫：公車開進末站停下、車門打開、司機下車站到車旁，最後定格在跟靜態圖相同的構圖。同一個場景匯出的兩張 WebP 留作備援，給沒有 JS、設定減少動態效果、不支援 WebGL 或動畫載入失敗的情況。初版只上靜態圖，14 項做完後使用者看過，決定改成執行期動畫（2026-10-22）。

## What Changes

- 根路徑 `/` 重寫為首頁，由上到下：站名、一句問題當標題、一句話說這個網站量什麼、插圖、有頁面的路線清單、資料限制四條、資料從哪裡來。伺服器輸出的整頁不靠 JS 就完整；頁面專屬的 JS 只有插圖動畫，由 Alpine 元件在首頁按需載入。
- 路線清單列出 `config/route_page.yml` 裡每一條路線，一次查詢取各路線最新寫入的 `route_days`：有資料的顯示路線名、Id、起迄、最新資料日與星期，整張連到路線頁；還沒有資料的只顯示 Id 與「還沒有資料」。頁面上所有日期都從資料庫讀，文案不寫「每天更新」。
- layout 的 `<title>` 預設值與 `application-name` 改成站名「折返點 TurnAround」，站名放 `config/locales/tw.yml` 與 `en.yml`；新增顯名聲明的 footer，首頁與路線頁都帶：`docs/data-sources.md` 那三行原文、北捷出入口座標那一份的顯名、一句「提供資料不代表該機關推薦、同意或核准本專案」。
- 插圖：場景模組 `app/frontend/hero/scene.js`（three.js）由首頁與 `tools/hero/` 的匯出頁共用。場景是公車停在末站、車門開、司機站在車旁休息；一側是調度站的窗，站長面對一面排班板；另一側是站牌，兩三個民眾在等車。色票鎖在路線頁的 slate 與 teal，平塗、不畫五官、通用公車、沒有業者塗裝或機關標誌。
  - 首頁有 JS、允許動態效果、支援 WebGL 時：先保留插圖的空位、不顯示靜態圖，再載入 three.js、播一次動畫，最後定格在跟靜態圖相同的構圖並停止重繪。
  - 其他情況顯示靜態圖：匯出頁從同一個場景匯出 WebP，桌機全景與手機直式兩個鏡頭，放 `app/assets/images/`，由 propshaft 提供，頁面用 `<picture>` 依寬度切換。
  - `three` 改為 dependency，只進首頁動態載入的 chunk。
- `DataLimitationsComponent` 加 `scope:` 參數：首頁用新的標題 `home_title`（這些數字能信到哪）與 `home_items` 四條（車不等於人、車上人數看刷卡率、10 秒輪詢會漏站、跨小時檔有重複），路線頁用的 `title` 與 `items` 一字不動。
- `app/frontend/stylesheets/application.css` 拿掉 Rails 小火車主題：Fredoka、Baloo、railsred 兩色、九組 keyframes 與 `.pop`、`.ad-*`。首頁改用路線頁那套 Barlow 配 Noto Sans TC 與 slate、teal。
- `RouteCoverageComponent#day_label` 與 `WEEKDAYS` 上提到 `ApplicationComponent`，首頁的路線卡用同一個格式。
- `.dockerignore` 加 `/tools/`；`docs/spectra/LANGUAGE.md` 交付物一節加「首頁」與「顯名聲明」兩條。

## Non-Goals

- 月報、路線搜尋（清單只有一條路線時不放搜尋框）、車牌查詢、回報表單、共用的頁首導覽：各自等有東西再開 change，不留空殼。
- 首頁放任何指標：趟次、p10、達成率都不放。數字只住在路線頁，旁邊才有定義與資料限制；`route-page-charts` 的決策「不會出現第二套定義」在這裡一樣成立。
- 連到開源 repo、原始檔或 Parquet 釋出：`docs/decisions.md` 第 10 條是「準備開源」，還沒公開。首頁只連 `docs/data-sources.md` 裡已經存在的三個 data.gov.tw 資料集頁。
- 插圖的互動（拖曳旋轉、縮放、滑鼠視差）與循環播放：動畫每次進首頁播一次就停。其他頁面放 3D 也不在範圍內。
- 換 favicon（`public/icon.svg` 與 `icon.png` 的紅圓）：另一個作圖步驟，另開小 change。
- 路線頁專屬的 `<title>`（帶路線名）與把 Google Fonts 連結搬進 layout：兩者都要動 `app/views/routes/show.html.erb`，那個檔在 `zhongshan-turnaround-ends` 裡還在改。首頁照路線頁的做法用 `content_for :head` 自己載字體。
- 修改任何指標定義、路線頁的任何區塊、`DataLimitationsComponent` 路線頁用的 `items`。

## Capabilities

### New Capabilities

- `home-page`: 根路徑那一頁的內容與順序、路線清單讀什麼與怎麼排、還沒有資料的路線怎麼列、插圖怎麼提供與播放、頁面上不出現指標、頁面專屬的 JS 只有插圖動畫。
- `site-layout`: 每一頁從共用 layout 得到的兩件事：文件標題帶站名、顯名聲明 footer。

### Modified Capabilities

（無）

## Impact

- 路線頁（既有的 route-page 規格）的需求不變：區塊、順序與數字都不動，路線頁多出來的只有 layout 給的 title 與顯名聲明 footer，那兩件事由新的 site-layout 規格描述。
- 排程：`zhongshan-turnaround-ends` 還有 3.3 與 4.1 沒做完，3.3 會改 `app/components/data_limitations_component.yml` 的 `items` 與 `docs/spectra/LANGUAGE.md` 的「起站、末站、折返點、調度站」「換休息試算」兩條。這個 change 在同一個 yml 只加 `home_title` 與 `home_items`，在 LANGUAGE.md 只在交付物一節加兩條，並且完全不碰 `app/views/routes/show.html.erb`、`app/controllers/routes_controller.rb`、`spec/requests/routes_spec.rb`。apply 等那個 change archive 之後開始。
- 新增：app/models/home_page/route_list.rb；app/components/home_hero_component.rb、.html.erb、.yml；app/components/route_list_component.rb、.html.erb、.yml；app/components/data_sources_component.rb、.html.erb、.yml；app/components/attribution_component.rb、.html.erb、.yml；app/frontend/hero/scene.js、app/frontend/hero/runtime.js；tools/hero/index.html、tools/hero/export.js；app/assets/images/home-hero-wide.webp、app/assets/images/home-hero-tall.webp；spec/models/home_page/route_list_spec.rb；spec/components/route_list_component_spec.rb、spec/components/data_limitations_component_spec.rb、spec/components/data_sources_component_spec.rb、spec/components/home_hero_component_spec.rb；spec/requests/site_layout_spec.rb；spec/assets/home_hero_images_spec.rb；spec/system/home_hero_spec.rb。
- 修改：app/views/pages/home.html.erb、app/controllers/pages_controller.rb、app/views/layouts/application.html.erb、app/frontend/entrypoints/application.js（註冊插圖的 Alpine 元件與動態載入；Turbo 換頁前銷毀頁面上的 Alpine 元件）、spec/support/system.rb（不支援 WebGL 的 driver）、app/components/application_component.rb、app/components/route_coverage_component.rb、app/components/data_limitations_component.rb、app/components/data_limitations_component.yml（只加 `home_title` 與 `home_items`）、app/frontend/stylesheets/application.css、config/locales/tw.yml、config/locales/en.yml、.dockerignore、.rubocop.yml（RSpec/DescribeClass 排除 spec/assets，同 spec/analysis 的理由）、package.json、yarn.lock、docs/spectra/LANGUAGE.md、spec/requests/pages_spec.rb。
- 路線頁的 request spec 與元件 spec 不改；`spec/components/route_coverage_component_spec.rb` 在 `day_label` 上提後仍要綠。
- 相依：`three` 釘 0.186.1 放 dependencies，只被 `app/frontend/hero/` 引用。`application.js` 用動態 import 載入插圖動畫，Vite 把它打成獨立的 chunk，只有首頁會抓，入口 chunk 不帶 three。Dockerfile 的 `yarn install --frozen-lockfile` 與 build 流程不變：build 階段裝相依、build 完 `rm -rf node_modules`，映像檔只帶 `public/vite` 裡打包好的檔。`/tools/` 仍在 .dockerignore，匯出頁不進映像檔。
- 資料限制與假設：這個 change 不改任何指標定義。首頁只顯示 `docs/spectra/LANGUAGE.md`「資料限制」那四條：車不等於人、車上人數看刷卡率、10 秒輪詢會漏站、跨小時檔有重複。頁面上的日期全部從 `route_days` 讀，不寫「每天更新」，因為 `derived:load` 目前手動執行、還沒有每晚排程。
