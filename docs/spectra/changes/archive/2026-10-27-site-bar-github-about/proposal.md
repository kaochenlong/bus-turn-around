## Why

這個 change 改兩個地方，都不新增資料，衍生表與伺服器都不動：

- 每一頁共用的網站名稱列：不直接服務三樣交付物的任何一樣，但讓讀路線健檢卡與換休息試算的人，從每一頁都找得到算出這些數字的程式。網站與算指標的 SQL（`analysis/`）都在公開的 GitHub repo https://github.com/kaochenlong/bus-turn-around（2026-10-27 用 `gh repo view` 查到是 PUBLIC）。名稱列讀的仍是衍生表。
- 當天調度頁：服務第二樣交付物「換休息試算」往調度員桌上推的當天調度。用的是瀏覽器裡存的當天（開始當天的快照與依序的修改）與瀏覽器的時鐘。

2026-10-27 使用者提出名稱列的三件事，討論後的結論：

- 「關於這個網站」改成只顯示「關於」。1280 寬時它是名稱列最長的字（6 個字；班表 2 個、當天調度 4 個），640px 以下已經只顯示「關於」。
- 「關於」放到名稱列右側。現在班表、當天調度、關於這個網站排成一串接在標誌旁邊（`01-day-dispatch-model` 的排法），「關於這個網站」是整列唯一離開網站的連結，排在兩個路線工具後面，看起來像第三個工具。
- 「關於」左邊放 GitHub 圖示，連到這個網站的 repo。網站上目前沒有任何連到 repo 的地方；介紹文章那一頁唯一的 GitHub 連結是作者的帳號首頁（2026-10-27 抓那一頁查的）。

名稱列做完之後，使用者同一天再補兩件當天調度頁的事，要併進這個 change：

- 時間軸的「現在」不會跟著時間走。使用者 19:37 看到的標記還寫「現在 19:28」，拖過一趟才更新。原因在 `app/frontend/timetable/day_view.js` 的 `render()`：每次重畫讀一次時鐘，但只在顯示當天與調度員操作時才跑，頁面上沒有計時器。停住的不只那條線：發車表的狀態（已發車、下一班）與現在分隔線、現在停在末站的車與站了幾分鐘，也都停在上一次重畫的時刻，而 `day-dispatch` 規格寫明這些看「現在」。
- 時間軸的每一趟畫成鳥瞰的公車，看起來更像在調度車輛。2026-10-27 在畫布「當天調度時間軸：鳥瞰公車」比了三列：現況的方塊、A 寫實的公車、B 只留車頭。畫板用開發資料庫 251區 平日 10-19 到 10-22、p85、休息 15 分鋪成的 11 台車、109 趟，現在 17:30。使用者選 A；問了車頭朝右還是朝左，照朝右做。

這些都做完之後，使用者再要求名稱列的 GitHub 連結與「關於」另開新分頁（「github link & about 做另開視窗」）。

## What Changes

- 名稱列分成兩組：左邊是標誌與這條路線的工具（班表、當天調度，只在路線頁、班表頁、當天調度頁），右邊是 GitHub 圖示與「關於」，推到名稱列右端。首頁沒有路線的工具，就是標誌在左、GitHub 與「關於」在右。
- 文章連結每種寬度都只顯示「關於」（en：About），讀螢幕軟體照舊念「關於這個網站」（en：About this site）。原本只有 640px 以下這樣。
- 新增 GitHub 連結：GitHub 官方的 mark 圖示，連到 https://github.com/kaochenlong/bus-turn-around，讀螢幕軟體念「GitHub」。640px 以下不顯示，因為手機上的路線頁放不下（換算在 design）。
- 名稱列的連結數：首頁從兩個變三個，路線頁、班表頁、當天調度頁從四個變五個。
- 名稱列的 GitHub 連結與「關於」另開新分頁（`target="_blank"`、`rel="noopener"`），讀螢幕軟體在連結名字後面多念一句「另開新分頁」；畫面上不加 ↗。這兩個是全站第一批開新分頁的連結，其他對外的連結照舊在原分頁開。
- 版面先在 Claude Design 畫布上畫給使用者選（1280 寬與 390 寬），選定再寫程式。
- 推翻三條之前的決定，理由在 design：`ui-touchups`「網站名稱列由 layout 輸出，每頁一條，放回首頁的連結與「關於這個網站」」不用「關於」的理由（「只寫『關於』容易被讀成『關於作者』」）、`01-day-dispatch-model`「名稱列加「當天調度」入口，選單接在標誌旁邊靠左」的「選單接在標誌旁邊靠左，每一頁都一樣」，以及 `ui-touchups` 的非目標「文章連結不開新分頁、不加外部連結圖示」。
- 當天調度跟著時鐘走：
  - 每到整分鐘，不用調度員按任何東西，這三塊就照新的時刻畫：時間軸的「現在」標記與線、發車表的狀態與現在分隔線、現在停在末站的車與站了幾分鐘。
  - 分頁切回來時馬上畫一次。
  - 焦點在發車表裡（正在選派車或打時刻），或發車表下面正顯示改不成的說明時，發車表先不動，焦點離開才補。
  - 時間軸的條與趟次不會被時鐘重畫，拖拉中、選取的那一趟不受影響。
  - 只在顯示當天時跑，離開頁面時停掉。
