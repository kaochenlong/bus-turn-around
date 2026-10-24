## 1. 404 頁的測試（先失敗）

- [x] 1.1 新增 `spec/requests/not_found_page_spec.rb`，涵蓋「Not-found page」的兩個情境，做法照設計「不存在網址的測試關掉 show_detailed_exceptions」。請求 `/no-such-page` 的例子：在 `around` 裡把 `Rails.application.env_config["action_dispatch.show_detailed_exceptions"]` 設成 `false`，在 `ensure` 裡還原，斷言狀態是 404，`response.body` 等於 `public/404.html` 的內容。頁面內容的例子直接 parse `public/404.html`，斷言：title 是「這一站沒有停靠｜折返點 TurnAround」；唯一的 `h1` 是「這一站沒有停靠」；恰好一個 `a`，`href` 是 `/`，文字含「404」與「往 首頁」；robots meta 是 `noindex, nofollow`；沒有 `script`、`[data-site-bar]` 與 `footer[data-attribution]`。每個例子維持 `RSpec/ExampleLength` 的 5 行以內。驗證：`bundle exec rspec spec/requests/not_found_page_spec.rb` 的內容例子失敗，因為現在是 Rails 預設的英文頁；不存在網址的例子通過，因為 Rails 本來就回這個檔，這證明關掉除錯頁的做法有效。
  - 結果（2026-10-24）：內容例子先跑，失敗在 title 與 body 都不含站名（得到 `[false, false, "noindex, nofollow"]`）；Rails 預設頁的 robots meta 本來就是 `noindex, nofollow`，紅燈只來自站名。不存在網址的例子一開始就通過（既有行為），做兩個反向驗證：拿掉 `around` 的開關，回的是 Rails 的除錯頁（`RoutingError`），比對失敗；暫時放一個 `public/404.tw.html`（`ActionDispatch::PublicExceptions` 先找目前語系的檔，預設語系是 `tw`），例子失敗在拿到那個檔，刪掉後恢復。`bin/rubocop` 沒有 offense。
  - 測試範圍的排除理由：內容例子只斷言兩件事：title 與牌面都帶著 `I18n.t("site.name")`（靜態檔沒辦法讀 locale 檔，兩邊的站名沒有東西綁在一起，照 TDD 的判準屬於「分開的檔案裡要對得上的字面值」，比對時不管前後文與位置），以及 robots meta（給爬蟲讀的輸出）。task 點名的其他斷言沒有寫：title 的「這一站沒有停靠｜」、唯一的 `h1` 與它的文字、恰好一個連到 `/`、文字含「404」與「往 首頁」的 `a`，以及沒有 `script`、`[data-site-bar]` 與 `footer[data-attribution]`。這些都是靜態檔裡寫死的內容，沒有分支或輸入決定它們，只有改這個檔才會變，改的時候就看得到；改由 2.1 的內容審閱（逐字對照設計的文案表）與 8.1 的人工確認（點連結回到首頁）。
- [x] 1.2 改寫 `spec/requests/routes_spec.rb` 的「路線不在路線清單裡回 404」，對應「Route page address and parameters」的 Route not configured 情境：狀態 404，而且 `response.body` 等於 `public/404.html` 的內容。驗證：`bundle exec rspec spec/requests/routes_spec.rb` 只有這個例子失敗，因為現在回的是空白內容，其餘例子照舊通過。
  - 結果（2026-10-24）：改寫後先跑，30 個例子只有這個失敗，得到 `[404, ""]`（`head :not_found` 的空白內容），其餘 29 個照舊通過。

## 2. 404 頁

