## Context

路線頁已經有換休息試算（`RoutePage::BufferTrade`）、行駛時間（`RoutePage::RunTimes`，按方向與發車小時給 p50、p85、p95）、折返停留（`RoutePage::LayoverStats`）、兩端性質（`RoutePage.ends`，讀 `config/route_page.yml`）與涵蓋日子（`RoutePage::Coverage`，`day` 與 `range` 參數）。這些都在請求時從衍生表 `trips`、`layovers`、`route_day_stops` 用 SQL 算，`docs/decisions.md` 第 2 條定了 Rails 只查衍生表。

站長與調度員每天在行車憑單上一車一張手寫每個車次幾點發車（使用場景 1 與 11）。2026-10-25 查過靜態快照：四條有路線頁的路線裡，中山幹線、307、251區 公佈的是班距範圍，251 與 307西藏三民 有定時發車表；「業者機動預排班表」每天約 70 到 98 條路線、超過一半每天不同，但這四條都不在裡面。`run-time-vs-cycle` 的非目標記了一個還沒查的差距：中山幹線 07 時公佈 4 到 6 分一班，量到的每小時 5 班。

這個 change 新增「班表」頁：用量到的行駛時間百分位數、調度員選的休息分鐘數與每小時發車數，鋪出一車一張的班表，可列印、可手動微調，伺服器不存。它重開一條記過的非目標，範圍寫在下面的決定裡。

2026-10-25 apply 做到 13/15 時使用者改了兩個決定：這個工具叫「班表」、不叫「草稿」；鋪排與手動微調都在瀏覽器算，伺服器只給量到的資料。被取代的兩條決定留在下面當紀錄，各自標了由哪一條取代；已經寫好的伺服器端微調、Ruby 鋪排與四小時視窗由 tasks 第 7 組拆掉。

## Goals / Non-Goals

**Goals:**

- 調度員在路線頁點一個連結，三十秒內拿到一份能印的一車一張班表，欄位跟手上的行車憑單對得起來。
- 班表上每一個數字都說得出來源：量到的百分位數、調度員選的參數、或照規則鋪出來的時刻。
- 鋪排、四小時休息、微調只有一份實作（瀏覽器端的 JavaScript），規格裡的數字例子直接當單元測試。
- 不新增資料表、不改 `analysis/`、不碰正式站的資料。

**Non-Goals:**

- 駕駛的班（職號、姓名、工時、輪休）；全網或多路線一起排；任何目標函數或最佳化。
- 讀公佈的班距與定時班表當預設；班表對照（脫班、班距達成）另開 change。
- 儲存班表、帳號、檔案下載再上傳、分享改過的班表；把發車數或手動改的格子放進網址。
- 沒有 JavaScript 也鋪得出班表。
- 延誤傳遞的模擬；換休息試算現有的數字、定義與介面。
- 伺服器端產 PDF。
- 把四小時休息的數字標成合規或不合規、用顏色標好壞。
- 把量到的班次串、歸零檢查、資料品質數字搬上頁面。
- 首頁的名稱列加連結、名稱列做選單。

## Decisions

### 重開「排班、班表產生」只到單一路線、單一天、一車一張的班表

**Supersedes**: zhongshan-buffer-trade / 駕駛工時、排班、班表產生。資料看得到車看不到人，雙班制下一台車兩人開；全網排班最佳化是專案的非目標。

使用者 2026-10-25 拍板：網站可以產生班表，前提是準不準不是重點，要不要照著發是調度員的事。重開的範圍只有「一條路線、一天、一車一張的班表」。被取代那條非目標記的理由「資料看得到車看不到人，雙班制下一台車兩人開」照舊成立，所以單子上的職號、姓名、調度員欄留白，四小時休息的數字標明「若一人開完這張單」；「全網排班最佳化是專案的非目標」也照舊成立，班表只照固定規則鋪一次，沒有目標函數。同一個 change 的另一條非目標「駕駛工時、排班、班表產生；門檻與合規標示」裡的門檻與合規標示不重開。`docs/use-cases.md` 第 11 項的「班表也還是站長排的，這套系統不發班表」改寫成「網站鋪得出一車一張的班表，要不要照著發是站長的事」。

理由：background.md 第 37、54、148 行把這個專案定位成陽明交大排班研究的輸入端，那是整數規劃的最佳化模型；這裡做的是調度員每天手填那張紙，用的就是頁面上已有的百分位數，兩者不重疊。

替代方案：維持非目標、只印一頁數字給調度員自己排（使用者否決，他要的是能直接改的班表）。

### 叫「班表」，工具不替自己貼草稿標籤

使用者 2026-10-25 拍板：介面、文件、規格與程式碼都不用「草稿」這個字。功能與頁面叫「班表」，名稱列的連結與文件標題也是「班表」；頁首不寫「草稿，不是定稿」這類替這張表定位的話，但照樣寫出用了哪個百分位數、休息幾分、每小時幾班，讓看的人知道這張表是怎麼鋪的；「手動改過 N 處」保留。他的話：「這是工具，用的人會不會把它拿去當正式是他們的事，沒必要在這時候就說自己是草稿。」

