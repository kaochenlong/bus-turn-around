## Context

根路徑 `/` 還是 Rails 範本的小火車頁（`app/views/pages/home.html.erb`），`PagesController#home` 是空的，`spec/requests/pages_spec.rb` 只驗 200。它用自己的一套字體與色（Fredoka、Baloo、railsred）與九組 keyframes，全在 `app/frontend/stylesheets/application.css` 的 home 那一段。路線頁用的是 Barlow 配 Noto Sans TC、slate 文字、teal 強調、等寬數字，字體由 `app/views/routes/show.html.erb` 的 `content_for :head` 從 Google Fonts 載。

layout `app/views/layouts/application.html.erb` 的 `<title>` 預設是 Website，`application-name` 也是 Website，沒有任何頁面設 `content_for :title`；`config/locales/tw.yml` 與 `en.yml` 只有範本的 `hello`，程式裡沒有用到。layout 與路線頁都沒有顯名聲明，而 `docs/data-sources.md` 寫明凡是用公運處這批檔案做出來的東西都要帶那三行，條款第三條未盡顯名義務視為自始未取得授權。

路線清單在 `config/route_page.yml` 的 `routes` 對應表（鍵是路線 Id，值只有兩端的性質，沒有路線名），`RoutePage.route_ids` 回傳鍵的陣列；test 環境是 15373 與 9001。路線名、起迄、最新一天都在衍生表 `route_days`。`RouteCoverageComponent#day_label` 用 `WEEKDAYS` 把日期印成「2026-10-19（一）」。`DataLimitationsComponent` 讀同層 `.yml` 的 `items`，目前六條，含捷運重疊與換休息試算的細節。

前端是手寫的 Vite 整合：`vite.config.ts` 的 `rollupOptions.input` 只有 `app/frontend/entrypoints/application.js`，`app/helpers/vite_helper.rb` 讀 `public/vite/.vite/manifest.json`。Vite 8.3.4 的設定檔是從 CLI 的 `[root]` 參數那個目錄找的（`loadConfigFromFile(configEnv, configFile, config.root, …)`），所以 `yarn vite tools/hero` 不會載入專案的 `vite.config.ts`。`three` 目前沒有安裝。圖片走 propshaft，`app/assets/images/` 已存在但是空的。Dockerfile 先 `yarn install --frozen-lockfile`、再 `COPY . .`，build 階段結尾 `rm -rf node_modules`；`.dockerignore` 目前沒有排除 `tools/`。

同時在飛的 change `zhongshan-turnaround-ends` 還有 3.3 與 4.1 沒做完：3.3 會改 `app/components/data_limitations_component.yml` 的 `items`，以及 `docs/spectra/LANGUAGE.md` 的「起站、末站、折返點、調度站」與「換休息試算」兩條；它已經改了 `app/views/routes/show.html.erb`、`app/controllers/routes_controller.rb`、`spec/requests/routes_spec.rb`。`spec/requests/routes_spec.rb` 的區塊順序例子是對整份文件收集 `[data-section]`。

需求變更（2026-10-22）：初版照「插圖用 three.js 作圖、預先 render 成靜態圖片上線，不在執行期載 three.js」做完 14 項、`bin/ci` 全綠。使用者看過首頁後，決定插圖改成執行期 three.js 動畫，靜態圖留作備援。這時的現況：

- 場景在 `tools/hero/scene.js`。
- 兩張 WebP 在 `app/assets/images/`。
- `HomeHeroComponent` 只輸出 `<picture>`。
- `three` 是 devDependency。
- 專案 `:js` system spec 的 driver（`selenium_chrome_headless`）實測有 WebGL2（ANGLE Metal）。

## Goals / Non-Goals

**Goals:**

- 第一次打開網站的人在一個畫面裡看到：這是什麼、有哪些路線、數字能信到哪、資料從哪來，並且點得進路線頁。
- 首頁與路線頁都帶顯名聲明與站名，補上授權義務與範本殘留。
- 伺服器輸出的首頁不靠 JS 就完整，手機上一個畫面開完。頁面專屬的 JS 只有插圖動畫，按需載入、播一次就停。
- 首頁跟路線頁是同一套字體與色。

**Non-Goals:**

- 月報、路線搜尋、車牌查詢、回報表單、共用頁首導覽：各自等有東西再開 change，不留空殼。
- 首頁放任何指標。
- 連到開源 repo、原始檔或 Parquet 釋出。
- 插圖的互動（拖曳旋轉、縮放、滑鼠視差）、循環播放，以及其他頁面的 3D。
- 換 favicon。
- 路線頁專屬的 `<title>`、把 Google Fonts 連結搬進 layout、路線頁的任何區塊與文案、`DataLimitationsComponent` 的 `items`。

## Decisions

### 插圖用 three.js 作圖、預先 render 成靜態圖片上線，不在執行期載 three.js

**已被取代**：由「插圖在首頁執行期播一次動畫，靜態圖當備援」取代（2026-10-22，初版 14 項做完後使用者決定）。仍然成立的部分：場景用 three.js 寫，從同一個場景匯出兩張 WebP，現在改當備援（見「匯出直接從 canvas 出 WebP，兩個鏡頭、固定尺寸」）。

