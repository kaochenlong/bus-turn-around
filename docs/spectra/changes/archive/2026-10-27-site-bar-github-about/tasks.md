## 1. 先畫再寫

- [x] 1.1 照 design「先在畫布畫名稱列，選定再寫程式」：在 Claude Design 畫布上畫名稱列，1280 寬的首頁與路線頁、390 寬的路線頁與首頁（390 寬沒有 GitHub 圖示）；方案 A（GitHub 圖示與「關於」的間距跟其他連結一樣，640px 以上 28px）與方案 B（12px）各一列，圖示 20px，用網站的標誌圖，其他數值照 design Context 列的現有尺寸。給使用者選，選定之後畫板快取到 `.spectra/design-cache/site-bar-github-about/`，用 `/spectra-ingest site-bar-github-about` 把選定的數值寫進 design 的 Design Source。驗證：使用者選定的方案與數值寫進 design（內容檢查）。

## 2. 名稱列

- [x] 2.1 Site name bar on every page 的兩組排法與文章連結的字，照 design「名稱列分兩組：路線的連結接在標誌旁邊，GitHub 與「關於」靠右」、「文章連結每種寬度都只顯示「關於」，讀螢幕軟體照舊念「關於這個網站」」與 Design Source 的名稱列數值：
  - `SiteBarComponent` 的模板把連結分成兩組：班表與當天調度照舊接在標誌旁邊，文章連結推到名稱列右端；兩組之間至少保留 20px（640px 以下）與 28px，首頁就是標誌在左、「關於」在右。
  - 文章連結的後半段從 `max-sm:sr-only` 改成 `sr-only`：每種寬度都只顯示「關於」（en：About），連結文字照舊是「關於這個網站」。
  - `.rb` 的 class 註解、`.html.erb` 與 `.yml` 裡描述舊排法的註解（選單接在標誌旁邊靠左、手機上只顯示「關於」）改成新的排法。

  這是寫死的版面與 class，照 design「測試：連結清單寫在 request spec，手機上不顯示寫在系統測試，排法由使用者看」不寫新的斷言。驗證：`bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/pages_spec.rb` 照樣全綠（連結的順序與文字都沒變）；`bin/rubocop app/components/site_bar_component.rb` 沒有警告；排法與只顯示「關於」由使用者在畫面上確認。[after: 1.1]
- [x] 2.2 Site name bar on every page 的 GitHub 連結，照 design「GitHub 圖示連到 repo，640px 以下不顯示」與 Design Source（方案 A）。先改測試看它們失敗：
  - `spec/requests/site_layout_spec.rb` 的四個名稱列例子改成規格的 Scenario「Bar on the home page」（三個連結：`/`、`SiteBarComponent::REPOSITORY_URL`、`SiteBarComponent::ABOUT_URL`）、「Bar on a route page」（五個連結，第四個連到 repo、文字是 GitHub，第五個連到文章、文字是關於這個網站，都沒有 `aria-current`）、「Bar on a timetable page」與「Bar on a day dispatch page」（五個連結，`aria-current` 照舊在第二、第三個）。
  - `spec/system/route_page_mobile_spec.rb` 加 Scenario「Repository link on a phone」：用這個檔案的 `on_phone`、`on_wide_screen` 與 `displays`，repo 連結在 390 寬的 `display` 是 `none`，在 1400 寬不是。

  再實作：加 `SiteBarComponent::REPOSITORY_URL`；`.yml` 加 `repository`（tw 與 en 都是 GitHub）；右組在文章連結前面放 repo 連結，用 `text_link` 加 `max-sm:hidden` 與 `px-0.5`（圖示 20px 置中，連結寬 24px），右組的間距 26px（`gap-6.5`），畫面上圖示到「關於」的字 28px；連結裡面是 `@primer/octicons@19.42.0` 的 `mark-github-24.svg` 原樣的 path（inline SVG、`aria-hidden="true"`、`size-5 fill-current`）與 `sr-only` 的 GitHub，不加 `target`。驗證：`bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/pages_spec.rb spec/system/route_page_mobile_spec.rb` 全綠，每個例子不超過 5 行；`bin/rubocop app/components/site_bar_component.rb spec/requests/site_layout_spec.rb spec/system/route_page_mobile_spec.rb` 沒有警告；圖示的樣子由使用者在畫面上確認。[after: 2.1]

