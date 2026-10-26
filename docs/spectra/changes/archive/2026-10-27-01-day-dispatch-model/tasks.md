## 1. 當天調度的模型：瀏覽器端的純函式

- [x] 1.1 Day plan from the laid-out timetable 的快照，照 design「當天的畫面是「開始當天的快照＋依序的修改」算出來的純函式」：新增 `app/frontend/timetable/day.js` 的 `startDay(vehicles, meta)` 與 `currentDay(day)`。快照帶每台車每一趟的方向、發車、到達，`plan` 一台車一筆 `{ vehicle, trips }`，趟次代號是 `"<車號>-<序號>"`，原排是自己那台；`meta`（路線 Id、台北日期、開始的時刻、涵蓋的日子與日型別、百分位數、休息分鐘數、趟次結束在停車端的方向 `stoppingEnds`）原樣帶著；`meta.runTimes`（頁面 JSON 的計畫行駛時間）只留 `basis.percentile` 那一個百分位數存進當天調度，形狀照頁面 JSON，讓 `layout.js` 的 `plan` 直接用；班表頁趟次上的 `edited`、`typed`、`original`、`fallback` 不帶進快照；沒有修改時 `currentDay` 回傳快照的車，每一趟 `plannedVehicle` 是自己、`recorded` 與 `typed` 是 false，頁首數字都是零。先在 `app/frontend/timetable/day.test.js` 寫測試看它失敗：兩台車的快照保留手動打過的 06:45 但不帶 `edited` 與 `typed`、代號在 `currentDay` 前後不變、`meta` 原樣、規格 Scenario「Run times of the day's percentile kept」（p85 開始的當天調度只存 p85 的行駛時間）、不改傳入的陣列。驗證：`yarn test:js` 全綠。
- [x] 1.2 Recording an arrival 與 No trip moves by itself 的模型，照 design「記下回到的時刻，改的是那台車回到這一端的那一趟」與「當天調度不自動移動任何一趟，車還沒回來就標出來」：`recordArrival(day, { vehicle, end, time, reason, at })` 把那台車開往那一端、發車不晚於記下時刻的最後一趟的到達改成記下的時刻並標 `recorded`；找不到這一趟回傳 `{ refused: { kind: "no-trip" } }`；同一趟記第二次以後記的為準。`currentDay` 把前一趟到達晚於發車的那一班標成等車、停留是負數，其他趟次都不動。先在 `app/frontend/timetable/day.test.js` 寫測試看它失敗：規格 Scenario「Recorded arrival replaces the planned one」、「No trip toward that end」、「A late arrival marks the next departure」（17:40 停留 −12）、同一趟記兩次取後面那筆、兩筆都留在修改裡。驗證：`yarn test:js` 全綠。[after: 1.1]
- [x] 1.3 Giving a departure to another vehicle 的模型，照 design「換車是兩台車從那一班起後面的班互換，只在調度員改派車時發生」：`changeVehicle(day, { tripId, vehicle, reason, at })` 把 A 車從那一班起後面的趟次，跟 B 車第一個發車不早於那一班的趟次起後面的趟次互換；前提不成立回傳 `{ refused: { kind: "elsewhere", vehicle, end } }`（B 車接下來從另一端發）或 `{ refused: { kind: "day-ended", vehicle, end } }`（B 車之後沒有班、也不在那一端收班）；移過去的趟次時刻不變、`plannedVehicle` 照舊。先在 `app/frontend/timetable/day.test.js` 寫測試看它失敗：規格 Scenario「Two vehicles exchange the rest of their day」、「Vehicle away from that end」、B 車之後沒有班但最後一趟到那一端時收、沒到那一端時不收、換過去再換回來回到原排。驗證：`yarn test:js` 全綠。[after: 1.1]
- [x] 1.4 Typing a departure in the day dispatch 的模型，照 design「改發車時刻只改那一趟，到達照新的小時重算」：`changeDeparture(day, { tripId, departure, reason, at })` 只改那一趟的發車並標 `typed`；到達用那一趟記下的回到時刻，沒有記下就用當天調度存下的計畫行駛時間（`layout.js` 的 `plan(day.runTimes, day.basis.percentile, …)`）依新發車的小時重算，不接頁面給的行駛時間；其他趟次都不動。先在 `app/frontend/timetable/day.test.js` 寫測試看它失敗：規格 Scenario「Later departure」（18:10 發、19:07 到）、頁面 JSON 的 18 時 p85 是 57 分與 p50 是 60 分而當天用 p85 時到達是 19:07、已經記下回到時刻的那一趟改發車時到達維持記下的、先改發車再記下回到時刻時到達是記下的、改晚之後下一班接不上時標成等車。驗證：`yarn test:js` 全綠。[after: 1.1]
- [x] 1.5 Figures of the day dispatch、Change log and undo of the day dispatch、Departures at an end 與 Vehicles at an end 的模型，照 design「頁首與每台車的數字：只報數字，四小時休息用班表頁同一個算法」、「只有復原上一步，已復原的照樣列著」與「「現在」用瀏覽器的台北時間，跨午夜算成營運日的分鐘」：`currentDay` 回傳 `figures`（換車次數、改過發車的班數、等車的班數、停車端最短的非負停留與它的車和下一班）與每台車的 `credits`（用 `rest_windows.js` 的 `minimumCredit` 算現在的與快照的）；`undoLast(day)` 把最新一筆還有效的修改標成已復原，重算只套還有效的；`departuresAt`、`vehiclesAt`、`arrivingAt` 依呼叫的人給的 `now`（快照那一天的分鐘數）給發車表與旁邊兩塊的列，並給預設端。先在 `app/frontend/timetable/day.test.js` 寫測試看它失敗：規格 Example「251區 vehicles 8 and 10」（43 附 61、35 附 69、最短停留 6 分在 10 號車 17:40 之前、沒有等車的班）、Scenario「Undoing a vehicle change」、「Statuses around now」、「Vehicle that just came back」、「Stopping end listed first」，以及 00:30 的 `now` 算成 1470。驗證：`yarn test:js` 全綠。[after: 1.2, 1.3, 1.4]
- [x] 1.6 Day dispatch kept in this browser 的存法，照 design「存在這台電腦的瀏覽器，伺服器什麼都不收」：新增 `app/frontend/timetable/day_storage.js` 的 `dayKey(routeId, date)`、`saveDay(storage, day)`、`loadDay(storage, routeId, date)`、`discardDay(storage, routeId, date)`；`saveDay` 遇到例外回傳 false；`loadDay` 存著、讀得出來時回傳 `{ day }`，存著的不是 JSON 或格式版本不是 1 時回傳 `{ unreadable: true }`，沒有存或讀 storage 丟例外時回傳 null。先在 `app/frontend/timetable/day_storage.test.js` 用假的 storage 寫測試看它失敗：鍵是 `turnaround.day-dispatch.v1.<路線 Id>.<YYYY-MM-DD>`、存了讀得回 `{ day }` 同一個當天調度、`setItem` 丟例外時回傳 false、壞掉的與版本 2 的讀成 `{ unreadable: true }`、沒有存的與 `getItem` 丟例外的讀成 null、`discardDay` 之後讀成 null。驗證：`yarn test:js` 全綠。[after: 1.1]

