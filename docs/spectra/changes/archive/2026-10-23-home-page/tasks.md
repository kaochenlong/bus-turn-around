<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
開工前提：`zhongshan-turnaround-ends` 已 archive（design「不碰路線頁的檔案，字體照路線頁的方式每頁自己載，apply 排在 zhongshan-turnaround-ends 之後」）。
-->

## 1. 站名與顯名聲明

- [x] 1.1 實作 Document title carries the site name：`config/locales/tw.yml` 的 `site.name` 是「折返點 TurnAround」、`en.yml` 是「TurnAround」，兩個檔都拿掉範本的 `hello`（grep 過，程式裡沒有用到）；`app/views/layouts/application.html.erb` 的 `<title>` 改成 `content_for(:title) || t("site.name")`，`application-name` 的 content 改成 `t("site.name")`。
  - 行為：沒有設 `content_for :title` 的頁面，title 與 `application-name` 都是「折返點 TurnAround」；路線頁其他輸出不變。
  - 驗證：新增 `spec/requests/site_layout_spec.rb`（`type: :request`），斷言 Scenario「Home page title」（`GET /` 的 `title` 文字與 `meta[name=application-name]` 的 content）與「Route page title」（9001 沒有任何 `route_days` 時 `GET /routes/9001` 回 200、title 是站名）。`bin/rubocop` 對新增的 spec。
- [x] 1.2 實作 Attribution footer on every page，套用 design「顯名聲明放 layout footer，兩頁都帶；footer 不帶 data-section」：用 `bin/rails g view_component:component Attribution --locale` 產生 `app/components/attribution_component.rb`、`.html.erb`、`.yml`，layout 在 `yield` 之後 render 它。[after: 1.1]
  - 行為：每一頁底部有 `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]`，裡面是 `docs/data-sources.md` 授權一節引文那三行原文、一行北捷出入口座標的顯名、一句「提供資料不代表該機關推薦、同意或核准本專案」（原文見 design 的文案一節）；footer 本身與裡面任何元素都沒有 `data-section`。
  - 驗證：`spec/requests/site_layout_spec.rb` 斷言 Scenario「Footer on the home page」（`GET /` 恰好一個這樣的 footer）與「Footer on a route page」（9001 沒有資料時 `GET /routes/9001` 回 200、恰好一個 footer、footer 內 `[data-section]` 為空）。三行原文是固定文案，照專案規則不寫文字斷言，做內容審查逐字對 `docs/data-sources.md`。`spec/requests/routes_spec.rb` 不改，區塊順序那個例子仍綠。

## 2. 路線清單

- [x] 2.1 實作 Route list 的查詢，套用 design「路線清單一次查詢取每條路線最新一天，日期格式沿用路線頁的 day_label」：新增 `app/models/home_page/route_list.rb` 的 `HomePage::RouteList`。[after: 1.2]
  - 行為：`#entries` 回傳 `[Entry(route_id:, route_day:)]`，順序等於 `RoutePage.route_ids`；`route_day` 是該路線 `day` 最大的 `RouteDay`，沒有列時是 nil；整個 `entries` 只對 `route_days` 發一次查詢（`DISTINCT ON (route_id)`，再照設定順序排）。不讀 `ends`。
  - 驗證：新增 `spec/models/home_page/route_list_spec.rb`（`type: :model`）斷言 Scenario「Entries in configuration order」（test 環境 15373 沒有列、9001 有 2026-10-19 與 2026-10-20 時，entries 是 15373 的 nil 接 9001 的 2026-10-20）與「Latest day of every route in one query」（兩條路線各建三天，訂閱 `sql.active_record` 數到對 `route_days` 的 SELECT 恰好一次）。`bin/rubocop`。