- [x] 2.1 照設計「404 頁用靜態的 public/404.html，不經過網站 layout」與「404 頁的內容與樣子照首頁插圖的站牌」改寫 `public/404.html`，結果是一個中文的站牌頁：文案逐字照設計的表，配色照插圖的站牌，樣式寫在頁內的 `<style>`，從 Google Fonts 載 Barlow 與 Noto Sans TC，沒有 `script`。驗證：1.1 的內容例子通過；文案逐字對照設計的表（內容審閱）。[after: 1.1]
  - 結果（2026-10-24）：改寫後 `spec/requests/not_found_page_spec.rb` 兩個例子都通過；不存在網址的例子比的是含中文的內容（回應是 UTF-8，位元組數與檔案相同，都是 4148），不是空比對。robots meta 的反向驗證：暫時改成 `index, follow`，內容例子失敗，還原後轉綠。內容審閱用程式比對：設計文案表的 title、站牌頂條、`h1`、牌面下方的小字四格跟頁面解析出來的文字一字不差，「往 首頁」中間是半形空白，兩邊位元組相同；只有一個 `a`，`href="/"`，兩個 `span` 是「404」與「往 首頁」；一個 `h1`，沒有 `script`、`[data-site-bar]` 與 `footer[data-attribution]`，`lang="zh-Hant-TW"`。初版的數值（8.1 再定）：牌面 22rem 寬、640px 以上 24rem，圓角 12px；站名用頁面標題的字級（手機 30px、640px 以上 40px），內文 17px、小字 15px，跟 `application.css` 的 token 相同；路線號碼 28px；桿子 16px 寬、`clamp(88px, 24vh, 220px)` 長，底座 64×10px。headless Chrome 模擬 390×844：`scrollWidth` 390、`scrollHeight` 844，橫向縱向都不用捲動，牌面左右各留 19px，Barlow 600 與 Noto Sans TC 500、700 都有載到；1280×800 牌面在畫面中間。WCAG 公式算的對比：牌面字 `#0f172a` 對 `#fbbf24` 10.69:1，頂條與路線號碼的白字對 `#1e293b` 14.63:1（8.1 用 DevTools 確認）。
- [x] 2.2 照設計「路線清單外的路線 Id 用 render file 回 404 頁」，讓 `RoutesController#show` 對路線清單外的 Id 回 `public/404.html` 的內容與 404：`head :not_found` 換成 `render file: Rails.public_path.join("404.html"), status: :not_found, layout: false`，判斷的位置不變，參數錯誤的 `head :bad_request` 不動。驗證：1.2 的例子通過，`bundle exec rspec spec/requests/routes_spec.rb` 全部通過。[after: 1.2]
  - 結果（2026-10-24）：改完 `spec/requests/routes_spec.rb` 30 個例子全過，`bin/rubocop` 沒有 offense。反向驗證：拿掉 `layout: false`，`render file:` 會把整頁包進網站 layout，1.2 的例子失敗，還原後轉綠；判斷那一行加了註解說明為什麼用 render、為什麼要 `layout: false`。安全面：路徑是常數 `Rails.public_path.join("404.html")`，沒有使用者輸入，不會變成讀任意檔案；`head :bad_request` 沒動。

## 3. robots.txt 的註解

- [x] 3.1 新增 `spec/requests/easter_eggs_spec.rb`，先寫「Comment in robots.txt」的情境：`GET /robots.txt` 回 200，Content-Type 是 `text/plain; charset=utf-8`，內容含「# 機器人也一樣，連續工作 4 小時至少休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）」這一行，每一個非空白的行都以 `#` 開頭。驗證：`bundle exec rspec spec/requests/easter_eggs_spec.rb` 這個例子失敗，因為沒有那行註解，Content-Type 也沒有 charset。
  - 結果（2026-10-24）：例子先跑，失敗在 Content-Type：得到 `[200, "text/plain", []]`。「每一個非空白的行都是註解」現在就成立（檔案只有 Rails 那行註解），反向驗證放在 3.2 Content-Type 轉綠之後做，失敗的原因才分得清楚。`bin/rubocop` 沒有 offense。
  - 測試範圍的排除理由：沒有斷言內容含那一行中文註解。註解是靜態檔裡寫死的文字，爬蟲不讀，只給打開檔案的人看；沒有分支或輸入決定它，只有改 `public/robots.txt` 才會變，改的時候就看得到，改由 3.2 的內容審閱逐字對照設計的原句。中文註解要正確顯示靠的是 Content-Type 的 charset，這一項有斷言。另外測試環境拿到的 `response.body` 是 ASCII-8BIT，拿中文字串對它做 `include?` 會因為編碼不同而出錯。