## 2. 班表頁上的當天調度

- [x] 2.1 當天調度畫面的 template 與文案，照 design「當天調度做在班表頁裡，跟排班共用一頁」與「一端的發車表先做，時間軸主畫面在 02」：新增 `DayDispatchComponent`（`app/components/day_dispatch_component.rb`、`.html.erb`、`.yml`，tw 與 en），輸出排班時藏著的當天調度區塊：頁首（路線、日期、計畫依據、回到排班、重新開始、四個數字的位置）、兩端各一個選端按鈕（帶方向與起站名）、發車表的列 template、現在在這一端的車、接下來會回到的車、每台車的四小時休息、記下回到時刻的表單（車、時刻、原因）、修改清單與復原上一步、存不了時的說明，每一塊帶瀏覽器要找的 data 屬性；放進 `app/views/timetables/show.html.erb`。數值照 design 的 Design Source。先在 `spec/components/day_dispatch_component_spec.rb` 寫測試看它失敗：兩個選端按鈕各帶自己的方向與站名、表單三個欄位都有 label、區塊預設藏著、輸出裡沒有任何 `BusID`。驗證：`bundle exec rspec spec/components/day_dispatch_component_spec.rb` 全綠；tw 與 en 的文案做內容檢查。
- [x] 2.2 Starting the day dispatch 與 Day plan from the laid-out timetable 在頁面上，照 design「當天調度做在班表頁裡，跟排班共用一頁」與「「現在」用瀏覽器的台北時間，跨午夜算成營運日的分鐘」：班表頁單子鋪好之後顯示「開始當天」（印的時候藏著）；按下去用台北日期與頁面 JSON 的 `runTimes` `startDay`、`saveDay`，同一頁換成當天調度；打開時這台電腦有這條路線今天或昨天的當天調度，就問要不要繼續；存著的讀不出來（`loadDay` 回 `{ unreadable: true }`）時當成沒有，在開始當天旁邊說明一句；「回到排班」保留它，「重新開始」問過之後 `discardDay`。時鐘由元件裡一個可以替換的函式給，系統測試在頁面上覆寫它。先在 `spec/requests/timetables_spec.rb` 加「單子的頁面帶開始當天的控制項，印的時候藏著」，在新增的 `spec/system/timetable_day_spec.rb` 寫：開始當天之後看得到當天調度與計畫依據、重新整理之後問要不要繼續、繼續之後回到同一天、回到排班再繼續還在、重新開始問過之後不見、規格 Scenario「Kept day that cannot be read」（存著壞掉的內容時不問要不要繼續、說明一句）；都先看它失敗。驗證：`bundle exec rspec spec/requests/timetables_spec.rb spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行。[after: 1.6, 2.1]
- [x] 2.3 Departures at an end、Vehicles at an end、Figures of the day dispatch 與 No vehicle identifiers from the data in the day dispatch 在頁面上：新增 `app/frontend/timetable/day_view.js`，把 `currentDay`、`departuresAt`、`vehiclesAt`、`arrivingAt` 畫進 2.1 的 template；選端可以切換；頁首四個數字、每台車的四小時休息與快照的數字；車只用單子上的車號。先在 `spec/system/timetable_day_spec.rb` 寫測試看它失敗：開始當天、把時鐘設在兩班之間，發車表的狀態依序是已發車、下一班、照計畫；預設列出停車那一端；切到另一端列出另一個方向的班；剛回來的車列在現在在這一端、停了幾分；頁面上沒有 `BusID`。驗證：`bundle exec rspec spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行。[after: 1.5, 2.2]
- [x] 2.4 Recording an arrival、Giving a departure to another vehicle 與 Typing a departure in the day dispatch 在頁面上：表單記下回到的時刻、派車那一格的選單換車、發車那一格打時刻，都經過 `day.js` 之後 `saveDay`、重畫；收不了、前提不成立、時刻讀不出來時，照 design Implementation Contract 的失敗樣子在那一格或表單旁說明，修改清單不加。先在 `spec/system/timetable_day_spec.rb` 寫測試看它失敗：記下晚回之後下一班標成車還沒回來；派給在這一端的車之後兩台後面的班互換、標出原排；派給不在這一端的車被拒絕並說它接下來從哪一端發；發車打 18:70 被退回並列出接受的寫法；打合法的時刻之後到達重算；規格 Scenario「Run times kept from the start」（開始當天之後換一個涵蓋日子行駛時間不同的網址繼續，打的時刻到達照開始時存下的算）。驗證：`bundle exec rspec spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行。[after: 2.3]
- [x] 2.5 Change log and undo of the day dispatch 與 Day dispatch kept in this browser 存不了的樣子在頁面上：修改清單依序列出每一筆的記下時刻（台北時間）、內容、原因，已復原的標出來；「復原上一步」；`localStorage` 寫不進去時頁面說這一天沒有存在這台電腦，修改照樣生效。先在 `spec/system/timetable_day_spec.rb` 寫測試看它失敗：三筆修改依序列出；復原上一步之後最新那筆標成已復原、畫面回到那筆之前；之後再改的一筆接在後面；在頁面上讓 `localStorage.setItem` 丟例外，出現說明、改的照樣看得到。驗證：`bundle exec rspec spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行。[after: 2.4]