- [x] 2.2 實作 Route list 的卡片，套用 design「路線清單一次查詢取每條路線最新一天，日期格式沿用路線頁的 day_label」：`WEEKDAYS` 與 `day_label(day)` 從 `RouteCoverageComponent` 上提到 `ApplicationComponent`；用 `bin/rails g view_component:component RouteList --locale` 產生 `RouteListComponent.new(route_list:)`。[after: 2.1]
  - 行為：輸出 `section[data-section=routes]`，標題「有頁面的路線」，每條路線一個 `[data-route=<Id>]`。有資料的卡帶 `[data-latest-day=YYYY-MM-DD]`、整張包在 `a[href="/routes/<Id>"]` 裡，文字含路線名、Id、「起站－迄站」、「最新資料 YYYY-MM-DD（一）」；沒有資料的卡帶 `[data-no-data]`、只有 Id 與「還沒有資料」、裡面沒有 `a`。清單下一句固定文案「一條路線的定義在它自己的資料上核過，才會有頁面」。不出現趟次、百分位數或任何指標。
  - 驗證：新增 `spec/components/route_list_component_spec.rb`（`type: :component`）斷言 Example「entry of a route with data」（9001 的卡文字含 測試幹線、9001、甲站－戊站、2026-10-20（二），`href` 是 `/routes/9001`）與沒有資料的卡（`[data-no-data]`、沒有 `a`）。`spec/components/route_coverage_component_spec.rb` 不改仍綠。`bin/rubocop`。

## 3. 資料限制與資料來源

- [x] 3.1 實作 Data limitations on the home page，套用 design「DataLimitationsComponent 用 scope 選 items 或 home_items，路線頁那組不動」：`DataLimitationsComponent.new(scope: :route)`，`app/components/data_limitations_component.yml` 在 tw 與 en 各加 `home_items` 四條（原文見 design 的文案一節），`items` 一字不動。[after: 2.2]
  - 行為：`scope: :home` 列 `home_items` 四條，`scope: :route`（預設）列 `items`；其他值丟 `ArgumentError`；輸出都是 `section[data-section=limitations]` 加一個 `ul`。路線頁的 `app/views/routes/show.html.erb` 不改，仍用預設。
  - 驗證：新增 `spec/components/data_limitations_component_spec.rb`（`type: :component`）斷言 Scenario「Four items on the home page」（`:home` 恰好四個 `li`）與「Route page list untouched」（`:route` 的 `li` 數等於用 `YAML.load_file(path, aliases: true)` 讀同一個 `.yml` 的 `tw.items` 長度，且四條 home 的文字一條都不在裡面；sidecar 的翻譯不在全域 `I18n` 後端，所以直接讀檔），以及不接受的 scope 丟 `ArgumentError`。四條文案做內容審查對 `docs/spectra/LANGUAGE.md`「資料限制」。`bin/rubocop`。
- [x] 3.2 實作 Data sources block：用 `bin/rails g view_component:component DataSources --locale` 產生 `DataSourcesComponent.new`。[after: 3.1]
  - 行為：輸出 `section[data-section=sources]`，標題「資料從哪裡來」，內文說三支 feed（到離站、車上人數、GPS）、每 10 秒抓一次、全路網都收；恰好三個 `a[href]`，依序指向 `https://data.gov.tw/dataset/128710`、`https://data.gov.tw/dataset/175726`、`https://data.gov.tw/dataset/128428`，連結文字是資料集名稱；沒有 repo 或原始檔的連結。
  - 驗證：新增 `spec/components/data_sources_component_spec.rb`（`type: :component`）斷言 Scenario「Dataset links present」（`a` 的 `href` 陣列等於那三個網址）。內文是固定文案，做內容審查對 `docs/data-sources.md`。`bin/rubocop`。

## 4. 插圖

- [x] 4.1 建立場景頁與匯出，套用 design「插圖用 three.js 作圖、預先 render 成靜態圖片上線，不在執行期載 three.js」「場景頁放 tools/hero，用專案現有的 Vite 開，three 釘版本進 devDependencies」「匯出直接從 canvas 出 WebP，兩個鏡頭、固定尺寸」，服務 Hero picture：`yarn add -D three@0.186.1`；新增 `tools/hero/index.html`（一個 canvas、「匯出全景」「匯出直式」兩個按鈕、幾行自己的 CSS，不用 Tailwind）與 `tools/hero/scene.js`（`buildScene()`、`wideCamera()`、`tallCamera()`、`exportWebp(renderer, scene, camera, width, height, filename)`）；`.dockerignore` 加 `/tools/`。這一步先畫地面、道路、末站站牌與公車（slate-100 車身配 teal-700 腰線、slate-800 車窗、車門開著），人物下兩步再加。[after: 3.2]
  - 行為：`yarn vite tools/hero` 開頁面看到正交斜俯角的街區與停在末站的公車，背景透明；按「匯出全景」下載 2048×1152 的 WebP，按「匯出直式」下載 1170×1170 的 WebP。`app/frontend/entrypoints/application.js` 不 import `three`。
  - 驗證：人工開頁面確認場景與兩個下載；對下載的檔跑 `sips -g pixelWidth -g pixelHeight` 得到上述像素。`yarn build` 後 `grep -c three public/vite/.vite/manifest.json` 是 0。`git status --short` 只有 `package.json`、`yarn.lock`、`.dockerignore` 與新增的 `tools/`。
