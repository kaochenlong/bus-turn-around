## Context

2026-10-24 的討論（`/spectra-discuss`）一開始要在 title 放顏文字、在 console 畫洋流海報的 ASCII，後來列了幾個「給好奇的人」的哏。使用者最後選了四件：404 頁做成站牌、`robots.txt` 的註解、原始碼裡的 ASCII 公車、console 的 `休息()`；console 的圖和 title 的顏文字都不做（proposal 的非目標）。

現況（2026-10-24 讀過的程式）：

- `<title>` 由 `app/views/layouts/application.html.erb` 輸出，沒設 title 的頁面用 `site.name`（「折返點 TurnAround」）；`<meta name="application-name">` 讀同一個鍵。這次不動 title。
- `RoutesController#show` 對路線清單外的路線 Id 用 `head :not_found`，回應沒有內容，瀏覽器顯示空白頁。參數錯誤用 `head :bad_request`，一樣是空白頁。
- `public/404.html` 是 Rails 預設的英文頁。正式站（`config.consider_all_requests_local = false`）對沒有路由的網址，由 `ActionDispatch::PublicExceptions` 回這個檔。測試環境 `config.action_dispatch.show_exceptions = :rescuable`，但 `consider_all_requests_local = true`，所以會顯示 Rails 的除錯頁。
- `public/robots.txt` 只有 Rails 預設的一行註解，沒有任何規則。Rails 送 `public/` 底下的檔案時（`ActionDispatch::FileHandler`），用 `Rack::Mime.mime_type` 決定 Content-Type；Rack 3.2.7 的表裡 `.txt` 是沒有 charset 的 `text/plain`。
- 前端入口是 `app/frontend/entrypoints/application.js`，放 Turbo、Alpine 與首頁插圖的設定。layout 用 `ViteHelper#vite_assets` 載入它；正式與測試環境讀 Vite 的 manifest，檔名帶 hash。Turbo Drive 換頁不會重新執行入口。
- CSP 沒開（`config/initializers/content_security_policy.rb` 整份是註解）。
- 系統測試：`spec/support/system.rb` 預設 rack_test，標 `:js` 才開 headless Chrome；`spec/support/vite.rb` 在跑到 `spec/system/` 時先 `yarn build`。`spec/system/home_hero_spec.rb` 的 `visit_counting_frames` 用 CDP 的 `Page.addScriptToEvaluateOnNewDocument`，在頁面自己的腳本執行前包住 `requestAnimationFrame`。
- 首頁插圖的站牌（`app/frontend/hero/scene.js` 的 `stopSign()`）：桿子與頂條是 `SLATE_800`（`#1e293b`），牌面是 `AMBER_400`（`#fbbf24`），牌面寬高比 1.1:1.5。
- 進行中的 `run-time-vs-cycle` 與 `turnaround-facilities` 都改 `app/views/routes/show.html.erb`，這次不碰那個檔。

## Goals / Non-Goals

**Goals:**

- 路線清單外的路線 Id 與網站上不存在的網址，都回同一個中文的 404 頁，狀態碼 404。
- `robots.txt` 多一行跟駕駛休息有關的註解，瀏覽器打開不會是亂碼，爬蟲的行為不變。
- 首頁與路線頁的原始碼開頭有一台 ASCII 公車。
- 每次完整載入，console 有一行提示；打 `休息()` 印出第 19 條之 2 的休息規則。

**Non-Goals:**

- console 的圖、title 的顏文字、切走分頁時換 title、路線頁專屬的 title、favicon、其他錯誤頁與空白的 400、404 頁的英文版、Konami code、`curl` 文字版：理由見 proposal 的非目標。
- 讓 404 頁經過網站 layout：見「404 頁用靜態的 public/404.html，不經過網站 layout」。

## Decisions

### 404 頁用靜態的 public/404.html，不經過網站 layout

改寫 `public/404.html` 這個檔，網站只有這一個 404 頁。正式站對沒有路由的網址本來就回它，不用寫程式；路線清單外的路線 Id 也回它（見「路線清單外的路線 Id 用 render file 回 404 頁」）。