原本的決定：場景在開發者的瀏覽器裡 render 一次、匯出圖片，網站只提供圖片。原本否決執行期的理由（人物模型、手機上的光影成本、bundle、Turbo 下 canvas 的處理、WebGL 備援、`prefers-reduced-motion`、headless Chrome 的 WebGL）由新決定逐項回答。原本量到的數字仍可參考：three.js 0.186.1 的兩個 build 檔在 jsDelivr 上 brotli 壓縮後是 90 KB 與 104 KB。

### 插圖在首頁執行期播一次動畫，靜態圖當備援

Supersedes：「插圖用 three.js 作圖、預先 render 成靜態圖片上線，不在執行期載 three.js」。

首頁在瀏覽器裡用 three.js 播一次動畫，播完定格在跟靜態圖相同的構圖並停止重繪；兩張 WebP 是備援。

| 情況 | 看到什麼 | 載不載 three.js |
| --- | --- | --- |
| 沒有 JS | 靜態圖 | 不載 |
| 有 JS、設定減少動態效果（`prefers-reduced-motion: reduce`） | 靜態圖 | 不載 |
| 有 JS、允許動態、有 WebGL | 先保留空位，canvas 淡入後播一次動畫，定格在跟靜態圖相同的構圖 | 只在首頁載 |
| 沒有 WebGL、動畫的 chunk 載入失敗 | 改顯示靜態圖 | 沒有 WebGL 時不載；載入失敗就退回 |
| JS 在元件啟動前出錯 | 3 秒後 CSS 自動顯示靜態圖 | — |

動畫時間軸是設計值，總長約 5.5 秒，apply 時可微調：

1. 0–3.0 秒：公車從地塊左緣開進來，沿近側車道減速停到末站。用 clipping plane 切在地塊邊緣，不會懸在透明背景上。
2. 3.0–3.8 秒：前門門板從關上轉到 62°。
3. 3.8–5.4 秒：司機從門口走到車旁、往後靠。

調度站、站牌與民眾不動。每次進首頁播一次，不循環。寬度小於 640 px 用直式鏡頭，否則用全景鏡頭，跟 `<picture>` 的切點一致。

理由：使用者看過初版靜態圖後，決定首頁要有動畫（2026-10-22）。原本否決執行期的理由逐項回答：

- 人物：仍是方塊拼的，不載 GLTF。
- 光影：用跟匯出相同的 Lambert 材質，加一盞投影的平行光，執行期陰影貼圖降到 2048（見「執行期效能預算：pixel ratio 上限 2、陰影貼圖 2048、只在播放時重繪」）。
- bundle：three 只進首頁按需載入的 chunk。
- Turbo 下 canvas 的生命週期：見「插圖動畫用 Alpine 元件按需載入，Turbo 快取前還原成伺服器輸出」。
- WebGL 與減少動態效果：都退回靜態圖。
- headless Chrome 的 WebGL：已實測專案的 `:js` driver 有 WebGL2。

定格畫面跟靜態圖相同，所以沒有 JS 的人和看動畫的人，最後看到的是同一張圖。

替代方案：

- 先顯示靜態圖、canvas 準備好再從頭播（否決：使用者不要「公車先消失再開進來」的倒帶）。
- 動畫從靜態圖那一格開始，只加不矛盾的小動作（否決：沒有公車開進末站那一段）。
- 循環播放或可拖曳旋轉（不在範圍內）。

### 場景頁放 tools/hero，用專案現有的 Vite 開，three 釘版本進 devDependencies

**已被取代**：由「場景模組放 app/frontend/hero，首頁與匯出頁共用，three 改為 dependency」取代（2026-10-22）。

仍然成立的部分：

- 匯出頁 `tools/hero/index.html` 用 `yarn vite tools/hero` 開。這個目錄沒有設定檔，所以不會吃到專案的 `base: "/vite/"` 與 Tailwind plugin。
- `/tools/` 在 `.dockerignore`，匯出頁不進映像檔。

改掉的部分：

- 場景程式碼不再放在 `tools/hero`。
- `three` 不再只是 devDependency。

### 場景模組放 app/frontend/hero，首頁與匯出頁共用，three 改為 dependency

Supersedes：「場景頁放 tools/hero，用專案現有的 Vite 開，three 釘版本進 devDependencies」。

`tools/hero/scene.js` 搬到 `app/frontend/hero/scene.js`。場景、鏡頭、色票、renderer 設定與動畫姿勢都在這裡：

- `buildScene()` 另外回傳動畫要動的部件：公車、前門門板、司機。
- `pose(parts, t)` 依 t（0 到 1）擺姿勢，`t = 1` 就是靜態圖的構圖。

匯出這邊：

- 匯出用的 `exportWebp` 留在 `tools/hero/export.js`。
- 匯出頁 `tools/hero/index.html` 從 `app/frontend/hero/scene.js` import，並用 `pose(parts, 1)` 匯出。
- 匯出頁照樣用 `yarn vite tools/hero` 開，沒有自己的設定檔；`/tools/` 仍排除在映像檔外。

`three` 釘 0.186.1，從 devDependencies 移到 dependencies。

搬完重新匯出兩張 WebP，用 `magick compare -metric AE` 跟 commit 進去的檔比，預期 0 個像素不同。不是 0，代表終點姿勢跟靜態圖對不上，要修到一致。

兩個 Vite（`bin/dev` 的與匯出頁的）共用 `node_modules/.vite`。兩種啟動順序都實測過：各自從記憶體提供預打包的相依，互不影響，只是每次啟動會多重新預打包一次。