- [x] 4.2 加入站長、排班板與調度站的窗，套用 design「構圖與風格：一張圖講司機的休息，色票鎖在路線頁，不畫五官，通用公車」：畫面左側一面牆開一扇窗，窗內站長（方塊與圓柱拼的人形，slate-600 衣服，沒有五官）面對一面排班板，板上是格子狀色塊（slate-300 底、少數 amber-400 格），沒有任何可讀文字。[after: 4.1]
  - 行為：全景鏡頭裡左側那一組清楚可辨，直式鏡頭裡不入鏡；公車仍是畫面最大、最靠中央的物件。
  - 驗證：人工開 `yarn vite tools/hero` 兩個鏡頭各看一次，對照 design 構圖清單的第 1 與第 2 點；放大看排班板確認沒有文字。
- [x] 4.3 加入司機、站牌與等車的民眾，套用 design「構圖與風格：一張圖講司機的休息，色票鎖在路線頁，不畫五官，通用公車」：司機站在公車車門旁、靠著車（不在駕駛座）；右側一根站牌（amber-400 牌面）前兩到三個民眾，衣服 slate-600 與 teal-500 輪流；所有人形不畫五官；公車上沒有路線號碼、業者塗裝或機關標誌。[after: 4.2]
  - 行為：全景鏡頭由左到右是站長那組、公車與司機、站牌與民眾；直式鏡頭只框公車與司機。
  - 驗證：人工看兩個鏡頭對照 design 構圖清單的第 2 與第 3 點與色票；由使用者看過整張圖決定是否收斂到只剩公車與司機（design 風險「圖做出來讀起來像玩具」的退路）。
- [x] 4.4 由人操作：匯出並放進資產目錄，寫檔案守門 spec，服務 Hero picture 的 Scenario「Image files within budget」。步驟：`yarn vite tools/hero`，按「匯出全景」把檔存成 `app/assets/images/home-hero-wide.webp`，按「匯出直式」存成 `app/assets/images/home-hero-tall.webp`；`ls -l app/assets/images/` 記下大小；超過預算照 design「匯出直接從 canvas 出 WebP，兩個鏡頭、固定尺寸」的順序降品質、再降像素，重新匯出。apply 的代理人沒有瀏覽器可操作時，在這一步停下、把上述步驟交給使用者，不自行產生替代圖片。[after: 4.3]
  - 行為：兩個檔案存在，全景不超過 200 KB、直式不超過 120 KB；像素是 2048×1152 與 1170×1170（降級時是 1600×900 與 900×900）。
  - 驗證：新增 `spec/assets/home_hero_images_spec.rb`（純檔案檢查，不需要 Rails type）斷言兩個檔案存在、`File.size` 各在預算內；`sips -g pixelWidth -g pixelHeight` 核像素。

## 5. 首頁

- [x] 5.1 實作 Hero picture 的頁面部分與 Home page content and order 的 hero 區塊，套用 design「標題用網站今天答得出來的問題，「末站有廁所嗎」留給回報表單上線」：用 `bin/rails g view_component:component HomeHero --locale` 產生 `HomeHeroComponent.new`。[after: 4.4]
  - 行為：輸出 `section[data-section=hero]`：站名「折返點 TurnAround」、`h1`「折返點實際能休幾分鐘？」、一段說明（原文見 design 文案）、`picture`：`source[media="(max-width: 639px)"]` 的 srcset 是 `home-hero-tall.webp` 的資產路徑，`img` 的 src 是 `home-hero-wide.webp` 的資產路徑、`width="1024"`、`height="576"`、`fetchpriority="high"`、`alt` 是 design 文案那一句。沒有 canvas、沒有 script。
  - 驗證：新增 `spec/components/home_hero_component_spec.rb`（`type: :component`）斷言 Scenario「Picture element」（`source` 的 media 與 srcset 含 `home-hero-tall`、`img` 的 src 含 `home-hero-wide`、width、height、alt 非空）。標題與說明是固定文案，做內容審查對 design。`bin/rubocop`。