跟著改的名稱：capability 叫 `timetable`，網址 `/routes/:route_id/timetable`、路由 helper `route_timetable_path`，類別 `RoutePage::Timetable`、`RoutePage::TimetableOverruns`，元件 `TimetableHeaderComponent`、`TimetableSheetComponent`、`TimetableOverrunTableComponent`、`TimetableLimitationsComponent`，控制器 `TimetablesController`、view `timetables/show`，spec 檔與 data 屬性（`data-timetable`、`data-timetable-header`、`data-timetable-data`）一律不用 Draft。change 的目錄名 `timetable-draft` 是歷史，不改。詞彙表的條目叫「班表」，「草稿」「試算單」進不要用。

理由：工具的定位由使用者決定，不是工具自己標；資料限制照寫，但不自貶。

替代方案：只改介面文案、程式碼留 Draft（否決：詞彙表「在程式碼裡」那一行會對不上，而且什麼都還沒 commit，改名沒有成本）。

### 預設發車數取量到的每小時發車數，不讀公佈的班距

每個方向每個台北小時的預設發車數，是涵蓋日子裡 `trips` 在那個方向、起點落在那個小時的趟次數除以涵蓋天數，四捨五入到整數（`RoutePage::MeasuredDepartures`）。所有趟次都算，不只完整趟次。調度員可以在頁面上改任何一格，0 表示那一小時不發車；改了立刻重新鋪排。

理由：公佈的尖峰班距 4 到 6 分換算每小時 10 到 15 班，中山幹線 07 時量到的是 5 班，原因還沒查（`run-time-vs-cycle` 的非目標）。預設讀公佈班距會排出業者實際兩到三倍的車，第一張印出來就不可信；取量到的發車數，班表的起點是「今天這樣跑，加上休息要幾台車」，正是這個網站要講的事。不讀靜態快照也守住 Rails 只查衍生表。

替代方案：讀 `GetSemiTimeTable.gz` 的班距（要新衍生表，而且差距沒查清楚，否決）；用班距而不是每小時班數當輸入（調度員講的是「這小時發幾班」，而且 60 除以班距會有小數，否決）。

### 計畫行駛時間取可選的百分位數，樣本少退回全天

網址參數 `p` 是 50、55、…、95 之一，預設 85，是頁面載入時的初始值；之後在頁面上換。一趟的計畫行駛時間是 `RoutePage::PlannedRunTimes` 算的：涵蓋日子裡該方向、該發車小時有行駛時間的趟次（定義同 `run-time`：完整、起訖都量到端點）的第 p 百分位數，`percentile_cont` 線性內插，四捨五入到整分鐘。那一小時的趟次少於 `RoutePage::RunTimes::SMALL_SAMPLE`（5）時，改用該方向全部小時合起來的第 p 百分位數，並記下這一趟用了全天的值，單子上標出來。伺服器一次算好全部十個百分位數、兩個方向、24 個小時的值與退回標記，寫進頁面的資料裡，瀏覽器換 p 時只查表、不重算。該方向一趟有行駛時間的都沒有時，班表鋪不出來，頁面寫出是哪個方向沒有。

理由：預設 85 是因為路線頁 p85 已經是粗體那一欄、使用場景 11 的駕駛講的是 p85、background.md 引的 Furth 與 Muller「平均加一個標準差」約是 p84。可選是因為選百分位數就是在選休息多常被吃掉，這件事在超時比例表上直接讓調度員看到。退回全天是因為 2 趟的 p95 沒有意義，而頁面本來就用 5 當樣本少的門檻。

替代方案：固定 p85（使用者要能選，否決）；樣本少時退回同時段（時段的起訖只寫在 `analysis/params.sql`，`zhongshan-buffer-trade` 的決定已經為了這個理由選小時不選時段，否決）。

### 兩端的停留：停車端停滿休息分鐘數，直接折返端停量到的中位數

一趟到達那一端之後，車要停多久才能接下一趟：那一端是停車端（`turnaround-ends`）時停 `buffer` 分鐘（0 到 20，預設 15，驗證沿用 `RoutePage::BufferTrade.minutes`）；是直接折返端時停涵蓋日子裡結束在那個方向的折返停留中位數（`layover-metrics` 的 p50），四捨五入到整分鐘，沒有折返停留時是 0。兩端的停留由伺服器算好寫進頁面的資料；換休息時瀏覽器只改停車端那一格。

理由：直接折返端的折返停留是車從末站開到下一趟起站的時間，不是休息（`zhongshan-turnaround-ends`），但它確實要花時間，用量到的中位數最誠實。休息沿用 `buffer` 這個參數名與範圍，路線頁的連結可以直接帶過來。

### 鋪排：發車交給在那一端等最久的車，沒有車就多開一台

鋪排是瀏覽器端的純函式（`app/frontend/timetable/layout.js`），不碰伺服器：輸入每個方向每小時的發車數、每個方向每小時每個百分位數的計畫行駛時間與退回標記、選的百分位數、兩端的停留分鐘數，輸出車輛清單。規則：