## 3. 文件與驗收

- [x] 3.1 詞彙與文件跟上新的行為：`docs/spectra/LANGUAGE.md` 新增「換車」與「當天調度」兩條（定義、在資料或程式碼裡、邊界、不要用），換車寫成從那一班起兩台車後面的班互換、只在調度員改派車時發生；`docs/use-cases.md`「不會被用的場景」裡的「即時調度：我們是每晚批次，晚一天。」改寫成資料仍然晚一天，但班表頁可以在當天記下晚回、換車；`README.md` 班表頁那段補一句當天調度，「伺服器只給量到的資料，什麼都不存」照舊成立。驗證：內容檢查，寫法跟 design「換車是兩台車從那一班起後面的班互換，只在調度員改派車時發生」與「存在這台電腦的瀏覽器，伺服器什麼都不收」一致。
- [x] 3.2 驗收，照 design「測試：模型寫 Vitest，頁面寫系統測試，畫面截圖給使用者看」：跑 `yarn test:js`、`bundle exec rspec spec/system/timetable_day_spec.rb spec/components/day_dispatch_component_spec.rb spec/requests/timetables_spec.rb`、對改過的 `.rb` 跑 `bin/rubocop`，最後 `bin/ci`。在 `bin/dev` 上開 251區 的班表頁，照 design Design Source 的情境走一次（8 號車 17:52 回到福安居一、17:40 那班派給 10 號車），1280px 與 390px 寬各截一張，看得到發車表、頁首數字、四小時休息與修改清單，交給使用者看。驗證：指令全綠，截圖交給使用者。[after: 2.5, 3.1]