- [x] 3.2 照設計「robots.txt 只加註解，.txt 的 Content-Type 帶 charset=utf-8」，讓 `/robots.txt` 帶著那行註解、以 UTF-8 送出：`public/robots.txt` 保留原本那行，下一行加上註解，不加任何規則；新增 `config/initializers/mime_types.rb`，把 `.txt` 的 MIME type 設成 `text/plain; charset=utf-8`，附一行註解說明原因。驗證：3.1 的例子通過。[after: 3.1]
  - 結果（2026-10-24）：3.1 的例子轉綠。內容審閱用程式比對：`public/robots.txt` 第二行跟 spec 與 design 裡的原句一字不差，整份兩行、是合法的 UTF-8，沒有任何規則。反向驗證：暫時在檔尾加 `Crawl-delay: 10`，例子失敗在多出那一行，還原後轉綠。`bin/rubocop config/initializers/mime_types.rb` 沒有 offense。`Rack::Mime::MIME_TYPES` 是全域的表，只改 `.txt` 一個鍵：`public/` 底下（不算 `public/vite/`）只有 `robots.txt` 一個 `.txt`，`app/`、`lib/`、`config/` 也沒有其他送 `.txt` 或 `text/plain` 的地方。

## 4. 原始碼裡的 ASCII 公車

- [x] 4.1 在 `spec/requests/easter_eggs_spec.rb` 加上「Bus drawing in the page source」的兩個情境。`/` 的回應以 `<!DOCTYPE html>`、換行、HTML 註解開頭；註解在 `<html` 之前結束，含 `TurnAround`，只有可見的 ASCII 字元、空白與換行，開頭與結尾記號之間沒有 `--`。`/routes/9001`（沒有資料）回 200，開頭的 doctype 與註解跟首頁相同。驗證：這兩個例子失敗，因為 layout 還沒有註解。[after: 3.1]
  - 結果（2026-10-24）：首頁的例子先跑，失敗在 layout 沒有註解：得到 `[nil, nil]`。例子用一個 regex 認出 DOCTYPE 下一行開始、`<html` 之前結束的註解，再斷言裡面只有可見的 ASCII、空白與換行，而且不含 `--`；註解中間如果提早出現 `-->`，抓到的內容會含 `--` 而失敗。`bin/rubocop` 沒有 offense。
  - 測試範圍的排除理由：沒有斷言註解含 `TurnAround`，也沒有寫路線頁那個例子。公車圖與車身上的字是 layout 裡寫死的內容，沒有分支或輸入決定它，改圖的時候就看得到，改由 4.2 的內容審閱與 8.2 的人工確認；例子靠位置（DOCTYPE 的下一行、`<html` 之前）認出這個註解，不靠字。有斷言的三項都是改的地方看不出來、壞掉時出現在別處的性質：提早結束的註解會讓剩下的圖變成每一頁 body 裡的文字，非 ASCII 字元在 view-source 的等寬字型裡會對不齊，DOCTYPE 前面多了東西會讓舊瀏覽器進 quirks mode。路線頁跟首頁用的是同一份 layout、同一段寫死的註解，沒有輸入讓兩頁不同，只是重用不構成要測的理由；路線頁經過網站 layout 這件事，已經由 `spec/requests/site_layout_spec.rb` 對 `/routes/9001` 的兩個例子（恰好一條網站名稱列、恰好一個顯名聲明 footer）證明。