1. 每小時有 n 班時，第 k 班（k 從 0 起）的發車分鐘是 `floor(k × 60 / n)`。
2. 兩個方向的發車照時刻排序，同一時刻去程在前。
3. 一班從某一端發車，候選是「現在在那一端、而且可用時刻不晚於發車時刻」的車，選可用時刻最早的那台（等最久），同時刻取編號小的；沒有候選就新開一台車，編號照開車順序，從 1 起。
4. 車跑完一趟：到達時刻是發車加計畫行駛時間；可用時刻是到達加那一端的停留；位置換到另一端。

時刻用當天的分鐘數，可超過 1440 代表跨午夜；查計畫行駛時間的小時取 `floor(分鐘 / 60) mod 24`，加列加出來的 24:45 返程查的是 0 時。

理由：這是調度站排班的直覺（先到先發），結果可重現、可手算，規格裡的例子就是測試。沒有目標函數，不算最佳化。2026-10-25 之前這一段是 Ruby 的 `RoutePage::DraftLayout`，由 tasks 第 7 組搬到 JavaScript、拆掉 Ruby 那一份，演算法與例子不變。

替代方案：選可用時刻最晚的車（讓停留最緊，省車但休息最少，跟專案方向相反，否決）；把兩個方向分開排再配對（同一台車的來回接不起來，否決）。

### 單子一車一張、一列一個來回，欄位照行車憑單

每台車一張單，一列是一個來回：去的那趟與接著回的那趟。欄位照紙本行車憑單的順序：職號、姓名、發車時間、起點、調度員、預計到達終點（到達時刻）、停留（返回那趟發車減到達，分鐘）、預計返回起點（返回那趟的發車時刻）、累計里程、預計返站時間（返回那趟的到達時刻）、回站後停留（下一列發車減這一列返站，分鐘，最後一列空白）、行駛里程、調度員。停留與回站後停留是我們加的，緊跟在對應的時刻後面；職號、姓名、兩個調度員、兩個里程印出來是空白，給人手填；列不編號。最後只剩單程時，返回那三欄空白。單子的標題是「車次 N」：紙本左上角的「車次」是這一張單、這台車當天這一班的編號，一張單一個，不是每一列的編號（2026-10-25 對照照片改過來，第一版誤當成列號）。單子上不出現任何車牌：班表根本不讀 `bus_id`，印出來的「車號」是空格給人手填。

「車次」在詞彙表是趟次的「不要用」說法，這裡保留它當單子的編號，因為它要跟紙本行車憑單對得起來；寫進 `docs/spectra/LANGUAGE.md`「班本」那條的邊界。

理由：使用者提供的行車憑單照片就是這個格式，調度員拿到不用學。

### 單子的標記由伺服器的 template 給，瀏覽器只填值

單子與列的 HTML 骨架、欄位標題、按鈕與說明文字由 `TimetableSheetComponent` 以兩個 `<template>`（`data-sheet-template`、`data-row-template`）輸出一次，文案照常走元件同層的 `.yml`；瀏覽器複製 template、填時刻與數字、掛事件，不自己拼 HTML 字串。瀏覽器要的少數文案（隔日時刻的寫法、加一列的方向名）由 template 的 data 屬性帶，頁面的 JSON 只放數字與站名。

理由：標記與文案留在一個地方（ERB 與 `.yml`），跟網站其他元件同一套做法；JavaScript 只管算與填，Vitest 測純函式、system spec 測頁面。

替代方案：JavaScript 用字串樣板拼整張單（文案要搬進 JSON 或 JS，否決）；每次重算都送回伺服器重畫（就是被取代的那條決定）。

### 四小時休息數字算在計畫時刻上，只報數字

每張單一行「若一人開完這張單，連續 4 小時裡最少休 X 分鐘」，瀏覽器端的 `app/frontend/timetable/rest_windows.js` 照 `layover-metrics` 的視窗規則算在這台車的計畫時刻上：對每一趟 i 找最早的 j 使第 j 趟到達減第 i 趟發車達 240 分鐘，視窗的休息額度是第 i 到第 j−1 趟之後長度達 15 分鐘的停留總和；X 是所有視窗額度的最小值。這張單從頭到尾不到 240 分鐘時寫「這張單不到 4 小時」。接不上的負停留不算休息。不標合規或不合規、不上色。

理由：第 19 條之 2 是整個專案的法規錨點，調度員排班時最需要的就是這個數字；但資料與班表都只到車，一台車可能兩個人開，所以句子裡寫明「若一人開完」。`zhongshan-route-page` 把量到的班次串列為不上頁面，這裡算的是班表的計畫時刻，不是量到的資料，不衝突。2026-10-25 之前這一段是 Ruby 的 `RoutePage::DraftRestWindows`，同樣搬到 JavaScript。

### 用量到的趟次驗班表：超時比例表