理由：只留一份場景，靜態圖與動畫的終點才不會分岔。場景要進 app 的 bundle，`three` 就是執行期相依。

替代方案：

- 場景留在 `tools/hero`，app 從那裡 import（否決：`/tools/` 不進映像檔，build 會找不到）。
- 首頁與匯出頁各寫一份場景（否決：兩份會漂移）。

### 插圖動畫用 Alpine 元件按需載入，Turbo 快取前還原成伺服器輸出

`app/frontend/entrypoints/application.js` 在 `Alpine.start()` 之前註冊 `Alpine.data("homeHero", …)`；`HomeHeroComponent` 的區塊帶 `x-data="homeHero"` 與 `data-hero="pending"`。

元件的 `init()` 依序判斷：

1. 減少動態效果：設成 `static`。
2. 沒有 WebGL：設成 `static`。
3. 其他：設成 `loading`，`import("../hero/runtime.js")`，失敗就設成 `static`。

`runtime.js` 的處理：

- 把 canvas 插進 hero。canvas 帶 `data-turbo-temporary`，Turbo 快取前會自動移除。
- 播放時設成 `playing`，結束設成 `done`，並停止 `requestAnimationFrame`。
- 視窗寬度跨過 640 px 時切換鏡頭，目前用哪個鏡頭寫在 `data-hero-shot`（`wide` 或 `tall`）。

元件另外處理兩件事：

- 在 `turbo:before-cache` 把 `data-hero` 還原成 `pending`，快照裡就只剩伺服器輸出的樣子。
- `destroy()` 停止動畫，釋放 renderer、幾何與材質。

Turbo 換頁時，`destroy()` 要靠 `application.js` 才會跑：在 `turbo:before-render`（不是 morph 的時候）對整個 `<body>` 呼叫 `Alpine.destroyTree`，頁面上每個 Alpine 元件的 `destroy()` 與清理都會執行。這段影響所有 Alpine 元件：`load_chart_component`、`buffer_trade_component` 離開路線頁時也會被清理，它們沒有寫 `destroy()`，畫面上看不出差別。

查證過的事實：

- `alpine-turbo-drive-adapter` 在 `turbo:before-cache` 不會銷毀 Alpine 元件，快照會複製當下的 DOM。所以 canvas 要設成 temporary、狀態要還原。
- Alpine 3.17.4 處理被移除的節點時，只看那個節點本身是不是它初始化過的元素（有 `_x_marker`），是的話才清理並呼叫 `destroy()`。Turbo 換頁是把整個 `<body>` 換掉，`<body>` 不是 Alpine 初始化的元素，所以裡面的元件不會被銷毀。這條在 apply 7.4 時由測試與 Alpine 原始碼查證（2026-10-23），所以需要上面那段橋接。
- Turbo 8.0.23 支援 `data-turbo-temporary`。
- `config/initializers/content_security_policy.rb` 沒有啟用的政策，動態 chunk 不受限。

理由：專案的頁面互動用 Alpine（沒有 Stimulus），`load_chart_component` 與 `buffer_trade_component` 都是這樣做。動態 import 讓 three 只在首頁出現，不用改 `vite_helper` 或 `rollupOptions.input`。

替代方案：

- 純 JS 模組監聽 `turbo:load`（否決：等於重做一遍 Alpine 已經有的生命週期）。
- 第二個 Vite entrypoint 走 `vite_helper`（否決：要改 helper 的 dev 分支與 `rollupOptions.input`，而動態 import 就能拆出 chunk）。

### 先保留插圖的空位再播，3 秒內沒有接手就顯示靜態圖

靜態圖是動畫的最後一格。先把它畫出來再從頭播，公車會消失再開進來。所以有 JS 又允許動態時，一開始就不顯示靜態圖，只保留它的空間。

`app/frontend/stylesheets/application.css` 的規則：

- 在 `@media (scripting: enabled) and (prefers-reduced-motion: no-preference)` 下，`[data-hero=pending]` 的 `<picture>` 用 `visibility: hidden` 藏起來，盒子保留，版面不會跳；同時掛一個延遲 3 秒（設計值）、把它改回可見的 CSS 動畫，當作保險。
- `loading`、`playing`、`done` 時藏靜態圖。
- `static` 時顯示靜態圖。
- canvas 淡入。

沒有 JS 時，`scripting` 這個條件不成立，靜態圖照常顯示。

理由：這是使用者選的銜接方式（2026-10-22）。保留盒子，避免版面位移；JS 在元件啟動前就出錯時，3 秒後 CSS 會自己把靜態圖顯示出來，不會留下一塊永久的空白。

替代方案：

- 先顯示靜態圖再倒帶重播（否決，理由同上）。
- 用 JS 計時器做保險（否決：JS 本身壞掉時，計時器也不會跑）。

### 執行期效能預算：pixel ratio 上限 2、陰影貼圖 2048、只在播放時重繪

執行期的做法：

- pixel ratio 上限是 2。
- 陰影貼圖用 2048，匯出仍用 4096。
- 只在動畫播放期間跑 `requestAnimationFrame`，定格後不再重繪；視窗大小改變時只重畫一格。

預算是估計值，不是量到的，由任務實測確認：