不經過 layout，所以：

- 沒有網站名稱列：名稱列用的 logo（`turnaround-logo.webp`）經過 Propshaft 加了 digest，靜態檔拿不到正確的檔名。網站名稱改寫在站牌的頂條上，回首頁靠站牌上的連結。
- 沒有顯名聲明：404 頁不顯示任何資料。授權條款要求的是利用資料的地方要顯名。
- 不載 Vite 的 CSS 與 JS：打包後的檔名帶 hash，靜態檔拿不到。所以 404 頁沒有 `休息()`，樣式寫在頁內的 `<style>`，跟 Rails 預設的錯誤頁一樣。

字型照首頁與路線頁的做法，從 Google Fonts 載 Barlow 與 Noto Sans TC。路線號碼「404」用 Barlow，它是公路標誌字形。載不到時退回系統字型。

替代方案：

- `config.exceptions_app = routes`，加一個用 layout 畫的 ErrorsController（否決：所有錯誤狀態都會改走 app 與路由，400、406、422、500 都要有對應的路由，否則錯誤頁本身會出錯；500 頁也會依賴 app 正常運作。為了一個 404 改整個錯誤處理不划算）。
- 路線清單外的 Id 用 layout 畫一個 view，不存在的網址照舊用靜態檔（否決：同一件事兩個頁面，樣子會分岔）。

### 路線清單外的路線 Id 用 render file 回 404 頁

`RoutesController#show` 判斷路線 Id 不在路線清單時，把 `head :not_found` 換成 `render file: Rails.public_path.join("404.html"), status: :not_found, layout: false`。判斷的條件與位置不變，仍在算 `@ends` 之前。參數錯誤的 `head :bad_request` 不動。

替代方案：`raise ActionController::RoutingError`（否決：開發與測試環境的 `consider_all_requests_local = true` 會顯示 Rails 的除錯頁，request spec 拿不到 404 頁，開發時也看不到；`render file:` 在每個環境都回同一個檔，測試可以直接比對內容）。

### 404 頁的內容與樣子照首頁插圖的站牌

文案（全部照抄）：

| 位置 | 文字 |
| --- | --- |
| `<title>` | 這一站沒有停靠｜折返點 TurnAround |
| 站牌頂條 | 折返點 TurnAround |
| 站名（唯一的 `h1`） | 這一站沒有停靠 |
| 路線列（唯一的連結，`href="/"`） | 路線號碼「404」，後面接「往 首頁」 |
| 牌面下方的小字 | 網址可能打錯了，或是這一頁已經不在了。 |

結構：

```html
<!doctype html>
<html lang="zh-Hant-TW">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>這一站沒有停靠｜折返點 TurnAround</title>
    <!-- Google Fonts：preconnect 兩條，加上 Barlow 600 與 Noto Sans TC 500、700 的 stylesheet -->
    <style>/* 見下面的配色 */</style>
  </head>
  <body>
    <main>
      <div class="sign">
        <p class="sign-band">折返點 TurnAround</p>
        <h1>這一站沒有停靠</h1>
        <a class="sign-route" href="/"><span class="route-number">404</span> <span>往 首頁</span></a>
        <p class="sign-note">網址可能打錯了，或是這一頁已經不在了。</p>
      </div>
      <div class="pole" aria-hidden="true"></div>
    </main>
  </body>
</html>
```

配色照插圖的站牌：頁面底色 `#f8fafc`（slate-50，跟路線頁一樣）；牌面 `#fbbf24`，上面的字 `#0f172a`（約 11:1 的對比，用 WCAG 公式手算的估計值，8.1 用 DevTools 的對比檢查確認至少 4.5:1）；頂條、路線號碼的底與桿子 `#1e293b`，上面的字是白色；連結 focus 時用 2px 的 `#0f172a` 外框。牌面在畫面中間，桿子接在牌面下方。牌面寬度、圓角、字級與桿子長度在 apply 時看畫面定，手機寬度（390px）也要整塊放得下、不用捲動。不放動畫，沒有 `script`。