`RoutePage::TimetableOverruns`：對 50 到 95 每 5 一格的每個百分位數 q，拿涵蓋日子裡每一趟有行駛時間的趟次，計畫值是它那個方向、那個發車小時的第 q 百分位數（樣本少退回全天，同上一條），超時是實際減計畫、小於 0 算 0。每個 q 一列：超時趟次的比例、超時達到休息分鐘數（把休息吃光）的比例、超時趟次的超時分鐘數中位數（一位小數，沒有超時趟次時寫「—」）。這張表只跟量到的資料與休息分鐘數有關，由伺服器算與畫（`TimetableOverrunTableComponent`）；目前選的 p 那一列粗體，瀏覽器換 p 時把粗體與 `data-selected` 移到那一列。表下寫明一趟一趟各算、不追延誤往下一趟傳。

理由：這是拿實測驻計畫，不是模擬；它讓「選 p50 還是 p85」有看得到的後果。超時的分母跟計畫值用同一批趟次，所以「超時比例」大致就是 100 減 q，差別來自整分鐘的進位與樣本少的退回，這一點寫在表下。「吃光休息」那一欄跟著休息分鐘數，換休息時瀏覽器不重算這張表，表頭寫的是載入時的休息分鐘數，旁邊註明換休息後要重新載入才會更新。

### 手動微調整張送回伺服器重算，不存、不用 JavaScript 算

已由「鋪排與微調都在瀏覽器算，伺服器只給量到的資料」取代，留作紀錄。原本的做法：班表頁是一張表單（`POST` 同一個網址），每一趟一組隱藏欄位，送出後伺服器照送來的發車時刻重算、重畫整頁，伺服器什麼都不存。理由是鋪排與休息檢查只在 Ruby 一份、RSpec 測得到。2026-10-25 使用者看了之後決定這類計算不該送後端，狀態只活在分頁裡，算在狀態所在的地方。

### 鋪排與微調都在瀏覽器算，伺服器只給量到的資料

**Supersedes**: timetable-draft / 手動微調整張送回伺服器重算，不存、不用 JavaScript 算

使用者 2026-10-25 拍板：重新鋪排（換 p、休息、每小時發車數）、改時刻、刪列、加列都在瀏覽器算，不送回伺服器。伺服器的回應裡嵌一段 JSON（`script[type="application/json"][data-timetable-data]`），放每個方向每個小時在每個百分位數下的計畫行駛時間與是否退回全天、量到的每小時發車數、兩端的停留分鐘數、兩端的站名、百分位數選項、休息與發車數的範圍。瀏覽器端的 Alpine 元件 `timetable` 讀這段資料，用純函式鋪排（`layout.js`）、算每張單的四小時休息（`rest_windows.js`）、把趟次配成列（`rows.js`）、處理改時刻、刪列、加列（`edits.js`）、格式化時刻與負停留（`format.js`），把單子畫進頁面，重算頁首的車數、每方向班數與手動改過的格數。什麼都不存，換參數會重新鋪排、手動改過的會不見，提醒固定寫在控制項旁邊。改時刻只重算到達、停留、四小時數字與總數，其他趟次的發車不動，接不上的停留印負數；加列照那張單第一趟的方向從打的時刻發，返回那趟從到達加那一端的停留發，兩趟都算改過；刪列刪掉那一列的兩趟。打的時刻不是營運日的 `HH:MM`（時 00 到 29、分 00 到 59）時，格子標成無效、保留原值。

理由：這張表的狀態（參數、手動改的格子）只活在分頁裡、不存，算在狀態所在的地方才合理；改一格就看到結果，不用整頁重載。演算法只有 JavaScript 一份，Ruby 不再有鋪排與四小時視窗，所以沒有兩份實作漂移的問題。

替代方案：伺服器重算（被取代的那一條）；伺服器算第一版、瀏覽器只算微調（同一套演算法兩份，否決）。

### 再加一台車：選方向、打第一趟的發車時刻，新開一張單

使用者 2026-10-25 看了中山幹線鋪出 23 台車之後說「如果需要，隨時也可以動態再加車班」。車數是規則鋪出來的最少同時在路上的車，不是上限；調度員要多開一台車時，改每小時發車數會整份重鋪、把手動改過的沖掉，所以單子底下多一個控制項：選方向（去程或返程）、打第一趟的發車時刻，按下去新開一張單，編號接在頁面上最大的車號後面（有車被刪光過也不重號），第一趟照選的方向、第二趟從到達加那一端的停留返回，兩趟都算改過，之後可以像別張單一樣再加一列。時刻不合格式就標無效、不加。沒有 JavaScript 時這一塊藏著，重新鋪排會把它清掉，跟其他手動微調一樣。頁首「量到的平均每天車數」與「班表的車數」那段說明改白話：前者數的是那天跑過的不同車牌，後者是同一時間最多要幾台車在路上，一台車從頭跑到尾、兩趟之間只停設定的分鐘數，所以通常比實際動用的少；車號是開車順序，不是車牌。

理由：工具是給人改的，加車是調度員最常見的動作之一；做成一個控制項比教人去改每小時發車數再重鋪直覺，也保住已經改過的格子。