- [x] 5.2 實作 Home page content and order，套用 design「首頁不放指標、只放涵蓋，日期全從 route_days 讀」與「不碰路線頁的檔案，字體照路線頁的方式每頁自己載，apply 排在 zhongshan-turnaround-ends 之後」：`PagesController#home` 準備 `@route_list = HomePage::RouteList.new`；重寫 `app/views/pages/home.html.erb`（`content_for :head` 載 Barlow、Barlow Semi Condensed、Noto Sans TC，`main` 用 `font-route` 與 `max-w-5xl`，依序 render `HomeHeroComponent`、`RouteListComponent`、`DataLimitationsComponent.new(scope: :home)`、`DataSourcesComponent`）；`app/frontend/stylesheets/application.css` 刪掉 home 主題那一段（Fredoka、Baloo、railsred、railsdeep、九個 `--animate-*` 與 keyframes、`.pop`、`.ad-*`、`popin`），保留 `--font-route` 兩個變數。[after: 5.1]
  - 行為：`GET /` 回 200，`[data-section]` 依序是 hero、routes、limitations、sources；頁面沒有 Alpine 屬性、沒有頁面專屬的 script；文案裡沒有「每天更新」；路線卡的日期來自 `route_days`。
  - 驗證：重寫 `spec/requests/pages_spec.rb` 斷言 Scenario「Blocks in order」（`[data-section]` 陣列）、「Complete without JavaScript」（9001 有 2026-10-20 時，rack_test 拿到的 HTML 已含 `[data-route=9001][data-latest-day=2026-10-20]`、`picture`、四個 `li`、三個資料集連結）、「Entries in configuration order」（test 環境 15373 在前且 `[data-no-data]`、9001 在後且有連結）、Example「entry of a route with data」。`yarn build` 後 `public/vite/assets/` 的 CSS 裡 `grep -ci "fredoka\|railsred"` 是 0。`bin/dev` 開 `/` 在 1280 px 與 390 px 各看一次：桌機是全景圖、手機是直式圖與單欄。`bin/rubocop`。

## 6. 詞彙與收尾

- [x] 6.1 `docs/spectra/LANGUAGE.md` 交付物一節的最後加「首頁」與「顯名聲明」兩條，內容照 design 介面一節寫的定義、在程式碼裡叫什麼、邊界、不要用；不動其他任何條目（design「不碰路線頁的檔案，字體照路線頁的方式每頁自己載，apply 排在 zhongshan-turnaround-ends 之後」）。
  - 行為：兩條都是四行格式，跟檔案裡其他條目一致。
  - 驗證：內容審查對 design；`git diff docs/spectra/LANGUAGE.md` 只有新增行、沒有刪改行。
- [x] 6.2 真資料驗收與整套檢查，套用 design「首頁不放指標、只放涵蓋，日期全從 route_days 讀」：開發資料庫已有 15373 的 2026-10-19 到 10-21，不重跑 `derived:load`。[after: 5.2]
  - 行為：`bin/dev` 開 `/`，中山幹線那張卡顯示「中山幹線 15373」「天母－青年公園」（開發資料庫 `route_days` 裡 15373 最新一列的 `departure` 與 `destination`，2026-10-22 查過）與「最新資料 2026-10-21（三）」，整張連到 `/routes/15373`；頁上沒有任何趟次或百分位數；底部有顯名聲明；路線頁打開跟之前一樣，多了 footer 與站名的 title。
  - 驗證：`bin/ci` 全綠（RuboCop、bundler-audit、Brakeman、平行 RSpec、seeds）；人工核對上述三點。

## 7. 插圖改成執行期動畫

需求變更（2026-10-22）：1.1–6.2 完成後，使用者決定首頁插圖改成執行期 three.js 動畫，靜態圖留作備援。design「插圖在首頁執行期播一次動畫，靜態圖當備援」取代了「插圖用 three.js 作圖、預先 render 成靜態圖片上線，不在執行期載 three.js」。

下面的任務接手已完成任務裡被推翻的行為：

- 4.1：`application.js` 不 import `three`、manifest 裡沒有 three、three 只進 devDependencies。
- 5.1：沒有 canvas、沒有 script。
- 5.2：頁面沒有 Alpine 屬性、沒有頁面專屬的 script。