### robots.txt 只加註解，.txt 的 Content-Type 帶 charset=utf-8

`public/robots.txt` 保留原本那行 Rails 的說明，下一行加上 `# 機器人也一樣，連續工作 4 小時至少休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）`（使用者給的原句）。不加 `User-agent`、`Disallow` 或 `Crawl-delay`：`Crawl-delay` 是真的會生效的指令，Bing 會照做。

新增 `config/initializers/mime_types.rb`，內容是 `Rack::Mime::MIME_TYPES[".txt"] = "text/plain; charset=utf-8"`，加一行註解說明原因：沒標編碼時，瀏覽器不一定用 UTF-8 解，中文註解會變亂碼。`public/` 底下目前只有 `robots.txt` 一個 `.txt`。

替代方案：

- `robots.txt` 改由 controller 用 `render plain:` 送（否決：要多一條路由與一個 action，還得刪掉 `public/robots.txt`，只為了一個 header）。
- 註解改寫成英文（否決：使用者要的是這句中文）。
- 檔頭加 UTF-8 BOM（否決：看不見，編輯器容易把它弄掉）。

### ASCII 公車放在 layout 的 DOCTYPE 下一行，只用 ASCII、不含 --

`app/views/layouts/application.html.erb` 在 `<!DOCTYPE html>` 下一行、`<html>` 之前放一個 HTML 註解（`<!-- -->`；ERB 註解不會送到瀏覽器）。初稿：

```text
<!--
   ____________________________________________
  |  ___    ___    ___    ___    ___    ___  | \
  | |   |  |   |  |   |  |   |  |   |  |   | |  \
  | |___|  |___|  |___|  |___|  |___|  |___| |___\
  |                                          |   |
  |  TurnAround                              |  o|
  |____/ \______________________/ \__________|___|
       \_/                      \_/
-->
```

apply 時可以修圖，但限制不變：

- 只用可見的 ASCII 字元、空白與換行。中文在 view-source 的等寬字型裡不一定剛好兩格寬，會對不齊。
- 註解內容不含 `--`。現在的 HTML 規範允許，但舊的檢查工具會警告，也避免不小心寫出 `-->`，讓註解提早結束。
- 寬度 50 欄以內；車身上要有 `TurnAround`，測試用它認這台車。

放在 DOCTYPE 之後：DOCTYPE 前面放註解，現在的 HTML 規範允許，但舊瀏覽器會因此進 quirks mode，沒必要冒險。註解在 `<html>` 之外，Turbo 換頁只換 `<body>`、合併 `<head>`，碰不到它；按 Ctrl+U 會重新抓原始碼，所以每一頁都看得到。

404 頁不經過 layout，不放這台車。

### 休息() 放在自己的模組，由 application.js 在最外層呼叫

新增 `app/frontend/rest_command.js`，具名匯出 `installRestCommand()`，沒有參數、回傳 `undefined`。它做兩件事：

1. 把 `休息` 掛到 `window`。`休息()` 用 `console.log` 印出「駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）」，回傳 `undefined`（console 會在後面多顯示一行 `undefined`，這是 console 的慣例）。
2. 用 `console.log` 印出提示「輸入 休息() 試試看」。

`app/frontend/entrypoints/application.js` import 它，在最外層呼叫一次，加一行註解說明這是什麼、為什麼一次完整載入只印一次。Turbo Drive 換頁不會重新執行入口，所以提示不會每換一頁就印一次。Chrome 與 Firefox 打開 DevTools 時，會顯示打開之前印的訊息，所以不需要偵測 F12。

規則用「駕駛連續開車」，不照 `robots.txt` 寫「連續工作」：`robots.txt` 那句以「機器人也一樣」開頭，是比喻；console 印的是規則本身，第 19 條之 2 管的是駕車（`docs/background.md`）。