替代方案：只靠每小時發車數加班（重鋪會沖掉手動改的，否決）；加一張空的單再從單子的加一列開始（空單沒有第一趟的方向可依，否決）。

### 瀏覽器端演算法用 Vitest 做單元測試

專案沒有 JavaScript 的單元測試工具。鋪排、四小時視窗、列的配對、微調、時刻格式化是有數字例子的演算法，用 headless Chrome 的 system spec 測太慢也太繞。加 `vitest` 當 devDependency，`package.json` 加 `test:js`（`vitest run`），測試檔放在模組旁邊（`app/frontend/timetable/*.test.js`，Vitest 預設會找到，Vite 打包不會把它們包進去），`config/ci.rb` 多一步 `step "Tests: JavaScript", "yarn test:js"`。規格的 Example 數字直接搬進測試。頁面上的流程（改一格、刪列、加列、列印鈕、列印樣式、換頁、390 寬）照舊用 system spec。

理由：這是專案第一個非顯示用的 JavaScript 演算法，值得一個單元測試工具；Vitest 跟 Vite 共用設定、零額外設定檔。

替代方案：只用 system spec 測（慢、每個例子要開瀏覽器，否決）；不測 JavaScript（規格的例子沒有鎖住，否決）。

### 沒有 JavaScript 時這一頁鋪不出班表

網站其他頁沒有 JavaScript 也完整（表單照送、地圖與圖有退路）。這一頁的計算全在瀏覽器，沒有 JavaScript 就沒有單子：伺服器輸出一句「這一頁要有 JavaScript 才鋪得出班表」（`[data-needs-script]`），Alpine 初始化時把它藏起來；超時比例表、資料限制、顯名聲明頁尾照常由伺服器輸出。這是網站裡唯一的例外，記在這裡與使用場景。

理由：給調度員的桌機工具，瀏覽器都有 JavaScript；為了沒有 JavaScript 再保留一份伺服器端的鋪排，就回到兩份實作。

### 列印用瀏覽器與列印樣式表，一車一頁

印出來的是一車一張的班表，不是網頁的列印版：使用者 2026-10-25 看了第一版（頁首的數字印在第一頁上面、第一張單擠在下面、超時表接在最後一張單後面）之後要求「一班車自己一張班表」。`app/frontend/stylesheets/application.css` 的 `@media print`：藏名稱列、頁首（路線名、涵蓋日子、數字、控制項、提醒）、列印鈕、再加一台車、刪除鈕與加一列、時刻輸入框（時刻改印同格的文字）；`main` 在印刷時改回區塊排版、不用 flex，斷頁才照一般區塊的規則走、Safari 才可靠；每張單 `break-after: page` 加舊的 `page-break-after: always`，所以每張單自己一頁、最後一張之後的超時表、資料限制與顯名聲明頁尾自然另起一頁；單子去掉卡片的外框與內距、列不跨頁、可橫向捲動的框印出全部；`@page` 預設橫印，十三欄才放得下。印出來照紙本的樣子（使用者 2026-10-25 拿行車憑單的照片對照，第一版只是網頁表格印成一頁，「不像班表」）：抬頭一行「＿＿公司　＿＿站　<路線名> 班表」，第二行「車次 N」、「車號＿＿」（空格手填，不從資料來）、「＿年＿月＿日 星期＿」，再一行小字寫資料依據（涵蓋的日子與日型別、p 幾、休息幾分，由 `TimetableSheetComponent` 的 template 帶著路線與日子、瀏覽器填百分位數與休息）；表格每一格都有格線、列高夠手寫、表頭粗體，列數不足 14 列時瀏覽器補空白列到 14 列，空白列只在印刷時出現；螢幕上的標題與卡片外框不印。邊界與內距照一般 Word 表格印出來的樣子（使用者 2026-10-25 的要求）：頁邊靠每張單自己 10mm／12mm 的內距，不靠 `@page` 的 margin（具名頁的 margin 不是每個瀏覽器的預覽都吃，Safari 尤其，第一版寫在 `@page` 結果貼邊），`@page` 只給 8mm 外邊與橫印；不留網頁的左右留白、文字黑色、0.5pt 黑色格線、格子內距 1.5mm 與 2mm、列高約 8mm、表頭不上底色。整張表要放進一頁的寬度（使用者 2026-10-25 第一次印中山幹線時右邊被切掉）：印刷時 `table-layout: fixed`、每欄照紙本的比例給固定寬度（表頭的 `data-column` 對到 CSS，合計 240mm，橫向 A4 扣邊界約 257mm，瀏覽器不吃 `@page` 時也有約 248mm）、內文 10pt、表頭 9pt 可換行、手填欄不再撐螢幕上的最小寬度、站名太長在那一格換行。一張紙拿在手上就跟調度室那張一樣，知道是哪條線、第幾車次、怎麼鋪的。頁面上一顆「列印」按鈕呼叫 `window.print()`，沒有 JavaScript 時藏起來（預設 `hidden`，元件初始化時打開）。另存 PDF 交給瀏覽器的列印對話框。

