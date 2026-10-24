## Why

這個 change 不直接服務三樣交付物，改的是網站本身；其中 404 頁跟第一樣有關：路線健檢卡在網站上的路線頁。路線清單設定裡沒有的路線 Id，`/routes/<Id>` 現在回 404，但頁面是空白的（`RoutesController#show` 用 `head :not_found`）。`route-251-pages` 的決定「每條路線各自驗收，沒過就單獨拿掉」說明路線會從設定裡被拿掉，到時候舊連結會落到這個空白頁。網站上不存在的網址，正式站回的則是 Rails 預設的英文 404 頁。

另外三件是給好奇的人的小東西，來自 2026-10-24 的討論：看 `robots.txt` 的人、按 Ctrl+U 看原始碼的人、打開 DevTools console 的人，各自會看到一個跟駕駛休息有關的哏。

需要的資料：不需要。不讀衍生表、不讀原始檔，沒有新增資料來源，也不改任何指標定義，所以沒有新的資料限制要寫。`robots.txt` 與 console 引用的規則是汽車運輸業管理規則第 19 條之 2 的「連續 4 小時至少休 30 分鐘」，跟 `docs/background.md` 與 `layover-metrics` 用的是同一條。

## What Changes

- 404 頁做成站牌：`public/404.html` 從 Rails 預設的英文頁換成中文的站牌頁，配色照首頁插圖裡那支站牌：琥珀色的牌面，深色的頂條與桿子。title 是「這一站沒有停靠｜折返點 TurnAround」，牌面的站名是「這一站沒有停靠」，路線列是路線號碼「404」加上連回 `/` 的「往 首頁」。title 不放顏文字。
- 路線清單外的路線 Id（例如 `/routes/9999`）改成回這一頁，狀態碼仍是 404。網站上不存在的網址，正式站本來就由 Rails 回 `public/404.html`，換了內容之後也是這一頁。
- `public/robots.txt` 加一行註解「機器人也一樣，連續工作 4 小時至少休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）」。只加註解，不加 `Crawl-delay` 或任何規則，爬蟲的行為不變。Rails 送靜態 `.txt` 檔時，Content-Type 只有 `text/plain`、沒有標編碼，瀏覽器不一定用 UTF-8 解，中文註解可能變成亂碼，所以 `.txt` 的 Content-Type 改成帶 `charset=utf-8`。
- 原始碼裡的 ASCII 公車：用網站 layout 的每一頁（首頁、路線頁），`<!DOCTYPE html>` 的下一行是一個 HTML 註解，裡面是一台只用 ASCII 字元畫的公車，給按 Ctrl+U 看原始碼的人。
- console 的 `休息()`：每次完整載入頁面，console 印一行「輸入 休息() 試試看」；在 console 打 `休息()`，會印出「駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）」。用 Turbo 換頁不會再印一次。`休息` 是掛在 `window` 上的全域函式。console 裡不畫任何圖。
- `site-layout` 的「每一頁都有網站名稱列」與「每一頁都有顯名聲明」兩條，加上 `public/` 底下靜態錯誤頁的例外：這些頁不經過網站 layout，也不顯示任何資料。`docs/spectra/LANGUAGE.md`「顯名聲明」的邊界也從「每一頁」改成用到這些資料的每一頁。

## Non-Goals

- console 的 ASCII 海報（不管是「洋流」、「折返」還是公車），以及 title 裡的顏文字（包括 404 頁的 title）：使用者 2026-10-24 討論後決定都不做。討論時列過的考量：title 會出現在分頁、書籤與搜尋結果，layout 又沒有 `og:` 標籤，LINE、Facebook 的分享預覽也用它；「洋流」是競選吉祥物的名字（`home-hero-turnaround-loop` 的 design 有記），照片上海報的 20261128 是投票日，選罷法第 56 條第 2 款禁止任何人在投票日從事競選、助選活動。
- 切走分頁時換 title：同上，不做。
- 路線頁專屬的 `<title>`（帶路線名）：`home-page` 的非目標留給另一個小 change。
- 換 favicon（`public/icon.svg` 與 `public/icon.png` 的紅點）：`home-page` 的非目標留給另一個作圖的小 change。
- 其他錯誤頁（`public/400.html`、`public/406-unsupported-browser.html`、`public/422.html`、`public/500.html`），以及路線頁參數錯誤時回的空白 400（`head :bad_request`）：維持現狀。
- 404 頁的英文版：網站沒有切換語系的機制，一律用預設的 `tw`。
- 讓 404 頁經過網站 layout（網站名稱列、顯名聲明、Vite 的 CSS 與 JS）：否決，理由在 design。
- Konami code，以及 `curl bus.5xcamp.us` 回文字版：討論時列為這次不做。Konami code 要動剛 archive 的插圖動畫；文字版要改 controller 與回應格式。

## Capabilities

### New Capabilities

- `not-found-page`: 網站的 404 頁：站牌的樣子、title、連回首頁的連結；網站上不存在的網址與路線清單外的路線 Id 都回這一頁。
- `easter-eggs`: 給好奇的人的三個小東西：`robots.txt` 的註解、原始碼裡的 ASCII 公車、console 的 `休息()`。

### Modified Capabilities

- `route-page`: 「Route page address and parameters」對路線清單外的路線 Id，從只回 404 狀態碼改成回網站的 404 頁。
- `site-layout`: 「Attribution footer on every page」與「Site name bar on every page」加上 `public/` 底下靜態錯誤頁的例外。

## Impact

- Affected specs: `not-found-page`（新）、`easter-eggs`（新）、`route-page`、`site-layout`
- Affected code:
  - public/404.html
  - app/controllers/routes_controller.rb
  - public/robots.txt
  - config/initializers/mime_types.rb（新）
  - app/views/layouts/application.html.erb
  - app/frontend/entrypoints/application.js
  - app/frontend/rest_command.js（新）
  - spec/requests/routes_spec.rb
  - spec/requests/not_found_page_spec.rb（新）
  - spec/requests/easter_eggs_spec.rb（新）
  - spec/system/rest_command_spec.rb（新）
  - docs/spectra/LANGUAGE.md
- 跟進行中的 change：`run-time-vs-cycle` 與 `turnaround-facilities` 改的是 `app/views/routes/show.html.erb` 與路線頁的其他需求（`route-page` 的「Page content」「Section links」「Data limitations on the page」），不碰 `RoutesController`、layout、`application.js` 與 `public/`。這次的 `route-page` delta 只改「Route page address and parameters」。`docs/spectra/LANGUAGE.md` 別的 change 也會改，這次只動「顯名聲明」一條。