已完成任務的描述保持原樣，作為歷史。

- [x] 7.1 場景模組搬到 `app/frontend/hero` 並加上動畫時間軸，套用 design「場景模組放 app/frontend/hero，首頁與匯出頁共用，three 改為 dependency」：`tools/hero/scene.js` 搬成 `app/frontend/hero/scene.js`；`buildScene()` 另外回傳動畫部件（公車、前門門板、司機）；新增 `pose(parts, t)`，照 design「插圖在首頁執行期播一次動畫，靜態圖當備援」的時間軸擺姿勢，t 從 0 到 1，1 是現在的構圖。`exportWebp` 移到 `tools/hero/export.js`；`tools/hero/index.html` 改從新位置 import，匯出前擺 `pose(parts, 1)`，並接受 `?t=` 參數預覽任一時間點。[after: 6.2]
  - 行為：`yarn vite tools/hero` 照樣開得起來，兩個按鈕照樣下載 2048×1152 與 1170×1170 的 WebP。用終點姿勢匯出的圖，跟 commit 進去的兩張逐像素相同。`?t=0` 看得到公車還沒進站，`?t=0.65` 看得到門正在打開。
  - 驗證：用 headless Chrome 按兩個匯出按鈕，對 `app/assets/images/home-hero-*.webp` 跑 `magick compare -metric AE`，結果要是 0，不是 0 就修到 0（Scenario「Final frame matches the static image」；RSpec 環境跑不到 `tools/hero` 的 Vite 頁，所以用這個指令驗）。`sips -g pixelWidth -g pixelHeight` 核像素。`spec/assets/home_hero_images_spec.rb` 仍綠。`?t=0` 與 `?t=0.65` 截圖做視覺檢查。
- [x] 7.2 首頁播一次動畫並停在終點，實作 Hero picture 的動畫部分與 Home page content and order 的頁面專屬 script，套用 design「插圖在首頁執行期播一次動畫，靜態圖當備援」「插圖動畫用 Alpine 元件按需載入，Turbo 快取前還原成伺服器輸出」「執行期效能預算：pixel ratio 上限 2、陰影貼圖 2048、只在播放時重繪」。這一項只做會播動畫的那條路。[after: 7.1]
  - 做法：
    - `three` 從 devDependencies 移到 dependencies，仍釘 0.186.1。
    - 新增 `app/frontend/hero/runtime.js` 的 `start(section)`：插入帶 `data-turbo-temporary` 的 canvas；依寬度選鏡頭並寫進 `data-hero-shot`；照時間軸播一次，`data-hero` 依序設成 `playing`、`done`；播完停止 `requestAnimationFrame`；pixel ratio 上限 2、陰影貼圖 2048；提供 `dispose()`。
    - `application.js` 在 `Alpine.start()` 之前註冊 `Alpine.data("homeHero")`：設成 `loading`，動態 import runtime，再呼叫 `start`。
    - `HomeHeroComponent` 的區塊加 `x-data="homeHero"`、`data-hero="pending"`，`<picture>` 外面包一個保留比例的容器。
    - `application.css` 加 `loading`、`playing`、`done` 時藏靜態圖、canvas 疊在原位並淡入的規則。
  - 行為：允許動態、有 WebGL 時，打開 `/` 看到 canvas 取代靜態圖、播一次動畫，`data-hero` 停在 `done`，之後不再重繪。伺服器輸出仍然沒有 canvas、沒有 script。入口 chunk 不帶 three。
  - 驗證：
    - `spec/components/home_hero_component_spec.rb` 加一條：伺服器輸出的 `data-hero` 是 `pending`，並掛 `x-data="homeHero"`。
    - 新增 `spec/system/home_hero_spec.rb`（`type: :system`、`:js`），斷言 Scenario「Animation plays once and stops」：`data-hero` 走到 `done`、有一個 canvas、靜態圖的 `visibility` 是 hidden，`done` 之後不再排 `requestAnimationFrame`（測試在頁面腳本執行前包一層計數）。
    - `spec/requests/pages_spec.rb` 不改，仍綠。
    - `yarn build` 後，manifest 的入口 chunk 沒有 three，three 在入口的 `dynamicImports` 那個 chunk 裡。
    - `bin/rubocop`。