理由：不加 gem、不在 Droplet 上裝 headless Chrome；頁面上的表是 HTML，印出來就是表。

替代方案：Prawn 或 Grover 產 PDF（新依賴、部署要多裝東西，否決）。

### 入口：換休息試算卡的連結與名稱列的第三個連結

路線頁換休息試算那張卡，表單下方一個連結「排成班表」，網址是班表頁加上當時的 `day`、`range`、`buffer`，不帶 `late`、`from`、`to`、`end`（班表用不到）；那張卡在 turbo-frame 裡，連結帶 `data-turbo-frame="_top"` 才會換整頁。網站名稱列在路線頁與班表頁多一個連結「班表」，連到該路線的班表頁不帶參數，班表頁上帶 `aria-current="page"`；首頁仍是兩個連結。`SiteBarComponent` 多兩個選用的參數 `draft_route_id` 與 `draft_page`（改名後叫 `timetable_route_id` 與 `timetable_page`），由 layout 從控制器設的實例變數傳進去。

`ui-touchups` 與 `02-route-page-mobile-first` 把「名稱列加其他連結」列為非目標，兩條都寫「車牌查詢、回報表單、月報等有了再說」，是範圍限制不是否決；現在班表頁有了，加這一個連結。

理由：使用者要求放在名稱列；卡上的連結是因為調度員看完試算的數字，下一步就是排。

替代方案：首頁名稱列也放連結、先選路線（四條路線首頁本來就列了，多一頁沒有必要，否決）。

### 網址與參數：GET 產生、POST 微調，壞參數回 400

已由「網址只收 day、range、buffer、p，buffer 與 p 由瀏覽器寫回網址」取代，留作紀錄。原本的做法：`GET` 產生、`POST` 微調，`departures[<方向>][<小時>]` 也走網址，POST 另帶每一趟的欄位與刪列、加列的參數，任何壞值回 400。

### 網址只收 day、range、buffer、p，buffer 與 p 由瀏覽器寫回網址

**Supersedes**: timetable-draft / 網址與參數：GET 產生、POST 微調，壞參數回 400

只有 `GET /routes/:route_id/timetable`，`config/routes.rb` 一條明寫的路由指到 `TimetablesController#show`。參數：`day`、`range` 同路線頁（`RoutePage::Coverage`）；`buffer` 同換休息試算；`p` 是 50 到 95 的 5 的倍數；四個都是載入時的初始值，不合格式或超出範圍回 400，跟路線頁一樣；路線清單外的 Id 回 404 頁；選的日子沒有資料時回 200，寫「沒有這一天的資料」，不畫單子。瀏覽器換 `buffer` 或 `p` 時用 `history.replaceState` 寫回網址、不多一筆瀏覽紀錄（同換休息試算拉桿的做法），重新載入保得住；每小時發車數與手動改的格子不進網址（幾十個欄位，網址太長，而且刪列、加列沒有好的網址表示法）。

理由：跟路線頁同一套處理方式，`RoutePage::Coverage::InvalidParameter` 已經是 400 的路；參數留在網址，試算卡的連結才帶得過來。

### 詞彙與文件：班本、班表、車次；use-cases 11 改寫

`docs/spectra/LANGUAGE.md` 新增「班本」（業界對一車一天行車單的叫法，駕駛手填；邊界：雙班制同一台車兩人開仍是一台車一張；車次在單子上是一列、一個來回；不要用：班表當班本用、班次當車次用）與「班表」（網站用量到的行駛時間百分位數、休息分鐘數與每小時發車數鋪出的一車一張班表，在瀏覽器裡鋪、改、印，不存；在程式碼裡是 `RoutePage::Timetable`、班表頁與 `app/frontend/timetable/`；不要用：排班系統、最佳化、試算單、草稿）。「換休息試算」那條的邊界加一句「班表是另一個東西，見該條」。`docs/use-cases.md` 第 11 項與「下車以後用手機看」那段的「不發班表」改寫，並記下這一頁要 JavaScript 是網站的例外；README 交付物加班表頁一條，「明確不做」保留全網排班最佳化並註明一車一張的班表不是最佳化。

## Implementation Contract

**行為**

- 調度員開 `/routes/<Id>/timetable`，看到頁首（路線名、起訖、涵蓋的日子與日型別、量到的平均每天車數、鋪出來的車數與每方向班數、手動改過 N 處、「列印」鈕）、控制項（`p`、`buffer`、每方向每小時發車數）與固定的提醒、一車一張的單子、超時比例表、資料限制、網站的顯名聲明頁尾。頁面載入後單子由瀏覽器鋪出來。
- 改控制項的任何一格：瀏覽器立刻重新鋪排、重畫單子、重算總數、把超時表的粗體移到選的 p 那一列，`buffer` 與 `p` 寫回網址。手動改過的格子全部消失。
- 改某一趟的發車：那一趟到達、兩邊的停留、那張單的四小時數字與頁首總數重算，其他趟次不動；格子標成改過、有底線。刪列：那一列的兩趟不見，列號重排。加列：那張單底下多一列，兩個發車格都算改過。打的時刻不是 `HH:MM` 時格子標成無效、保留原值，什麼都不重算。
- 按「列印」開瀏覽器的列印對話框；印出來一車一頁，沒有控制項，時刻是文字，有資料限制與頁尾。
- 沒有 JavaScript：頁首、那一句「這一頁要有 JavaScript 才鋪得出班表」、超時表、資料限制、頁尾；沒有單子、沒有列印鈕。