為什麼要獨立成一個模組：`application.js` 現在放的是 Turbo、Alpine 與首頁插圖的設定，這件事跟它們無關。用具名的函式呼叫，不靠 import 的副作用，讀 `application.js` 就看得到它做了什麼。

替代方案：

- 直接寫在 `application.js`（否決：理由如上）。
- 只在首頁做（否決：任何一頁打開 console 都該看得到）。
- 偵測 DevTools 有沒有打開（否決：量視窗大小會誤判，`debugger` 會讓開發者的頁面停住）。

### console 的測試用 CDP 在頁面腳本執行前包住 console.log

新增 `spec/system/rest_command_spec.rb`，標 `:js`。照 `home_hero_spec.rb` 的 `visit_counting_frames`：visit 之前用 `Page.addScriptToEvaluateOnNewDocument` 裝一段腳本，包住 `console.log`，把每次呼叫的參數用空白串起來，存進 `window.consoleLines`，同時照樣交給原本的 `console.log`；visit 之後用 `Page.removeScriptToEvaluateOnNewDocument` 拿掉。斷言都讀 `window.consoleLines`。

Turbo 換頁的例子：先開 `/routes/9001`，點網站名稱列的連結（`[data-site-bar] a`）回 `/`，等首頁的 `[data-section=hero]` 出現之後才讀。Turbo 換頁沒有換 document，所以紀錄還在。

替代方案：讀 Chrome 的瀏覽器 log（否決：`spec/support/system.rb` 的 Chrome 沒開 `goog:loggingPrefs`，要改共用的 driver 設定；log 的訊息還帶著來源網址與行號，要另外解析）。

### 不存在網址的測試關掉 show_detailed_exceptions

新增 `spec/requests/not_found_page_spec.rb`。請求不存在網址的例子，用 `around` 把 `Rails.application.env_config["action_dispatch.show_detailed_exceptions"]` 設成 `false`，結束後在 `ensure` 裡還原。關掉之後，測試環境就跟正式站一樣，交給 `ActionDispatch::PublicExceptions` 回 `public/404.html`。

頁面內容的例子直接 parse `public/404.html`，不經過請求。路線清單外的路線 Id 那個例子放在 `spec/requests/routes_spec.rb`，改寫原本的「路線不在路線清單裡回 404」：狀態碼 404，回應內容等於 `public/404.html` 的內容。

### site-layout 加上靜態錯誤頁的例外，LANGUAGE.md 的顯名聲明跟著改

`site-layout` 的 Purpose 寫的是「每一頁從共用 layout 拿到的東西」，但「Attribution footer on every page」與「Site name bar on every page」的內文寫「Every HTML page」，字面上包含了 `public/` 底下的靜態錯誤頁（Rails 預設的那幾頁本來就沒有）。這次把例外寫進這兩條需求（delta spec）。

`docs/spectra/LANGUAGE.md`「顯名聲明」的邊界，從「每一頁、每份釋出檔都要有」改成「用網站 layout 的每一頁、每份釋出檔都要有。`public/` 底下的靜態錯誤頁（例如 404 頁）不經過 layout、不顯示資料，不帶。」其他條不動。

替代方案：

- 404 頁也放一份顯名聲明（否決：要在靜態檔裡複製 `AttributionComponent` 的文字，兩份會分岔）。
- 不改規格，只靠 Purpose 解讀（否決：需求內文字面上跟 404 頁衝突，之後讀規格的人會以為 404 頁漏了）。

## Implementation Contract

**看得到的行為：**

1. 正式站請求網站上不存在的網址，回 404，內容是 `public/404.html`。任何環境請求路線清單外的路線 Id（例如 `/routes/9999`），也回 404 與同一份內容。404 頁是中文的站牌，title「這一站沒有停靠｜折返點 TurnAround」，唯一的連結回 `/`。
2. `GET /robots.txt` 回 200，Content-Type 是 `text/plain; charset=utf-8`，內容只有註解，其中一行是使用者給的那句。
3. 首頁與路線頁回應的開頭是 `<!DOCTYPE html>`、換行、一個裝著 ASCII 公車的 HTML 註解，接著才是 `<html>`。
4. 有 JavaScript 的瀏覽器完整載入任何一頁，console 收到「輸入 休息() 試試看」一次，`window.休息` 是函式；呼叫 `休息()`，console 收到第 19 條之 2 的規則那句。用 Turbo 換頁不會再印提示。