## 3. 驗收

- [x] 3.1 驗收，照 design「測試：連結清單寫在 request spec，手機上不顯示寫在系統測試，排法由使用者看」：跑 `bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/pages_spec.rb spec/system/route_page_mobile_spec.rb spec/system/buffer_trade_spec.rb spec/system/rest_command_spec.rb spec/system/timetable_edit_spec.rb spec/system/timetable_day_spec.rb spec/system/timetable_print_spec.rb spec/system/timetable_day_record_spec.rb`，對改過的 `.rb` 跑 `bin/rubocop`，最後 `bin/ci`。畫面上的排法由使用者自己確認，不在這個 task。驗證：指令全綠，回報跑了哪些指令與結果。[after: 2.2]

## 4. 當天調度跟著時鐘走

- [x] 4.1 每到整分鐘叫一次的時鐘，照 design「當天調度每到整分鐘照現在重畫，只重畫跟現在有關的三塊」與「測試：時鐘的排程寫 Vitest，時鐘走、切回分頁、焦點在發車表寫系統測試；公車的樣子不寫斷言」：新增 `app/frontend/timetable/minute_clock.js` 的 `startMinuteClock({ now, onMinute })`，照 `now()` 算到下一個整分鐘排一次 `setTimeout`，到了叫 `onMinute()` 再照 `now()` 重排，回傳 `stop()`。先在 `app/frontend/timetable/minute_clock.test.js` 用 Vitest 的假計時器寫測試看它失敗：17:30:40 開始時，20 秒後叫第一次、之前不叫；之後每 60 秒一次；`stop()` 之後不再叫；每次都照 `now()` 重算（17:31:00.250 叫完，下一次在 59.75 秒後）。驗證：`yarn test:js` 全綠。
- [x] 4.2 Day dispatch view follows the clock，照 design「當天調度每到整分鐘照現在重畫，只重畫跟現在有關的三塊」：
  - `app/frontend/timetable/day_timeline_view.js` 加 `moveNow(minutes)`：只更新現在的分鐘數、現在的標記與線、圖例的「現在 HH:MM」，不重畫條與趟次。
  - `app/frontend/timetable/day_view.js` 加 `refreshNow()`：照 `now()` 算現在，跟上次畫的同一分鐘就不動，`render()` 也記下它畫的分鐘；時間軸 `moveNow`；停在末站的車照新的現在畫；發車表沒有走過這一端任何一班的發車時刻時只改分隔線上的「現在 HH:MM」，走過了才重畫列與分隔線，保留捲動位置。焦點在發車表的捲動框裡、或發車表下面有改不成的說明時，發車表整張不動並記下欠一次，捲動框的焦點移到框外時補畫。
  - `app/frontend/timetable/day_page.js`：顯示當天時用 `startMinuteClock({ now: () => this.now(), onMinute: () => this.view.refreshNow() })` 開始時鐘（先停掉舊的），顯示今天的計畫時停掉；`visibilitychange` 變成看得到時立刻 `refreshNow()` 並重排時鐘；`destroy()` 停掉時鐘、拿掉監聽。

  先在 `spec/system/timetable_day_spec.rb` 寫測試看它們失敗，時刻照 9001 的測試資料挑：
  - 規格 Scenario「A minute passes」：把頁面的時鐘換成從某個整分鐘前半秒起、照真實時間走的時鐘，送一次 `visibilitychange` 讓時鐘照它重排；不按任何東西，現在的標記換到下一分鐘，發車表的狀態、現在分隔線與停在末站的車照新的現在畫。
  - 「Page shown again」：時鐘換到別的時刻後送 `visibilitychange`，標記馬上換，不等下一個整分鐘。
  - 「Focus in the departures」：焦點在一班的派車選單時時鐘走過一班：標記換了、發車表沒換、焦點還在；焦點離開發車表後，那一班變成已發車。

  現有的例子裡，用真實時鐘、又會讀發車表或停在末站的車的，改成先 `set_clock`，免得計時器到點時讀到被重畫掉的舊元素（design 的 Risks）。驗證：`yarn test:js` 與 `bundle exec rspec spec/system/timetable_day_spec.rb spec/system/timetable_day_timeline_spec.rb` 全綠，每個例子不超過 5 行；現有的 `set_clock`（換時鐘後按一下目前那一端）照舊能用；對改過的 `.rb` 跑 `bin/rubocop`。[after: 4.1]