**介面與資料形狀**

- `RoutePage::MeasuredDepartures.new(route_days)#counts` → `{ go_back => { hour => Integer } }`，24 個小時都有鍵。
- `RoutePage::PlannedRunTimes.new(route_days, percentile:)#minutes(go_back, hour)` → `[Integer, fallback]` 或 nil；`#minutes_at(go_back, hour, percentile)`；`#any?(go_back)`。
- `RoutePage::TimetableOverruns.new(route_days, buffer:, run_times:)#rows` → 每個 q 一列 `percentile, overrun_share, exhausted_share, median_overrun`。
- `RoutePage::Timetable.new(route_days:, ends:, buffer:, percentile:)`：`#covered`、`#route_name`、`#vehicles_per_day`、`#missing_run_times`、`#holds`、`#stop_names`、`#departures`（量到的預設）、`#overruns`、`#data`。`#data` 是頁面 JSON 的 Hash：`percentile`、`buffer`、`percentiles`（`[50, 55, …, 95]`）、`bufferRange`（`[0, 20]`）、`departuresRange`（`[0, 30]`）、`runTimes`（`{ "0" => [24 個 { "50" => [分鐘, 退回全天], …, "95" => […] }], "1" => […] }`，索引是小時）、`departures`（`{ "0" => [24 個整數], "1" => […] }`）、`holds`（`{ "0" => 分鐘, "1" => 分鐘 }`，載入時的休息算的）、`stoppingEnds`（停車端的方向，如 `[0, 1]`；瀏覽器換休息時只動這些端的停留，直接折返端照 `holds` 的值）、`stopNames`（`{ "0" => 站名, "1" => 站名 }`，沒有站名的方向沒有鍵）。
- `app/frontend/timetable/layout.js`：`minutesInHour(n)`；`plan(runTimes, percentile, goBack, departure, edited = false)` → `{ goBack, departure, arrival, fallback, edited }`；`layOut({ departures, runTimes, percentile, holds })` → `[{ number, trips }]`，`departures` 是 `{ "0": [24], "1": [24] }`，時刻是當天分鐘數、可超過 1440。
- `app/frontend/timetable/rest_windows.js`：`minimumCredit(trips)` → 整數或 `null`。
- `app/frontend/timetable/rows.js`：`rows(trips)` → `[{ number, first, second, stop, nextStop }]`，`second`、`stop`、`nextStop` 可為 `null`。
- `app/frontend/timetable/edits.js`：`changeDeparture(vehicles, { vehicle, index, departure }, plan)`、`deleteRow(vehicles, { vehicle, row })`、`addRow(vehicles, { vehicle, departure }, plan, holds)`、`addVehicle(vehicles, { goBack, departure }, plan, holds)`（編號是頁面上最大的車號加一）都回新的車輛清單、不改傳入的；`countEdited(vehicles)`。
- `app/frontend/timetable/format.js`：`clock(minutes, nextDayLabel)`（`"06:50"`；1470 → `nextDayLabel` 填入 `"00:30"`）、`fieldClock(minutes)`（營運日的 `"24:30"`）、`parseClock(text)`（`"HH:MM"`，時 00 到 29、分 00 到 59，否則 `null`）、`stopText(minutes)`（`null` → `""`，負數用 U+2212 的「−」）。
- Alpine 元件 `timetable`（`app/frontend/timetable/component.js`，在 `application.js` 註冊）：讀 `script[data-timetable-data]`、把單子畫進 `[data-sheets]`、填 `[data-timetable-header] [data-value="vehicles"|"departures-0"|"departures-1"|"edited"]`、每張單的 `[data-rest-credit]`、超時表的 `tr[data-selected]`。
- 頁面上的標記：`main[data-timetable]`、`[data-timetable-header]`、控制項 `select[name=p]`、`input[name=buffer]`、`input[name="departures[<方向>][<小時>]"]`（名字只為了讀，不送出）、`[data-regeneration-notice]`、`[data-needs-script]`、`[data-sheets]`、`template[data-sheet-template]`、`template[data-row-template]`；每張單 `section[data-vehicle="<編號>"][id="vehicle-<編號>"]`、每列 `tr[data-row="<列號>"]`、時刻格 `[data-departure="<分鐘>"]`（裡面是 `input[data-departure-input]` 與印刷用的 `span`）、`[data-arrival="<分鐘>"]`、`[data-fallback]`、`[data-stop]`、改過的格 `[data-edited]`、無效的格 `[data-invalid]`（時刻格另帶 `data-sheet` 與 `data-index` 說它屬於哪張單的第幾趟；`data-vehicle` 只標單子）、`button[data-delete-row]`（帶 `data-sheet` 與 `data-row`）、`[data-add-row] input` 與 `button[data-add]`、`[data-rest-credit="<分鐘或空>"]`、`button[data-print]`；單子底下的加車控制項 `[data-add-vehicle]`（預設 `hidden`，元件初始化時打開）裡有 `select[data-add-vehicle-direction]`、`input[data-add-vehicle-input]` 與 `button[data-add-vehicle-button]`，時刻無效時 `[data-add-vehicle]` 帶 `data-invalid`。