## 4. 名稱列的「當天調度」入口

- [x] 4.1 Site name bar on every page 的「當天調度」連結與排法，照 design「名稱列加「當天調度」入口，選單接在標誌旁邊靠左」與 Design Source 名稱列的數值：`SiteBarComponent` 有 `timetable_route_id` 時，在「班表」（`data-timetable-link`）後面輸出「當天調度」（`data-day-dispatch-link`，連到 `route_timetable_path(id, anchor: "day-dispatch")`，文案 tw 與 en）；兩個連結的字色改用 `aria-current` 選擇器；選單接在標誌旁邊靠左；「關於這個網站」拆成「關於」與「這個網站」兩段，後一段在 640px 以下是 `sr-only`，連結文字照舊是「關於這個網站」。先在 `spec/requests/site_layout_spec.rb` 改測試看它失敗：規格 Scenario「Bar on a route page」（四個連結，第三個連到 `/routes/9001/timetable#day-dispatch`、文字是當天調度、沒有 `aria-current`）、「Bar on a timetable page」（第二個帶 `aria-current="page"`、第三個沒有）、「Bar on the home page」照舊兩個連結，關於那個連結的文字照舊是關於這個網站。選單靠左與 640px 以下只顯示「關於」是畫面上的排法，在 4.3 截圖對照畫布。驗證：`bundle exec rspec spec/requests/site_layout_spec.rb` 全綠；對改過的 `.rb` 跑 `bin/rubocop`。
- [x] 4.2 Opening the day dispatch from the site name bar 在班表頁：`app/frontend/timetable/component.js` 加 `openDayDispatch()`，這台電腦存著今天（沒有就昨天）讀得出來的當天調度就 `showDay`，沒有就 `showPlanning` 之後把「開始當天」捲進畫面、焦點放在它的按鈕上；`init` 讀到網址的 `#day-dispatch` 時先用 `history.replaceState` 拿掉再呼叫；名稱列的 `[data-day-dispatch-link]` 被點時 `preventDefault` 之後呼叫，不換頁；`showDay` 與 `showPlanning` 把 `aria-current="page"` 在「當天調度」與「班表」之間移動。先在 `spec/system/timetable_day_spec.rb` 寫測試看它失敗：規格 Scenario「Kept day opened from the route page」（從路線頁按當天調度，存著的一天直接顯示，當天調度帶 `aria-current`，網址沒有 `#day-dispatch`）、「No day kept yet」（焦點在開始當天的按鈕上，按鈕在畫面裡）、「Link on the timetable page keeps the sheets」（`day=2026-10-19`、`range=7d` 開的班表頁把 06:00 打成 06:10 之後按當天調度，網址參數與 06:10 都還在，焦點在開始當天的按鈕上）、「Back to planning moves the mark」。驗證：`bundle exec rspec spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行。[after: 4.1]
- [x] 4.3 文件與驗收：`docs/spectra/LANGUAGE.md`「當天調度」那條寫進入口（名稱列的「當天調度」與班表頁的「開始當天」），README.md 班表頁那段補一句名稱列的「當天調度」；跑 `yarn test:js`、`bundle exec rspec spec/requests/site_layout_spec.rb spec/system/timetable_day_spec.rb`、對改過的 `.rb` 跑 `bin/rubocop`，最後 `bin/ci`；在 `bin/dev` 上截首頁、路線頁、班表頁（排班時與當天調度時）的名稱列，1280、390、360 寬，對照 design Design Source 名稱列的數值：選單接在標誌旁邊靠左、640px 以下只顯示「關於」、360 寬不折行，交給使用者看。驗證：指令全綠，截圖交給使用者。[after: 4.2]


## 5. 當天調度另開一頁

- [x] 5.1 Day dispatch page 的伺服器端，先跟班表頁裡的當天調度並存，照 design「當天調度另開一頁，開始當天留在班表頁」：
  - `config/routes.rb` 加 `GET /routes/:route_id/dispatch`（`route_dispatch`）。
  - 新的 `DayDispatchesController#show`：路線不在清單就 `render_not_found`；設 `@timetable_route_id`；有資料時路線名稱與兩端站名用 `RoutePage::Coverage` 加 `RoutePage::Timetable`，沒有資料時都空。
  - 新的 `app/views/day_dispatches/show.html.erb`：底色、文件標題、需要 JavaScript 那一句、`x-data="dayDispatch"`。
  - `DayDispatchComponent` 改收 `route_id:`、`route_name:`、`stop_names:`，「回到排班」改成連結；班表頁照新參數放它，班表頁上點它照舊回到排班、不換頁。
  - 「隔日」與打不出來的時刻那三句，從 `app/components/timetable_sheet_component.yml` 搬到 `config/locales`，兩個元件都讀那裡。

  先寫測試看它失敗：
  - 新的 `spec/requests/day_dispatches_spec.rb`：規格 Scenario「Route not configured」；9001 回 200，帶藏著的當天調度區塊與需要 JavaScript 那一句；沒有資料也 200；頁面上沒有 `BusID`。
  - `spec/components/day_dispatch_component_spec.rb` 改參數，補路線名稱為 nil、站名為空的情況。
  - 讀共用字的 `spec/components/timetable_sheet_component_spec.rb`、`spec/system/timetable_edit_spec.rb` 與 `spec/system/timetable_day_spec.rb` 改讀新的位置。

  驗證：上面的 spec 全綠，既有的班表頁系統測試照舊全綠；對改過的 `.rb` 跑 `bin/rubocop`。