## 5. 時間軸畫成鳥瞰公車

- [x] 5.1 時間軸的每一趟畫成鳥瞰的公車，照 design「時間軸的每一趟畫成鳥瞰的公車，車頭朝右」與 Design Source（時間軸的公車）：
  - `DayTimelineComponent` 的趟次 template：車身圓角 `4px 8px 8px 4px` 加陰影；加後窗、擋風玻璃、上下兩個後照鏡（`aria-hidden` 的 span），兩個方向的顏色照 Design Source、用 `data-go-back` 分；發車時刻從左緣 6px 開始；拿掉會把後照鏡切掉的 `overflow-hidden`。
  - 換過車與拖拉時會換走的班的框，圓角 `6px 10px 10px 6px`；選取的框 `10px 14px 14px 10px`。
  - `app/frontend/timetable/day_timeline_view.js` 的 `DEPARTURE_LABEL_PX` 從 26 改成 36。
  - 圖例兩個方向的色塊換成 22×12px 的小公車。

  這是寫死的版面與 class，照 design「測試：時鐘的排程寫 Vitest，時鐘走、切回分頁、焦點在發車表寫系統測試；公車的樣子不寫斷言」不寫新的斷言。驗證：`bundle exec rspec spec/system/timetable_day_timeline_spec.rb spec/components/day_timeline_component_spec.rb spec/system/timetable_day_spec.rb` 全綠。那幾個測試的 `marks` 讀的是趟次的 textContent，加進去的車窗是空的 span，時刻照舊讀得到；要是有例子因為門檻改成 36px 而讀不到時刻，照實回報。公車的樣子由使用者在畫面上確認。[after: 4.2]

## 6. 驗收

- [x] 6.1 驗收，照 design「測試：時鐘的排程寫 Vitest，時鐘走、切回分頁、焦點在發車表寫系統測試；公車的樣子不寫斷言」：跑 `yarn test:js`、`bundle exec rspec spec/system/timetable_day_spec.rb spec/system/timetable_day_timeline_spec.rb spec/components/day_timeline_component_spec.rb spec/system/timetable_day_record_spec.rb spec/system/timetable_print_spec.rb`，對改過的 `.rb` 跑 `bin/rubocop`，最後 `bin/ci`。畫面上的樣子由使用者自己確認，不在這個 task。驗證：指令全綠，回報跑了哪些指令與結果。[after: 4.2, 5.1]

## 7. 名稱列的兩個對外連結另開新分頁

- [x] 7.1 Site name bar on every page 的 GitHub 連結與文章連結另開新分頁，照 design「GitHub 與「關於」另開新分頁，讀螢幕軟體聽得到」，取代 2.2 做的「不加 `target`」：
  - `SiteBarComponent` 的兩個連結加 `target: "_blank"`、`rel: "noopener"`、`aria: { describedby: "site-bar-new-tab" }`。
  - 名稱列裡加一個 `hidden` 的 `<span id="site-bar-new-tab">`，字從 `.yml` 新增的 `new_tab` 讀：tw「另開新分頁」，zh-TW 照舊 `<<: *tw`，en「opens in a new tab」。
  - `.rb` 裡 `ABOUT_URL` 與 `REPOSITORY_URL` 寫著在原分頁開的註解，改成另開新分頁。

  這是寫死的屬性與文案，照 design「測試：連結清單寫在 request spec，手機上不顯示寫在系統測試，排法由使用者看」不寫新的斷言。驗證：`bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/pages_spec.rb spec/system/route_page_mobile_spec.rb` 照樣全綠（`bar_links` 比對的網址、連結文字與 `aria-current` 都沒變）；`bin/rubocop app/components/site_bar_component.rb` 沒有警告；點了會另開新分頁由使用者在畫面上確認。
- [x] 7.2 驗收：跑 `bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/pages_spec.rb spec/system/route_page_mobile_spec.rb spec/system/buffer_trade_spec.rb spec/system/rest_command_spec.rb spec/system/timetable_edit_spec.rb spec/system/timetable_day_spec.rb`，對改過的 `.rb` 跑 `bin/rubocop`，最後 `bin/ci`。畫面上的樣子由使用者自己確認，不在這個 task。驗證：指令全綠，回報跑了哪些指令與結果。[after: 7.1]