**介面：**

- `app/frontend/rest_command.js` 具名匯出 `installRestCommand()`：沒有參數，回傳 `undefined`；呼叫後 `window.休息` 是沒有參數、回傳 `undefined` 的函式。
- `RoutesController#show` 對路線清單外的 Id 回 `public/404.html` 的內容，狀態 404，不套 layout。
- `config/initializers/mime_types.rb` 把 `.txt` 的 MIME type 設成 `text/plain; charset=utf-8`。

**失敗時：**

- 404 頁的 Google Fonts 載不到：退回系統字型，文字照樣顯示。
- JS 沒載到或被擋：沒有提示也沒有 `休息`，頁面其他部分不受影響。
- 參數錯誤的 400 照舊回空白頁，不在這次的範圍。

**驗收：**

- `bundle exec rspec spec/requests/not_found_page_spec.rb spec/requests/routes_spec.rb spec/requests/easter_eggs_spec.rb spec/requests/site_layout_spec.rb spec/system/rest_command_spec.rb` 全部通過；新的例子在實作之前先跑過一次，確認是失敗的。
- `bin/rubocop` 對這次新增或修改的 Ruby 檔沒有 offense；`bin/ci` 通過。
- 使用者在瀏覽器確認 404 頁（1280px 與 390px 寬）、原始碼裡的公車、console 的提示與 `休息()`。

**範圍：**

- 在範圍內：`public/404.html`、`RoutesController#show` 的 404、`public/robots.txt`、`config/initializers/mime_types.rb`、layout 的 HTML 註解、`app/frontend/rest_command.js` 與 `application.js` 的呼叫、上面列的測試、`docs/spectra/LANGUAGE.md` 的「顯名聲明」一條。
- 不在範圍內：`<title>` 與 `site.name`、`app/views/routes/show.html.erb`、其他錯誤頁、`head :bad_request`、favicon、首頁插圖。

## Risks / Trade-offs

- [`Rack::Mime::MIME_TYPES` 是 Rack 的全域常數，改了影響整個 app] → 只改 `.txt` 一個鍵，`public/` 底下只有 `robots.txt` 是 `.txt`。request spec 斷言 Content-Type，之後 Rack 或 Rails 換了做法，測試會擋下來。
- [測試改了 `Rails.application.env_config` 沒還原，影響後面的例子] → 在 `around` 的 `ensure` 裡還原；平行測試每個 process 各有一份。
- [`render file:` 讀的是 image 裡的 `public/404.html`] → `.dockerignore` 只排除 `/public/assets`，`public/404.html` 會進 image；request spec 比對的是同一個檔。
- [`休息` 要打中文，輸入法切換麻煩] → 這是哏的一部分，提示句寫明要打什麼。
- [「連續工作 4 小時」被當成法條原文] → `robots.txt` 那句以「機器人也一樣」開頭，是比喻；console 印的是駕車的版本。
- [原始碼每頁多一段註解：照初稿算約 400 位元組，修圖後以 4.2 的實際內容為準] → 跟頁面其他內容比可以忽略。
- [`site-layout` 的「Attribution footer on every page」跟別的 change 改到同一條] → 這次的 delta 抄的是 `2026-10-24-turnaround-map` archive 之後的主規格內文（含公廁與底圖兩行顯名、兩個情境），只多一句靜態錯誤頁的例外；起草時抄到舊版、archive 前用預覽發現，2026-10-24 ingest 修正。進行中的 `01-bus-feeds-attribution` 與暫存中的 `03-route-shape-map` 也改這一條：誰後 archive，誰就把先 archive 那一方的內文（包括這句例外）併進自己的 MODIFIED，archive 前先跑 `spectra archive <name> --preview` 對照主規格。
