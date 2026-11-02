<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
先決條件：01-rest-windows 與 02-published-schedule 都歸檔並 commit。開工先 /spectra-drift 03-monthly-card。
版面參考 .spectra/design-cache/03-monthly-card/（不進版控）；文案以 design 的 Implementation Contract 為準。
-->

## 1. 月份與涵蓋

- [x] 1.1 套用 design「月卡一個月一列存在 route_cards，涵蓋先算好存進去」，實作 Requirement「Route card row for a month」：migration、`RouteCard` model、factory、`#partial?`。驗證：`spec/models/route_card_spec.rb` 涵蓋唯一鍵與部分月份的四列表格（「平日收到不到九成算部分月份」），`bin/push-derived` 的衍生表清單測試確認沒有 `route_cards`。
- [x] 1.2 [after: 1.1] 套用 design「這個月的每一天歸成四種，有還在等的日子就不算到齊」「平日收到不到九成算部分月份」與「cards:prepare 寫一列，還在等就不寫」，實作 Requirement「Coverage of a month」與「Preparing a route card」：`RouteCardCoverage` 與 rake task。驗證：`spec/models/route_card_coverage_spec.rb` 涵蓋規格的情境（10 月那一份、原始檔齊全但沒載入、讀檔視窗還沒結束，`now` 由測試給）；task 的 spec 涵蓋到齊、還在等、成員路線與月份格式不對。

## 2. 查詢物件

- [x] 2.1 [after: 1.1] 套用 design「月卡的數字全部來自查詢物件，一個月就是一組路線日」：`RoutePage::MonthCard`、`LayoverHours`、`MonthDays`、`SlowLegs`。驗證：各自的 spec；`MonthDays` 的漏站率在 `spec/models/route_page/card_consistency_spec.rb` 對健檢卡 JSON；`SlowLegs` 涵蓋規格「Slowest stretches」的例子。
- [x] 2.2 [after: 2.1] 套用 design「第 1 頁「這個月看到的事」用規則組句，不寫結論」，實作 Requirement「Findings sentences」。驗證：`spec/models/route_page/month_findings_spec.rb` 涵蓋規格的四個情境與四句各自不出現的條件、兩個停車端時句首寫末站名。
- [x] 2.3 [after: 2.1] 套用 design「上月與逐月表用現在的定義重算，跟當時不同就註明」：`RoutePage::CardTrend` 與 `RoutePage::MonthCard#summary`。驗證：`spec/models/route_page/card_trend_spec.rb` 涵蓋只有一份、有上一份、`summary` 跟重算不同時點名那個月、部分月份的標示，`summary` 的鍵與四捨五入照 design。

## 3. 頁面

- [x] 3.1 [after: 2.1] 套用 design「頁面只給印，不連出去」與「內容只留直指駕駛休息與班表的區塊」，實作 Requirement「Month card page」與「Blocks left out of the month card」：路由、`RouteCardsController#show`、view 的骨架與 `data-card-section`。驗證：`spec/requests/route_cards_spec.rb` 涵蓋區塊順序、四種 404、文件標題、`noindex`、沒有車牌與 `不合規`、沒有規定不放的字、還沒重算時最上面的提醒。
- [x] 3.2 [after: 2.2, 3.1] 實作 Requirement「Summary block」，文案照 design Implementation Contract；套用 design「限制寫在各區塊的內文，不另立資料限制區塊」：第 1 頁那一句，以及 `docs/spectra/LANGUAGE.md`「資料限制」的邊界、「健檢卡」改成月卡的內容與部分月份、拿掉「第一張是 Markdown」改寫成一天版與月卡的區別。驗證：component spec 涵蓋涵蓋句、兩個停車端、上月那一欄、沒有假日時的 —；詞彙表內容檢查，跟這個 change 的規格沒有矛盾。
- [x] 3.3 [after: 3.1] 實作 Requirement「Layovers block」與「Continuous driving block」，內文照 design。驗證：component spec 涵蓋小時列的比例與筆數、筆數不到 10 的柱子分開畫、規則列的四個值、10 小時那一句與連續行駛段的分佈。圖的樣子由 4.2 使用者看。
- [x] 3.4 [after: 3.1] 實作 Requirement「Schedule block」：兩張圖與對照表。驗證：component spec 涵蓋時段列、公告改過時一版一張表、成員路線一列、其餘時段一列、下界最小的時段標出來。
- [x] 3.5 [after: 3.1] 實作 Requirement「Cycles and run times blocks」與「Buffer block」。驗證：component spec 涵蓋不算的趟數、最慢的 4 段、筆數不到 5 的灰字、差不到 4 分鐘的小時標出來、15 分鐘那一列，內文沒有建議。
- [x] 3.6 [after: 2.3, 3.1] 實作 Requirement「History block」與「Attribution block」，並套用 design「顯名聲明只列這份用到的來源」。驗證：component spec 涵蓋第一份、定義改過的註明、快照沒有改動與有改動、少的日子那一列、兩段授權文字與不列的來源。
- [x] 3.7 [after: 3.2, 3.3, 3.4, 3.5, 3.6] 套用 design「版面照試印：A4 直式，頁尾有路線、月份與頁碼」，實作 Requirement「Month card printing」：`@page month-card`、頁尾的 margin box、部分月份的字樣、列印時藏名稱列與 layout 頁尾。驗證：`spec/system/month_card_print_spec.rb`（`:js`，CDP 換 print media）涵蓋藏起來的元素與 `Page.printToPDF` 的 A4 直式；路線名含引號時 `<style>` 不會壞。

## 4. 文件與驗收

- [x] 4.1 [after: 3.7] 套用 design「用真資料驗收：中山幹線 10 月的頁面跟試印的數字相同」：本機載入 15373 的 10 個路線日、跑 `cards:prepare`、用 headless Chrome 印成 PDF。驗證：頁面與 PDF 的數字跟 design 列的相同，不超過 6 頁，掃描 PDF 文字沒有車牌；再用 16111 印一份確認兩個停車端與成員路線沒有版面問題，結果記進 design。
- [x] 4.2 [after: 4.1] 使用者看印出來的 PDF。驗證：使用者確認版面與內容，或提出要改的地方。
- [x] 4.3 [after: 4.1] 全套檢查。驗證：`bin/rails parallel:spec` 全綠、對改到的 `.rb` 跑 `bin/rubocop` 沒有警告、`bin/brakeman` 沒有新告警，`git status` 只有這個 change 的檔案。