- 首頁動態載入的 chunk 用 brotli 壓縮後不超過 200 KB。估計依據：three.js 0.186.1 的兩個 build 檔在 jsDelivr 上 brotli 後是 90 KB 與 104 KB（量到的），tree-shaking 後應該更小。
- 播放期間每格不超過 16 ms。量法：開發機的 headless Chrome，開 4 倍 CPU 節流。

量到的數字寫回這一節。超出預算時回報，不自己放寬。

量到的數字（2026-10-23，apply 7.5）：

- 首頁動畫的 chunk（three、場景、runtime 打成一個檔）：未壓縮 540,011 bytes，brotli（q11）110,374 bytes，gzip（-9）133,809 bytes。在 200 KB 的預算內。上線時由 Thruster 壓縮，實際傳輸的格式看它的設定。
- 入口 chunk：brotli 40,694 bytes；加入 Alpine 元件與換頁橋接後，未壓縮多不到 1 KB。
- 每格耗時。量法：開發機（Apple M1 Max）的 headless Chrome，用 CDP 開 4 倍 CPU 節流；在頁面腳本執行前包住 `requestAnimationFrame`，量每次回呼的執行時間，不計前三次（頁面上 Turbo 等程式也會用）。
  - 桌機寬 1400 px、DPR 1，canvas 992×558：324 格，中位數 2.4 ms、p95 3.2 ms、最大 7.6 ms。
  - 模擬手機寬 390 px、DPR 3（壓到 2），canvas 716×716：326 格，中位數 1.8 ms、p95 2.4 ms、最大 11.0 ms。
  - 兩種都在每格 16 ms 的預算內。
- 沒量到的部分：CPU 節流不會拖慢 GPU，開發機的 GPU 也比手機快得多，所以上面是主執行緒那一份，不含 GPU 的繪製時間。實機上的耗時還沒量，仍是未驗證。

理由：初版擔心的是「執行期在司機的手機上付不起」，這次要用量到的數字回答。

替代方案：不設預算，上線後再看（否決，理由同上）。

### 匯出直接從 canvas 出 WebP，兩個鏡頭、固定尺寸

場景頁有兩個按鈕，各把 renderer 設成固定尺寸、用對應的鏡頭 render 一次，然後 `canvas.toBlob(blob => 下載, "image/webp", 0.85)` 直接存成 WebP，不經過 PNG 與離線轉檔。

| 鏡頭 | 匯出像素 | 頁面上顯示 | 說明 |
| --- | --- | --- | --- |
| 全景（桌機） | 2048×1152 | 最寬 1024 CSS px，2x | 設計目標 |
| 直式（手機） | 1170×1170 | 約 390 CSS px，3x | 設計目標 |

檔案大小預算：全景不超過 200 KB、直式不超過 120 KB。兩個數字是估計，不是量到的；確認的量測是匯出後 `ls -l` 的檔案大小。超過預算時依序：品質降到 0.75、再把匯出像素降一級（全景 1600×900、直式 900×900），直到進預算為止，預算本身不放寬。

替代方案：匯出 PNG 再用 cwebp 或 vips 轉（否決：要多裝工具，`canvas.toBlob` 在 Chrome 直接出 WebP）；AVIF（否決：canvas 不能編碼 AVIF）。

### 構圖與風格：一張圖講司機的休息，色票鎖在路線頁，不畫五官，通用公車

正交相機、固定斜俯角，從斜上方看一塊切下來的街區；沒有 OrbitControls、沒有滑鼠視差。一盞平行光加環境光，材質平塗（`MeshLambertMaterial`），背景透明。

構圖，由左到右：

1. 左：調度站的窗，站長面對一面排班板。排班板是一格一格的色塊，沒有可讀的字。
2. 中：末站。公車停著、車門開，司機站在車旁休息。這是焦點，占畫面最大。
3. 右：一根站牌，兩三個民眾在等車。

直式鏡頭只框中間那一組（公車與司機），全景三組都在。

色票鎖在路線頁那套（Tailwind v4 的近似 hex）：地面 slate-100 `#f1f5f9`、道路 slate-300 `#cbd5e1`、公車車身 slate-100 配車窗下一條 teal-700 `#0f766e` 腰線、車窗與深色部件 slate-800 `#1e293b`、人物衣服 slate-600 `#475569` 與 teal-500 `#14b8a6` 兩色輪流、唯一的強調色 amber-400 `#fbbf24` 只用在站牌與排班板的少數格子。人物是方塊與圓柱拼的，不畫五官。公車是通用車：沒有業者塗裝、沒有路線號碼、沒有機關標誌，`docs/data-sources.md` 的「不得暗示機關推薦」在圖上一樣成立。車身用白色配一條腰線、不用整台 teal：臺北聯營公車沒有統一塗裝，各業者有自己的標準塗裝，初版整台深 teal 讀起來不像臺北的公車。

理由：README「誰受益」與 `docs/background.md`「瓶頸是駕駛，不是車」點名的就是這組人，但畫成現在小火車那種調性，公運處、審議會、記者會讀成遊戲。收斂的色票與不畫五官是把它壓回「插畫」而不是「玩具」的兩個最便宜的手段。

替代方案：只畫公車與末站（保留為退路：圖做出來讀起來像玩具時，砍到只剩公車與司機）；抽象粒子（否決：跟公車或折返無關）。

### 首頁不放指標、只放涵蓋，日期全從 route_days 讀