- [x] 5.2 Day dispatch page 的瀏覽器端，照 design「當天調度另開一頁，開始當天留在班表頁」：
  - 新的 `app/frontend/timetable/day_page.js`（Alpine `dayDispatch`，在 `app/frontend/entrypoints/application.js` 註冊）：顯示這台電腦存著的那一天（今天，沒有就昨天），或同一分頁交接的那一天；都沒有就 `Turbo.visit` 班表頁的 `#day-dispatch`（`action: "replace"`）。
  - 回到排班的連結照那一天的計畫依據填。重新開始：問過之後 `discardDay`、清掉交接、回到班表頁。
  - 新的 `app/frontend/timetable/day_handoff.js`：存不進這台電腦的那一天，整個分頁留著。

  先寫測試看它失敗：
  - 新的 `app/frontend/timetable/day_handoff.test.js`：交了取得到、不同路線取不到、清掉之後取不到、再交就換掉。
  - `spec/system/timetable_day_spec.rb` 加直接打開當天調度頁的例子：規格 Scenario「Kept day on its own page」、「Nothing kept」、「Back to planning on the day's basis」；存著的讀不出來時回到班表頁、看得到那一句；重新開始的確定與取消。

  驗證：`yarn test:js` 與 `bundle exec rspec spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行。[after: 5.1]
- [x] 5.3 班表頁開始當天之後換到當天調度頁，照 design「當天調度另開一頁，開始當天留在班表頁」。這一項取代 2.2 的同一頁切換：
  - `app/frontend/timetable/component.js` 開始當天時 `startDay`、`saveDay`，存成就清掉交接、存不成就交給 `day_handoff.js`，然後 `Turbo.visit` 當天調度頁。
  - 要繼續的那一天：這個分頁交過來的那一天，沒有就是存著讀得出來的（今天，沒有就昨天）。問要不要繼續、名稱列的入口、再按開始當天先問，都看它；交過來的那一天，問的那一句說它沒有存在這台電腦（`timetables.show.day_start.handed`，再按開始當天問的是 `handed_replace_confirm`）。
  - `app/frontend/timetable/day_page.js` 改成先看交接、再看存著的，取代 5.2 寫的先看存著的（理由見 design「當天調度另開一頁，開始當天留在班表頁」）。
  - 「繼續這一天」改成連到當天調度頁。
  - 當天調度頁的 head 帶 `turbo-cache-control` 的 `no-preview`：換過來時不先閃一下快取裡的上一天（design 的 Risks）。
  - 名稱列的「當天調度」在班表頁上：有要繼續的那一天就換到當天調度頁，沒有就照舊捲到開始當天、聚焦按鈕。
  - 拿掉 `showDay`、`markCurrent`、`dayView` 的使用，以及班表頁裡的 `DayDispatchComponent`；開始當天要的路線 Id、涵蓋日子與日型別改放開始當天那一塊。

  先改測試看它失敗：
  - `spec/requests/timetables_spec.rb`：班表頁不再有當天調度區塊，開始當天那一塊帶路線 Id、涵蓋日子與日型別。
  - `spec/requests/day_dispatches_spec.rb`：當天調度頁帶 `no-preview`。
  - `spec/system/timetable_day_spec.rb` 改成兩頁的流程：
    - 開始當天換到當天調度頁，重新整理還在。
    - 規格 Scenario「Offer to continue a kept day」：繼續換到當天調度頁。
    - 規格 Scenario「Day that could not be kept」：存不進去時交得過去、回到排班再進來還在、重新整理就回班表頁。
    - 規格 Scenario「Offer to continue a day that could not be kept」、「Tab's day newer than the kept one」；交過來的今天那一天在時再按開始當天，先問。
    - 離開當天調度頁再按上一頁，照樣顯示那一天。
    - 今天已經存著一天時再按開始當天，先問。
    - 同一頁切換的舊例子刪掉或改寫。

  驗證：`bundle exec rspec spec/requests/timetables_spec.rb spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行；對改過的 `.rb` 跑 `bin/rubocop`。[after: 5.2]