- 時間軸的每一趟畫成鳥瞰的公車：
  - 車頭朝右：時間往右走，車頭停在到達的時刻。
  - 有擋風玻璃、後窗、兩側後照鏡，加一點陰影。
  - 兩個方向照舊用深淺分。
  - 換過車與選取的框跟著車身的圓角；圖例的色塊也換成小公車。
  - 段寬不到 36px 不寫發車時刻（原本 26px）。畫布上 251區 的 109 趟，因此有 6 趟不寫（1280 與 390 都是，數過的）。
- 測試：
  - 名稱列：`spec/requests/site_layout_spec.rb` 的連結清單改成三個與五個；`spec/system/route_page_mobile_spec.rb` 加一條，GitHub 連結在手機上不顯示、在寬螢幕上顯示。
  - 時鐘：排「下一個整分鐘」的程式用 Vitest 測；頁面用系統測試換掉頁面的時鐘，看時鐘走到下一分鐘、分頁切回來、焦點在發車表時各怎麼畫。
  - 不寫斷言、由使用者在畫面上確認的：名稱列的靠右、只顯示「關於」、圖示的大小與顏色、兩個對外連結另開新分頁；公車的樣子。

## Non-Goals

- 指標、資料、衍生表一律不動。
- 名稱列不做選單（例如手機上收成一個按鈕）；車牌查詢、回報表單、月報等連結有了再說。
- 不加看得到的 ↗：GitHub 圖示是那個連結本身，「關於」照舊只有字；另開新分頁只用讀螢幕軟體聽得到的一句說明。
- 名稱列以外對外的連結（起點區塊連到《未來城市》、頁尾的出處）照舊在原分頁開。
- 640px 以下顯示 GitHub 連結：否決，縮小標誌、換到第二列、只在首頁顯示都比較過，理由在 design。
- 不連 n-gear 的 repo：n-gear 是獨立的 repo（`../gems/n-gear`），這次只連網站本身。
- 404 頁（`public/404.html`）不加：它不經過網站 layout，沒有名稱列（`site-easter-eggs`「404 頁用靜態的 public/404.html，不經過網站 layout」）。
- 文章連結不換說法：讀螢幕軟體念的照舊是「關於這個網站」，`ui-touchups` 否決過的「設計理念」「緣起」與文章標題照舊不用。
- 不改「現在」怎麼算：`01-day-dispatch-model`「「現在」用瀏覽器的台北時間，跨午夜算成營運日的分鐘」照舊，這次只補上什麼時候照它重畫。
- 不做秒級的更新、倒數或動畫：畫面上的時刻只寫到分鐘。
- 今天的計畫（開始當天之前）不跟時鐘走；頁首的四個數字、修改清單、記下回到時刻的表單不看現在，時鐘不碰。
- 公車不畫車號、輪子或開門；不用車頭朝向分去程與返程（去程朝右、返程朝左）：否決，理由在 design。
- 方案 B（只留車頭）不做；放不下時刻的短趟次不退回方塊。
- 列印不變：時間軸不印，印出來的單子照舊。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `site-layout`: 「Site name bar on every page」：名稱列分成左右兩組，多一個連到 repo 的 GitHub 連結（640px 以下不顯示），文章連結每種寬度都只顯示「關於」，兩個對外的連結另開新分頁。
- `day-dispatch`: 新增「Day dispatch view follows the clock」：顯示當天時，每到整分鐘與分頁切回來時照新的現在畫跟現在有關的部分；焦點在發車表時發車表先不動。

## Impact

- Affected specs: site-layout, day-dispatch
- Affected code:
  - Modified: app/components/site_bar_component.rb, app/components/site_bar_component.html.erb, app/components/site_bar_component.yml, spec/requests/site_layout_spec.rb, spec/system/route_page_mobile_spec.rb, app/frontend/timetable/day_page.js, app/frontend/timetable/day_view.js, app/frontend/timetable/day_timeline_view.js, app/components/day_timeline_component.html.erb, app/components/day_timeline_component.rb, spec/system/timetable_day_spec.rb
  - New: app/frontend/timetable/minute_clock.js, app/frontend/timetable/minute_clock.test.js
  - Removed: (none)
- 畫布：選定的畫板快取在 .spectra/design-cache/site-bar-github-about/