路線卡只有路線名、Id、起迄、最新資料日；沒有趟次、百分位數、達成率。文案不寫「每天更新」。

理由：`route-page-charts` 的決策「不會出現第二套定義」，`spec/models/route_page/card_consistency_spec.rb` 就是為了守住只有一套數字；數字只住在路線頁，旁邊才有定義與資料限制。`derived:load` 目前手動執行、沒有每晚排程（`docs/spectra/LANGUAGE.md` 衍生表那條），寫了「每天更新」就是說謊；從資料庫讀日期，頁面永遠只說它真的知道的事。

替代方案：卡上放兩個醒目數字（否決，理由如上）。

### 路線清單一次查詢取每條路線最新一天，日期格式沿用路線頁的 day_label

`HomePage::RouteList#entries` 用一次 `DISTINCT ON (route_id)` 查詢取每條設定路線最新的 `route_days` 列，再照 `RoutePage.route_ids` 的順序組成 entries；沒有列的路線 `route_day` 是 nil。`RouteCoverageComponent#day_label` 與 `WEEKDAYS` 上提到 `ApplicationComponent`，路線卡用同一個方法印「2026-10-20（二）」。

理由：每條路線各查一次不是關聯的 N+1，test 環境的 Bullet 抓不到，路線一多就慢；一次查詢加 spec 數查詢次數，行為鎖住。日期格式沿用，首頁與路線頁的星期寫法不會分岔；`route_coverage_component.rb` 不在在飛的 change 裡，上提安全。

替代方案：每條路線 `RouteDay.where(route_id:).order(day: :desc).first`（否決：N+1）；在設定檔加路線名（否決：路線名已經在 `route_days`，多一份會分歧）。

### 顯名聲明放 layout footer，兩頁都帶；footer 不帶 data-section

`AttributionComponent` 在 layout 的 `yield` 之後 render，所以首頁與路線頁都有。內容：`docs/data-sources.md` 授權一節那三行原文一字不改、一行北捷出入口座標的顯名（機關、資料集、同一授權）、一句「提供資料不代表該機關推薦、同意或核准本專案」。footer 的標記是 `data-attribution` 與 `data-license="OGDL-Taiwan-1.0"`，不用 `data-section`。

理由：授權義務對每一頁成立，放 layout 一次解決，之後新頁面不可能漏。`spec/requests/routes_spec.rb` 的區塊順序例子是對整份文件收集 `[data-section]`，footer 帶了這個屬性會讓在飛的 change 那條測試壞掉。固定文案照專案規則不寫文字斷言，測的是元素在不在。

替代方案：只放首頁（否決：路線頁也是用這批資料做出來的東西，而且它是被引用的那一頁）。

### 標題用網站今天答得出來的問題，「末站有廁所嗎」留給回報表單上線

首頁 H1 是「折返點實際能休幾分鐘？」。

理由：路線頁的兩張圖各用一句白話的問題當標題（`route-page-charts` 的提案），首頁沿用同一個語氣。「末站有廁所嗎」在 `docs/decisions.md` 第 9 條只是副標候選，折返點設施盤點與司機回報表單都還沒有，網站今天答不出這個問題，當標題會變成承諾。等回報表單上線再把它接上。

替代方案：「末站有廁所嗎？」當 H1（否決，理由如上，這是品味，使用者可以推翻）。

### DataLimitationsComponent 用 scope 選 items 或 home_items，路線頁那組不動

`DataLimitationsComponent.new(scope: :route)` 預設讀 `items`，`scope: :home` 讀同一個 `.yml` 新加的 `home_title` 與 `home_items`，標題用文案一節的「這些數字能信到哪」，四條照 `docs/spectra/LANGUAGE.md`「資料限制」那條寫。元件輸出的 `section[data-section=limitations]` 兩種 scope 相同。

理由：在飛的 change 3.3 要改 `items` 的內容，這個 change 只加新的鍵，兩邊不會改到同一行；一份 `.yml` 兩組文案，來源仍只有一個檔。路線頁那六條含捷運重疊與試算的細節，首頁沒有那些區塊，列了反而沒有對象。

替代方案：首頁另開一個元件（否決：同一件事兩個元件）；首頁直接沿用六條（否決：對象不在頁面上）。

### 不碰路線頁的檔案，字體照路線頁的方式每頁自己載，apply 排在 zhongshan-turnaround-ends 之後

這個 change 不改 `app/views/routes/show.html.erb`、`app/controllers/routes_controller.rb`、`spec/requests/routes_spec.rb`；首頁用自己的 `content_for :head` 載 Barlow 與 Noto Sans TC，跟路線頁一樣各載各的；路線頁的 `<title>` 維持站名。LANGUAGE.md 只在交付物一節的最後加「首頁」與「顯名聲明」兩條。apply 等 `zhongshan-turnaround-ends` archive 之後才開始。

理由：討論時曾建議把 Google Fonts 連結搬進 layout，那要動 `show.html.erb`，這個檔在飛的 change 正在改；兩個 change 同時改同一個檔，衝突的成本高過一條重複的 `<link>`。搬進 layout 與路線頁專屬的 `<title>` 等那個 change 收掉之後另開一條小 change。

替代方案：現在就搬（否決，理由如上）。

## Implementation Contract

**看得到的行為**