- [x] 5.4 Site name bar on every page 的「當天調度」連到當天調度頁，照 design「名稱列加「當天調度」入口，選單接在標誌旁邊靠左」。這一項取代 4.1 連到 `#day-dispatch`，以及 4.2 由瀏覽器搬標記的做法：
  - `SiteBarComponent` 改收 `current:`，「當天調度」連到 `route_dispatch_path(id)`、在當天調度頁上帶 `aria-current`；layout 傳 `@site_bar_current`，兩個控制器各自設。
  - `app/frontend/timetable/component.js` 的名稱列入口：有要繼續的那一天（交接的，或存著讀得出來的）就照連結走，沒有就攔下來、捲到開始當天、聚焦按鈕。

  先改測試看它失敗：
  - `spec/requests/site_layout_spec.rb`：規格 Scenario「Bar on a route page」、「Bar on a timetable page」、「Bar on a day dispatch page」。
  - `spec/system/timetable_day_spec.rb`：規格 Scenario「Kept day opened from the route page」、「No day kept yet」、「Link on the timetable page keeps the sheets」；搬標記的舊例子刪掉。

  驗證：`bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/day_dispatches_spec.rb spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行；對改過的 `.rb` 跑 `bin/rubocop`。[after: 5.3]
- [x] 5.5 文件與驗收：
  - README.md、`docs/use-cases.md` 與 `docs/spectra/LANGUAGE.md`「班表」那條的「唯一要 JavaScript 的頁」改成班表頁與當天調度頁兩頁；`docs/use-cases.md` 的非目標「即時調度」那句改成在當天調度頁記下；LANGUAGE.md「當天調度」那條寫 `/routes/<Id>/dispatch` 與入口。
  - 跑 `yarn test:js`、`bin/rubocop`，最後 `bin/ci`。
  - 在 `bin/dev` 上截班表頁（沒有當天調度區塊）與當天調度頁，1280、390 寬，截完關掉伺服器，交給使用者看。

  驗證：指令全綠，截圖交給使用者。[after: 5.4]

## 6. 當天調度頁自己開始，班表頁只排班

- [x] 6.1 Today's plan on the day dispatch page 的伺服器端，先跟班表頁的開始當天並存，照 design「當天調度頁自己開始，班表頁只排班」與 Design Source「當天調度頁還沒開始」：
  - 新的 `RoutePage::DispatchPlan`（`app/models/route_page/dispatch_plan.rb`）：`RoutePage::DispatchPlan.day_type(type, today)` 照 `type` 或 `today` 是星期幾決定日型別，不認得的 `type` 丟 `RoutePage::Coverage::InvalidParameter`；`#coverage` 是那個日型別最新一天、`range` 為 `7d` 的 `RoutePage::Coverage`，沒有那個日型別的資料時是 nil。
  - `DayDispatchesController#show` 讀 `type`、`p`、`buffer`，不收的值回 400；有計畫時用那份涵蓋與 `p`、`buffer` 建 `RoutePage::Timetable`，把 `#data` 嵌進 `script[data-plan-data]`，路線名稱與兩端站名取它；沒有計畫時照舊取最新一天。
  - 新的 `DayStartComponent`（`app/components/day_start_component.rb`、`.html.erb`、`.yml`，tw 與 en）：今天的計畫的頁首與卡片，伺服器輸出時整塊藏著；「今天是」是 `name="type"` 的 GET 表單選單，百分位數與休息的欄位照班表頁的選項與範圍；鋪成幾台車、昨天那一句與「繼續那一天」、讀不出來那一句留位子給瀏覽器填；沒有計畫時是「這條路線還沒有<日型別>的資料，鋪不出今天的計畫。」，沒有百分位數、休息與開始當天。放進 `app/views/day_dispatches/show.html.erb`。

  先寫測試看它失敗：
  - 新的 `spec/models/route_page/dispatch_plan_spec.rb`：規格 Scenario「Day type from the day of the week」（2026-10-31 星期六是 `holiday`，2026-10-26 星期一是 `weekday`）；`type` 優先於星期幾；不認得的 `type` 丟例外；涵蓋的日子是那個日型別最新一天往前 7 天內同類型的；沒有那個日型別的資料時沒有計畫。
  - `spec/requests/day_dispatches_spec.rb`：規格 Scenario「Unknown day type」；`p`、`buffer` 不收的值回 400；有計畫時嵌了資料、寫出涵蓋的日子；`p`、`buffer` 是控制項的值；`type=holiday` 而 9001 沒有假日資料時有那一句、沒有開始當天。
  - 新的 `spec/components/day_start_component_spec.rb`：整塊藏著；三個控制項的選項與選中的值；依據寫出涵蓋的日子與日型別；沒有計畫時的那一句。

  驗證：上面的 spec 全綠；既有的系統測試照舊全綠（班表頁的開始當天還在）；對改過的 `.rb` 跑 `bin/rubocop`。