- [x] 4.2 照設計「ASCII 公車放在 layout 的 DOCTYPE 下一行，只用 ASCII、不含 --」，讓用網站 layout 的每一頁在原始碼開頭帶一台 ASCII 公車：在 `app/views/layouts/application.html.erb` 的 `<!DOCTYPE html>` 下一行、`<html>` 之前放 HTML 註解，內容是設計裡的公車；可以修圖，限制照設計。驗證：4.1 的兩個例子通過；`bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/pages_spec.rb spec/requests/routes_spec.rb` 照舊通過。[after: 4.1]
  - 結果（2026-10-24）：用的是設計的初稿，沒有修圖：最寬 50 欄、只有 ASCII、不含 `--`、行尾沒有空白，六個車窗間距相同，兩個輪子對準輪拱。圖由程式從 design.md 原樣抄進 layout，避免手打反斜線出錯。4.1 的首頁例子轉綠，加上 `site_layout_spec.rb`、`pages_spec.rb`、`routes_spec.rb`、`not_found_page_spec.rb` 共 48 個例子全過。反向驗證：在車身塞進 `--`、一個中文字、一個提早結束的 `-->`，三次都失敗，還原後轉綠。內容審閱：首頁回應的開頭是 DOCTYPE、公車註解、`<html>`；`/routes/9001`（沒有資料）回 200，前 12 行跟首頁完全相同（4.1 排除的路線頁情境在這裡人工確認）；`/routes/9999` 回的是 404 頁本身，沒有公車。註解共 395 位元組。

## 5. console 的 休息()

- [x] 5.1 新增 `spec/system/rest_command_spec.rb`（標 `:js`），做法照設計「console 的測試用 CDP 在頁面腳本執行前包住 console.log」，涵蓋「Rest command in the console」的三個情境：開 `/` 之後，提示「輸入 休息() 試試看」恰好收到一次，`window.休息` 是函式；呼叫 `休息()` 之後收到「駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）」；開 `/routes/9001`，點網站名稱列的連結回 `/`，等 `[data-section=hero]` 出現之後，提示仍然只有一次。驗證：`bundle exec rspec spec/system/rest_command_spec.rb` 三個例子都失敗，因為還沒有 `休息`。
  - 結果（2026-10-24）：三個例子先跑都失敗：完整載入得到 `[0, "undefined"]`；呼叫 `休息()` 是 Selenium 的 `JavascriptError`「休息 is not defined」，指令不存在本身就是要測的行為，不是測試寫錯；Turbo 換頁得到 0，而且拿得到記錄陣列，表示換頁確實沒有換 document。`bin/rubocop` 沒有 offense。例子用規格的原句認出 console 的那兩行，因為要測的是印的次數與時機、指令存不存在、呼叫後印了什麼，句子只拿來分辨是哪一行；不改成數 `console.log` 的總次數，是因為 three.js 在 WebGL context 掉了的時候會用 `console.log` 印「THREE.WebGLRenderer: Context Lost.」，總數會不穩。呼叫的例子另外斷言回傳 `undefined`，對應設計的介面約定。
- [x] 5.2 照設計「休息() 放在自己的模組，由 application.js 在最外層呼叫」，讓每次完整載入都印出提示並定義 `window.休息`：新增 `app/frontend/rest_command.js`，具名匯出 `installRestCommand()`；`app/frontend/entrypoints/application.js` import 它，在最外層呼叫一次，附一行註解。兩句文案逐字照設計。驗證：5.1 的三個例子通過（跑系統測試前，`spec/support/vite.rb` 會先 `yarn build`）；`bundle exec rspec spec/system/home_hero_spec.rb` 照舊通過。[after: 5.1]
  - 結果（2026-10-24）：`spec/system/rest_command_spec.rb` 3 個與 `spec/system/home_hero_spec.rb` 11 個例子全過。`installRestCommand()` 放在 `application.js` 最後、`Alpine.start()` 之後呼叫，它出錯也不會擋到頁面其他部分。內容審閱用程式比對：`rest_command.js` 的兩句跟 spec 與 design 的原句一字不差。打包後的檔案直接寫 `window.休息=()=>{…}`，沒有跳脫成 `\u` 形式，module script 一律以 UTF-8 解碼。反向驗證：紅燈時 Turbo 換頁那個例子失敗的原因是完全沒印，所以另外把呼叫暫時改成每次 `turbo:load` 都執行，只有那個例子失敗，數到 2；還原並重新 build 後轉綠。

## 6. 詞彙表