- `GET /` 回 200，由上到下是 `section[data-section=hero]`、`section[data-section=routes]`、`section[data-section=limitations]`、`section[data-section=sources]`，然後是 layout 的 `footer[data-attribution]`。伺服器輸出的整頁不靠 JS 就完整；頁面專屬的 script 只有插圖動畫，只在首頁按需載入。
- 路線清單照 `RoutePage.route_ids` 的順序。有資料的路線是一張整張可點的卡：路線名、Id、「起站－迄站」、「最新資料 2026-10-21（三）」，連到 `/routes/<Id>`；沒有資料的卡只有 Id 與「還沒有資料」，不是連結。
- 首頁與路線頁的 `<title>` 與 `application-name` 都是「折返點 TurnAround」；兩頁底部都有顯名聲明 footer。路線頁其他部分跟改之前一模一樣。
- 手機寬度看到直式的插圖與單欄；桌機看到全景插圖，內容欄最寬跟路線頁一樣（`max-w-5xl`）。
- 插圖動畫的各種情況：
  - 有 JS、允許動態、有 WebGL：先保留空位，canvas 淡入後播一次動畫（公車開進末站停下 → 門打開 → 司機下車），定格在跟靜態圖相同的構圖並停止重繪。
  - 減少動態效果、沒有 WebGL、動畫載入失敗：顯示靜態圖。
  - JS 在元件啟動前出錯：3 秒後顯示靜態圖。
  - 路線頁不載入動畫的 chunk。

**介面**

- `HomePage::RouteList.new` 的 `#entries` 回傳 `[Entry(route_id:, route_day:)]`，依 `RoutePage.route_ids` 的順序；`route_day` 是該路線最新的 `RouteDay`，沒有時是 nil。整個 `entries` 只對 `route_days` 發一次查詢。
- `ApplicationComponent` 提供 `WEEKDAYS` 與 `day_label(day)`，輸出「YYYY-MM-DD（一）」；`RouteCoverageComponent` 改用繼承來的，行為不變。
- `RouteListComponent.new(route_list:)` 輸出 `section[data-section=routes]`；每條路線一個 `[data-route=<Id>]`，有資料的帶 `[data-latest-day=YYYY-MM-DD]` 並包在 `a[href="/routes/<Id>"]` 裡，沒有資料的帶 `[data-no-data]` 且裡面沒有 `a`。
- `HomeHeroComponent.new` 輸出 `section[data-section=hero]`，含 `h1`、一段說明、`picture`：`source[media="(max-width: 639px)"]` 的 srcset 是 `home-hero-tall.webp` 的資產路徑，`img` 的 src 是 `home-hero-wide.webp` 的資產路徑、`width="1024"`、`height="576"`、`alt` 非空、`fetchpriority="high"`。區塊另外帶 `x-data="homeHero"` 與 `data-hero="pending"`；`<picture>` 外面包一個保留比例的容器；伺服器輸出沒有 canvas，也沒有 script。
- `DataLimitationsComponent.new(scope: :route)`：`scope` 只接受 `:route` 與 `:home`，其他值丟 `ArgumentError`；`:route` 讀 `title` 與 `items`，`:home` 讀 `home_title` 與 `home_items`。輸出仍是 `section[data-section=limitations]` 與一個 `ul`。
- `DataSourcesComponent.new` 輸出 `section[data-section=sources]`，三個 `a[href]` 分別指向 `https://data.gov.tw/dataset/128710`、`https://data.gov.tw/dataset/175726`、`https://data.gov.tw/dataset/128428`，沒有第四個連結。
- `AttributionComponent.new` 輸出 `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]`，裡面沒有任何 `data-section`。
- layout：`<title><%= content_for(:title) || t("site.name") %></title>`，`application-name` 的 content 是 `t("site.name")`；`config/locales/tw.yml` 的 `site.name` 是「折返點 TurnAround」，`en.yml` 是「TurnAround」；範本的 `hello` 拿掉。
- `PagesController#home` 準備 `@route_list = HomePage::RouteList.new`；`app/views/pages/home.html.erb` 用 `content_for :head` 載 Barlow、Barlow Semi Condensed、Noto Sans TC，`main` 用 `font-route`、`max-w-5xl`，依序 render 四個元件。
- `app/frontend/stylesheets/application.css`：刪掉 home 主題那一整段（`--font-fredoka`、`--font-baloo`、`--color-railsred`、`--color-railsdeep`、九個 `--animate-*` 與 keyframes、`.pop`、`.ad-*`、`popin`），保留 `--font-route` 與 `--font-route-figure`。
- `app/frontend/hero/scene.js` 提供：
  - `buildScene()`：回傳 scene、三組物件與動畫部件 `parts`。
  - `pose(parts, t)`：t 從 0 到 1，1 是靜態圖的構圖。
  - `wideCamera()`、`tallCamera()`、`createRenderer(canvas, options)`、`renderFrame(…)`。