- [x] 7.3 先保留空位與退回靜態圖的各種情況，實作 Hero picture 的退路，套用 design「先保留插圖的空位再播，3 秒內沒有接手就顯示靜態圖」與「插圖動畫用 Alpine 元件按需載入，Turbo 快取前還原成伺服器輸出」。[after: 7.2]
  - 做法：
    - `application.css` 在 `@media (scripting: enabled) and (prefers-reduced-motion: no-preference)` 下，讓 `pending` 的靜態圖保留盒子、`visibility: hidden`，並在 3 秒後用 CSS 動畫顯示；`static` 顯示靜態圖。
    - `homeHero` 的 `init()` 遇到減少動態效果或沒有 WebGL 時，設成 `static`，不 import runtime；runtime 載入失敗時也設成 `static`。
    - `spec/support/system.rb` 註冊一個帶 `--disable-3d-apis` 的 headless Chrome driver。
  - 行為：
    - 減少動態效果：看到靜態圖、沒有 canvas、沒抓動畫 chunk。
    - 沒有 WebGL：看到靜態圖。
    - 動畫 chunk 被擋：看到靜態圖。
    - `application.js` 被擋：3 秒內靜態圖變可見。
    - 路線頁：不抓動畫 chunk，也不抓 three。
  - 驗證：`spec/system/home_hero_spec.rb` 斷言以下 Scenario，再跑 `bin/rubocop`。
    - 「Reduced motion keeps the static image」：用 CDP `Emulation.setEmulatedMedia` 模擬。
    - 「No WebGL keeps the static image」：用新註冊的 driver。
    - 「Animation that fails to load falls back」：用 CDP `Network.setBlockedURLs` 擋動畫 chunk。
    - 「Static image appears when no script takes over」：擋 `application.js`。
    - 「Route pages do not load the animation」：讀 `performance.getEntriesByType("resource")`。
- [x] 7.4 Turbo 換頁與視窗寬度，套用 design「插圖動畫用 Alpine 元件按需載入，Turbo 快取前還原成伺服器輸出」：`turbo:before-cache` 把 `data-hero` 還原成 `pending`；`destroy()` 呼叫 `dispose()`；`application.js` 在 `turbo:before-render`（不是 morph 時）對 `<body>` 呼叫 `Alpine.destroyTree`，Turbo 換頁時 `destroy()` 才會跑（Alpine 不處理沒標記的 `<body>` 被換掉）；視窗寬度跨過 640 px 時換鏡頭，播放中照常繼續，播完則重畫一格。[after: 7.3]
  - 行為：首頁 → 路線頁 → 上一頁，沒有殘留的空白 canvas，動畫重播到 `done`。`data-hero-shot` 隨寬度在 `tall` 與 `wide` 之間切換。
  - 驗證：`spec/system/home_hero_spec.rb` 斷言以下 Scenario，再跑 `bin/rubocop`。
    - 「Returning to the home page」：點路線卡、`page.go_back`，canvas 只有一個，而且走到 `done`。
    - 「Framing follows the viewport width」：視窗 500 寬時是 `tall`，放大到 1400 後是 `wide`。headless Chrome 視窗最小寬度是 500，仍小於 640。
- [x] 7.5 量執行期效能並寫回 design，套用 design「執行期效能預算：pixel ratio 上限 2、陰影貼圖 2048、只在播放時重繪」：量兩個數字。[after: 7.4]
  - 量法：
    - 首頁動畫 chunk 的 brotli 大小：量 `yarn build` 產出的實際檔案。
    - 播放期間的每格耗時：在開發機的 headless Chrome，用 CDP `Emulation.setCPUThrottlingRate` 開 4 倍節流後量。
  - 行為：design 那一節寫上量到的數字、量法與日期。超出預算時回報使用者，不自行放寬。
  - 驗證：內容審查 design 那一節；量測指令與輸出記在 apply 的回報裡。
- [x] 7.6 整套驗收，套用 design「插圖在首頁執行期播一次動畫，靜態圖當備援」：開發資料庫同 6.2，不重跑 `derived:load`。[after: 7.5]
  - 行為：
    - `bin/dev` 開 `/`，在 1280 與 390 px 各看一次動畫，定格要跟靜態圖一致。
    - 模擬減少動態效果時看到靜態圖。
    - 切到 `/routes/15373` 再按上一頁回來，動畫重播。
    - 路線頁其他部分不變。
  - 驗證：`bin/ci` 全綠（含 system specs）；人工核對上述幾點。