**失敗的樣子**

- 壞的 `day`、`range`、`buffer`、`p` 回 400；路線清單外 404 頁；沒有資料 200 加說明；某方向沒有行駛時間時 200、不給資料、不畫單子、寫出哪個方向。
- 打的時刻不合格式：格子 `[data-invalid]`、保留原值；不重算。
- 手動改到接不上：停留印負數，不擋。
- 沒有 JavaScript：有那一句說明，沒有單子、沒有列印鈕，瀏覽器選單的列印照常可用。

**驗收**

- 規格裡的演算法 Example（發車分鐘、四班的鋪排、等最久的車、四小時 70 與 40、負停留、改 07:20 得 30 與 08:05、加列 11:48/12:03/12:49）各有一個 Vitest 測試（`app/frontend/timetable/*.test.js`）；`yarn test:js` 全綠。
- `spec/requests/timetables_spec.rb` 驗網址、400、404、沒資料、沒有行駛時間、頁面的 JSON 內容、頁首、沒有 JavaScript 那一句、`<title>`、顯名聲明；`spec/models/route_page/timetable_spec.rb` 驗 `#data` 的形狀與 holds、站名。
- `spec/system/timetable_edit_spec.rb`（`:js`）驗頁面載入後三台車三張單、改一格、刪列、加列、換 p 與 buffer 重鋪並寫回網址、無效時刻；`spec/system/timetable_print_spec.rb` 驗列印鈕、列印樣式與換頁；`spec/system/timetable_entry_spec.rb` 驗試算卡的連結換整頁；`spec/system/timetable_layout_spec.rb` 驗 390 寬不橫向捲動。
- `spec/requests/site_layout_spec.rb` 驗首頁兩個連結、路線頁與班表頁三個連結；`spec/requests/routes_spec.rb` 驗卡上連結的網址。
- `bin/rubocop` 對新增與修改的檔案乾淨；`bin/ci`（含 `yarn test:js`）通過。
- 人工：Chrome 與 Safari 的列印預覽，一車一頁、沒有控制項、頁尾在。

**範圍邊界**

- 範圍內：上面的頁、元件、查詢物件、路由、JavaScript 模組與測試、Vitest 設定、列印樣式、兩個入口、三份文件、改名、拆掉伺服器端微調。
- 範圍外：衍生表、`analysis/`、健檢卡、`derived:load`、正式站資料、班表對照、任何儲存、把發車數或手動改的格子放進網址。

## Risks / Trade-offs

- [量到的發車數偏低（趟次重建漏趟或當天減班），鋪得比實際少] → 每格可改、頁首寫出預設是量到的平均；班表對照另開 change 查差距。
- [改一格造成後面接不上] → 停留印負數、改過的格有標記，調度員自己看得到；不自動往後推，避免班表偷偷變形。
- [演算法在 JavaScript，Ruby 這邊看不到] → 規格的例子進 Vitest，`bin/ci` 一起跑；伺服器給的 JSON 形狀有 request spec 鎖住。
- [沒有 JavaScript 這一頁是空的] → 寫明這是例外，頁面上有那一句說明；調度員的桌機都有 JavaScript。
- [列印在不同瀏覽器排版不同] → 用 `break-before: page` 與 `break-inside: avoid` 這類標準屬性；人工在 Chrome 與 Safari 驗。
- [跨午夜的趟次（23 時發、00 時到）] → 時刻用當天分鐘數，可超過 1440，印成 24:xx 之後的時刻以「隔日 00:xx」顯示，輸入框用營運日的 24:xx；涵蓋的日子本身照路線頁的日型別分。
- [同一頁兩套「要幾台車」（試算的最忙小時增加車數、班表的車數）] → 頁首旁邊寫明「試算算的是量到的折返停留多留幾分鐘要多幾台，班表算的是照這些班數與停留鋪出來要幾台」。
- [超時表的「吃光休息」欄跟著載入時的休息分鐘數，換休息後不更新] → 表頭寫出用的分鐘數，旁邊註明換休息後重新載入才會更新；真正跟著動的是單子上的停留。

## Migration Plan

沒有資料庫變更。照常用 Kamal 部署，由使用者執行；回滾就是部署前一版。`yarn install` 會多裝 Vitest（devDependency，不進正式站的 image 執行階段）。

## Open Questions

- 無。超時比例表要不要同時列「吃光休息」之外的其他門檻，等調度員看過第一版再說。