- `app/frontend/hero/runtime.js` 提供 `start(section)`，回傳有 `dispose()` 的物件。它負責插入帶 `data-turbo-temporary` 的 canvas、依寬度選鏡頭（寫在 `data-hero-shot`）、播一次並把 `data-hero` 設成 `playing`、`done`。
- `tools/hero/index.html`：一個 canvas、兩個按鈕「匯出全景」「匯出直式」，從 `app/frontend/hero/scene.js` import；`tools/hero/export.js` 提供 `exportWebp(renderer, scene, camera, width, height, filename)`。`yarn vite tools/hero` 開頁面；`bin/dev` 同時在跑時，Vite 會自己挑下一個 port。
- `app/frontend/entrypoints/application.js` 在 `Alpine.start()` 之前註冊 `Alpine.data("homeHero", …)`：
  - `init()` 依序判斷減少動態效果、WebGL，再動態 import `../hero/runtime.js`。
  - `turbo:before-cache` 時把 `data-hero` 還原成 `pending`。
  - `destroy()` 呼叫 `dispose()`。
  - `turbo:before-render`（不是 morph）時呼叫 `Alpine.destroyTree(document.body)`，Turbo 換頁時元件的 `destroy()` 才會跑。
- `app/frontend/stylesheets/application.css` 依 `data-hero` 決定顯示靜態圖還是 canvas；`pending` 在 `scripting: enabled` 且允許動態時藏靜態圖，3 秒後自動顯示。
- 圖片：`app/assets/images/home-hero-wide.webp`（2048×1152）、`app/assets/images/home-hero-tall.webp`（1170×1170）。
- `.dockerignore` 多一行 `/tools/`；`package.json` 的 dependencies 有 `three`（釘 0.186.1），`yarn.lock` 跟著更新。
- `docs/spectra/LANGUAGE.md` 交付物一節最後加兩條：「首頁」（定義：根路徑那一頁，說這是什麼、列有路線頁的路線與各自最新資料日、數字能信到哪、資料從哪來；在程式碼裡：`pages#home`、`HomePage::RouteList`；邊界：有設定沒資料的路線照列、標還沒有資料，只放涵蓋不放指標；不要用：landing page、入口頁、dashboard）與「顯名聲明」（定義：政府資料開放授權條款要求的標示，原文在 `docs/data-sources.md`；在程式碼裡：layout 的 `AttributionComponent`；邊界：每一頁、每份釋出檔都要有；不要用：版權聲明、免責聲明、credits）。

**文案（固定內容，apply 不自行發明）**

- 站名：折返點 TurnAround
- H1：折返點實際能休幾分鐘？
- 說明：台北公車逐路線量兩個數字：折返點實際能休幾分鐘、與捷運重疊的路段實際載多少人。給駕駛、站長、公運處，和任何要引用的人。
- 插圖 alt：公車停在末站，司機站在車旁休息；一側是調度站裡看排班板的站長，另一側是站牌前等車的民眾。
- 路線清單標題：有頁面的路線。卡片：「最新資料 YYYY-MM-DD（一）」；沒有資料：「還沒有資料」。清單下一句：一條路線的定義在它自己的資料上核過，才會有頁面。
- 資料限制標題：這些數字能信到哪。四條：車不等於人：資料認的是車牌，不是駕駛，折返停留是駕駛休息的上限。／車上人數是票證推出來的值，不是點人頭，準確度看下車刷卡率。／每 10 秒抓一次，一定會漏站。／跨小時檔的事件可能重複，分析前會再去重一次。
- 資料來源標題：資料從哪裡來。內文：臺北市公共運輸處的公車即時開放資料，三支 feed：到離站、車上人數、GPS，每 10 秒抓一次，全路網都收。三個連結的文字用資料集名稱：定時車機資訊、公車車上擁擠度、捷運車站出入口座標。
- 顯名聲明：`docs/data-sources.md` 授權一節引文那三行原文；加一行「臺北大眾捷運股份有限公司 捷運車站出入口座標（data.gov.tw/dataset/128428），依政府資料開放授權條款第 1 版釋出」；加一句「提供資料不代表該機關推薦、同意或核准本專案」。
- en 的 `.yml` 給對應英文，照既有元件的做法；唯一例外是顯名聲明那三行原文與北捷那一行，`tw` 與 `en` 一模一樣，不翻譯，因為授權條款要求的是那段原文。

**錯誤與邊界**

- 設定裡有、`route_days` 裡沒有的路線：卡片照列、標「還沒有資料」、不是連結。
- `route_page.yml` 的 `ends` 缺漏：那是路線頁的事，`HomePage::RouteList` 只讀 `RoutePage.route_ids`，不解析 `ends`。
- 圖片不存在：`spec/assets/home_hero_images_spec.rb` 失敗；不依賴 propshaft 對缺檔的行為。
- 沒有 WebGL、動畫 chunk 載入失敗：`data-hero` 設成 `static`，顯示靜態圖。
- JS 在元件啟動前出錯：`data-hero` 停在 `pending`，CSS 3 秒後顯示靜態圖。
- 從首頁換到別頁再按上一頁：快照裡沒有 canvas、`data-hero` 是 `pending`，元件重新初始化並重播。
- 播放中視窗寬度跨過 640 px：換鏡頭繼續播；播完後才跨過，則重畫一格。
- 沒有新的網址參數，首頁不接受任何參數也不回 400。

**驗證**