- [x] 6.2 Today's plan on the day dispatch page 在瀏覽器上，從當天調度頁開始當天，照 design「當天調度頁自己開始，班表頁只排班」。這一項取代 5.2 寫的「都沒有就換到班表頁」：
  - `app/frontend/timetable/layout.js` 新增 `holdsFor(data, buffer)`；`app/frontend/timetable/component.js` 改用它，班表頁鋪出來的單子不變。
  - `app/frontend/timetable/day_page.js`：交接的、今天存著的都沒有時打開今天的計畫，用 `layOut` 加 `holdsFor` 照百分位數與休息鋪，填鋪成幾台車與兩端各發幾班；百分位數或休息一改就重算，範圍外或讀不出來的值照班表頁退回；「今天是」一換就 `Turbo.visit` 帶 `type`、`p`、`buffer` 的當天調度頁；存著昨天讀得出來的那一天時說一句並給「繼續那一天」；存著的讀不出來時說一句；「開始當天」用鋪好的車 `startDay`，`saveDay` 存成就清掉交接、存不成就交給 `day_handoff.js`，同一頁顯示那一天。不再換到班表頁。

  先寫測試看它失敗：
  - `app/frontend/timetable/layout.test.js` 加 `holdsFor`：停車端是休息分鐘數，非停車端是資料的停留。
  - `spec/system/timetable_day_spec.rb`：規格 Scenario「Today's plan before starting」（4 台車、甲站 3 班、乙站 3 班）、「Nothing kept」、「Starting the day」、「Previous day offered」、「No stored day of the selected type」、「Kept day that cannot be read」；休息改成 0 時鋪成幾台車跟著變、頁面沒有重新載入。直接打開當天調度頁時網址帶 `type=weekday`，星期六日跑也有計畫；`start_day` 改成在當天調度頁開始，記下回到時刻、換車、改時刻、復原那些例子照舊通過。

  驗證：`yarn test:js` 與 `bundle exec rspec spec/system/timetable_day_spec.rb` 全綠，每個例子不超過 5 行。[after: 6.1]