- [x] 6.1 照設計「site-layout 加上靜態錯誤頁的例外，LANGUAGE.md 的顯名聲明跟著改」，讓詞彙表跟規格一致：`docs/spectra/LANGUAGE.md`「顯名聲明」的邊界改成設計裡那句，改之前重讀整份檔案，因為別的 change 也在改這個檔。`site-layout` 的「Attribution footer on every page」與「Site name bar on every page」兩條的例外已經寫在這個 change 的 delta spec，archive 時才套用，這個任務不改 `docs/spectra/specs/`。驗證：內容審閱，「顯名聲明」這一條只動到邊界那一行，其他條不動；`bundle exec rspec spec/requests/site_layout_spec.rb` 照舊通過，因為兩條需求對用 layout 的頁面行為沒變。
  - 結果（2026-10-24）：改之前重讀整份 `docs/spectra/LANGUAGE.md`，沒有別人未 commit 的修改。`git diff` 只有「顯名聲明」的邊界一行，新的句子用程式比對，跟設計裡的原句一字不差；其他條沒動。`spec/requests/site_layout_spec.rb` 9 個例子照舊通過（HEAD 是 8 個，多的 1 個是 `01-bus-feeds-attribution` 還沒 commit 的新例子）。沒有新增測試：這是詞彙表的文字，不是程式行為。

## 7. 自動檢查

- [x] 7.1 對這次新增或修改的 Ruby 檔跑 `bin/rubocop app/controllers/routes_controller.rb config/initializers/mime_types.rb spec/requests/not_found_page_spec.rb spec/requests/routes_spec.rb spec/requests/easter_eggs_spec.rb spec/system/rest_command_spec.rb`，沒有 offense；再跑 `bin/ci`。驗證：兩個指令都成功結束，`bin/ci` 的平行 RSpec 全部通過。[after: 2.1, 2.2, 3.2, 4.2, 5.2, 6.1]
  - 結果（2026-10-24）：task 列的 6 個 Ruby 檔 `bin/rubocop` 沒有 offense。第一次 `bin/ci` 失敗在平行 RSpec：785 個例子 22 個失敗，全在 `spec/system/home_hero_spec.rb`（11 個）與 `spec/system/end_map_spec.rb`（11 個），分屬兩個 worker，錯誤全是 Selenium 的 `InvalidSessionIdError`（「session deleted as the browser has closed the connection」，Chrome 斷線），沒有任何斷言失敗；當時這台機器同時在跑另一個專案的 11 個平行測試程序，1 分鐘負載 61 到 67。這兩個檔用單一 process 重跑，24 個例子全過；等 1 分鐘負載降到 8 以下重跑 `bin/ci`：Setup、RuboCop、bundler-audit、Brakeman、平行 RSpec（785 個例子 0 失敗）、seeds 全部通過，結束碼 0，Brakeman 沒有對 `render file:` 報警告。兩次 `bin/ci` 都連同工作區裡 `01-bus-feeds-attribution` 與 `load-chart-stretch-markers` 還沒 commit 的改動一起跑；`bin/setup` 沒有改到任何 repo 裡的檔。

## 8. 人工確認

- [x] 8.1 用 `bin/dev` 開 `/routes/9999` 與 `/404.html`（開發環境對不存在的網址會顯示 Rails 的除錯頁，所以直接開檔案本身），在 1280px 與 390px 寬看 404 頁：站牌在畫面中間；390px 寬整塊放得下、不用捲動；配色像首頁插圖的站牌；用 Tab 移到「往 首頁」看得到 focus 外框，點了回到首頁；用 DevTools 的對比檢查確認牌面文字至少 4.5:1。牌面寬度、圓角、字級與桿子長度在這一步定下來。驗證：使用者看過畫面確認。[after: 2.1, 2.2]
  - 結果（2026-10-24）：使用者看過確認沒問題，牌面寬度、圓角、字級與桿子長度維持 2.1 記的初版數值。
- [x] 8.2 用 `bin/dev` 在 Chrome 與 Firefox 開首頁：按 Ctrl+U，原始碼開頭的公車是對齊的；打開 DevTools 的 console，看得到「輸入 休息() 試試看」，打 `休息()` 印出規則；開 `/robots.txt`，中文註解不是亂碼。驗證：使用者看過確認。[after: 3.2, 4.2, 5.2]
  - 結果（2026-10-24）：使用者在 Chrome 與 Firefox 看過確認沒問題。