- `spec/requests/pages_spec.rb`：區塊順序、路線卡的順序與內容、沒有資料的卡、`picture` 的屬性、四條資料限制、三個資料集連結、title。
- `spec/requests/site_layout_spec.rb`：首頁與沒有資料的 `/routes/9001` 都有 footer、title 與 `application-name`；footer 內沒有 `data-section`。
- `spec/models/home_page/route_list_spec.rb`：順序、nil、最新一天、只有一次對 `route_days` 的查詢（訂閱 `sql.active_record` 數 SQL）。
- `spec/components/route_list_component_spec.rb`、`spec/components/data_limitations_component_spec.rb`、`spec/components/data_sources_component_spec.rb`、`spec/components/home_hero_component_spec.rb`。
- `spec/assets/home_hero_images_spec.rb`：兩個檔案存在且在預算內。
- `spec/components/route_coverage_component_spec.rb` 與整套路線頁測試不改仍綠；`bin/rubocop` 對新增與修改的 Ruby 檔；`bin/ci`。
- `yarn build` 後，manifest 裡 three 只出現在入口動態載入的 chunk，入口 chunk 本身不帶 three；build 出的 CSS 裡沒有 `Fredoka`、`railsred`。
- `spec/system/home_hero_spec.rb`（`:js`）：
  - 允許動態：`data-hero` 走到 `done`、有 canvas、靜態圖藏起來。
  - 模擬減少動態效果：`static`、沒有 canvas、沒抓動畫 chunk。
  - 不支援 WebGL 的 driver：`static`。
  - 擋掉動畫 chunk：`static`。
  - 擋掉 `application.js`：3 秒後靜態圖可見。
  - 路線頁：沒抓動畫 chunk。
  - 首頁 → 路線頁 → 上一頁：沒有殘留 canvas，並重播到 `done`。
  - 視窗寬度跨過 640：`data-hero-shot` 跟著換。
- 場景搬家後重新匯出的兩張 WebP，跟 commit 進去的逐像素相同（`magick compare -metric AE` 是 0）。
- 效能：量首頁動畫 chunk 的 brotli 大小與播放期間的每格耗時，寫回「執行期效能預算：pixel ratio 上限 2、陰影貼圖 2048、只在播放時重繪」。
- `bin/dev` 開 `/`：桌機 1280 px 與手機 390 px 各看一次；中山幹線那張卡顯示「天母－青年公園」（開發資料庫 `route_days` 裡 15373 最新一列的 `departure` 與 `destination`，2026-10-22 查過：存的日子是 2026-10-19 到 10-21）與「最新資料 2026-10-21（三）」。

**範圍**

- 範圍內：`/` 的內容、layout 的 title 與 footer、首頁插圖的執行期動畫（`app/frontend/hero/`、Alpine 元件、CSS 狀態）、`tools/hero/` 與兩張圖、`DataLimitationsComponent` 的 scope、`ApplicationComponent#day_label`、home 主題 CSS 的移除、locale 的站名、`.dockerignore`、LANGUAGE.md 兩條。
- 範圍外：路線頁的任何檔案與文案、指標定義、favicon、月報、搜尋、車牌查詢、回報表單、導覽、插圖互動與循環播放、其他頁面的 3D。

## Risks / Trade-offs

- [跟 `zhongshan-turnaround-ends` 改到同一個檔] → 只在 `data_limitations_component.yml` 加 `home_title` 與 `home_items`、只在 LANGUAGE.md 交付物一節末尾加條目、不碰那三個路線頁檔案；apply 排在它 archive 之後。
- [圖做出來讀起來像玩具] → 色票、不畫五官、通用公車三條守則；匯出前由使用者看過；仍不行就砍到只剩公車與司機那一組，兩個鏡頭都重出。
- [匯出的檔案超過預算] → 品質 0.85 降到 0.75，再降一級像素；預算不放寬。
- [匯出與放檔是人操作的步驟，apply 會停在那裡] → 任務裡寫清楚步驟與目標路徑，後面的任務標明等它。
- [路線多了之後清單變長] → 這次只有一條，清單只放涵蓋；搜尋留給之後的 change。
- [`three` 改成 dependency] → Docker 的 `yarn install` 本來就在 build 階段裝全部相依，build 完 `rm -rf node_modules`；映像檔只多首頁動畫打包好的 chunk。
- [手機上動畫卡頓或耗電] → pixel ratio 上限 2、陰影貼圖 2048、只在播放期間重繪；量到的數字超出預算就回報。
- [載入 three.js 那段時間，插圖位置是空白] → 保留盒子，版面不跳；動畫 chunk 只在首頁抓；另有 3 秒保險。
- [動畫終點跟靜態圖漂移] → 只有一份場景模組，終點姿勢 `pose(parts, 1)` 也是匯出用的姿勢；搬家後做逐像素比對。
- [Turbo 快取或換頁留下空白 canvas、renderer 沒釋放] → canvas 帶 `data-turbo-temporary`、`turbo:before-cache` 還原狀態、`destroy()` 釋放；system spec 走一次上一頁，並檢查舊 canvas 的 WebGL context 已經釋放。
- [換頁前銷毀 Alpine 元件會碰到其他頁面的元件] → 頁面本來就要被換掉，清理只移除監聽與 effect；目前另外兩個元件沒有 `destroy()`，畫面不變。morph 換頁照舊由 adapter 處理。
- [瀏覽器不支援 `@media (scripting)`] → 整條規則不成立，靜態圖先照常顯示；元件接手後，再依 `data-hero` 把它藏起來。最差的情況是先看到靜態圖、再倒帶。
- [Tailwind 的 `@source` 掃不到 `tools/`] → 場景頁不用 Tailwind，自己寫幾行 CSS，不受影響。