- [x] 6.3 當天調度頁的「重新開始」與「計畫的班表」，以及從當天調度頁開始時存不進去的交接，照 design「當天調度頁自己開始，班表頁只排班」。這一項取代 5.2 寫的「重新開始回到班表頁」與「回到排班」：
  - 「重新開始」問過之後 `discardDay`、清掉交接，同一頁回到今天的計畫；按取消就留著那一天。
  - 「回到排班」改名「計畫的班表」：`DayDispatchComponent` 的文案（tw 與 en）與 `a[data-back]` 改成 `a[data-plan-timetable]`，連結照舊照那一天的計畫依據填。
  - 存不進這台電腦時，從當天調度頁開始的那一天交給 `day_handoff.js`：離開到班表頁再回來還在，重新整理就是今天的計畫。

  先改測試看它失敗：
  - `spec/system/timetable_day_spec.rb`：規格 Scenario「Starting again」、「Plan's timetable on the day's basis」、「Day that could not be kept」、「Tab's day newer than the kept one」改成在當天調度頁開始、離開到班表頁再回來。
  - `spec/components/day_dispatch_component_spec.rb`：連結是「計畫的班表」，連到班表頁。

  驗證：`bundle exec rspec spec/system/timetable_day_spec.rb spec/components/day_dispatch_component_spec.rb` 全綠，每個例子不超過 5 行；對改過的 `.rb` 跑 `bin/rubocop`。[after: 6.2]
- [x] 6.4 班表頁只排班，照 design「當天調度頁自己開始，班表頁只排班」。這一項取代 5.3 的班表頁開始當天、繼續與交過來的那一天，以及 5.4 的名稱列攔截：
  - `app/views/timetables/show.html.erb` 拿掉開始當天那一塊（`data-day-start`）。
  - `app/frontend/timetable/component.js` 拿掉開始當天、要繼續的那一天、名稱列的攔截與 `#day-dispatch`，以及只為它們用的 import 與方法。
  - `config/locales/tw.yml`、`config/locales/en.yml` 拿掉 `timetables.show.day_start`。

  先改測試看它失敗：
  - `spec/requests/timetables_spec.rb`：班表頁沒有 `[data-day-start]`、沒有當天調度區塊。
  - `spec/system/timetable_day_spec.rb`：拿掉從班表頁開始、繼續、交過來的那一天、名稱列攔截的例子；加「在班表頁按名稱列的當天調度，換到當天調度頁、看到今天的計畫」。

  驗證：`bundle exec rspec spec/requests/timetables_spec.rb spec/system/timetable_day_spec.rb spec/system/timetable_edit_spec.rb spec/system/timetable_print_spec.rb spec/system/timetable_layout_spec.rb spec/system/timetable_entry_spec.rb` 全綠；對改過的 `.rb` 跑 `bin/rubocop`。[after: 6.3]
- [x] 6.5 文件與驗收：
  - README.md、`docs/use-cases.md`、`docs/spectra/LANGUAGE.md`：開始當天在當天調度頁，用量到的資料鋪今天的計畫（日型別預設照星期幾、可以換，百分位數與休息可以選）；班表頁只排班。
  - 跑 `yarn test:js`、`bin/rubocop`，最後 `bin/ci`。
  - 在 `bin/dev` 上截當天調度頁還沒開始（251區，對照 Design Source「當天調度頁還沒開始」的數值）與開始之後，以及班表頁，1280、390 寬，交給使用者看；截完關掉自己開的伺服器，別人開的不動。

  驗證：指令全綠，截圖交給使用者。[after: 6.4]
