<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
開工前先 /spectra-drift daan-top-three-routes：設定的寫法與 ends_spec 的例子要跟當時的 config/route_page.yml 對齊。
-->

## 1. 設定與測試

- [x] 1.1 套用 design「三條的兩端性質用全路網調查的證據查證，寫進設定」「三條排在 307 之後，照官方每日人次的順序」與「設定的註解一端一段，數字抄調查報告」：`config/route_page.yml` 的 `shared.routes` 在 16111 之後依序加 10283、11833、10832，各只有 `ends: { 0: pass_through, 1: stop }`、沒有 `member_routes`，每條路線一段英文註解寫路線名、起迄、查證日期 2026-11-01 與證據來源（change `02-end-nature-survey`、`tmp/end-natures/report-2026-10-19_2026-10-22.csv`、四天合計），每一端的值旁一段寫末站、下一趟起站與距離、有 GPS 的折返停留筆數、停下來過的筆數與比例、折返停留中位數、最長靜止 p50 與最大、最遠離站 p90 與最大，數字只抄 design Context 那張表。做完後 `RoutePage.ends(10283)`、`ends(11833)`、`ends(10832)` 都是方向 0 `pass_through`、方向 1 `stop`，`RoutePage.route_ids` 是 15373、10712、11764、16111、10283、11833、10832 與 9001，`/routes/10283`、`/routes/11833`、`/routes/10832` 不再是 404。對應「Verified end nature per route」的 Scenario「Both ends of 235」「Both ends of 復興幹線」「Both ends of 22」與「Route list is the set of configured routes」：`spec/models/route_page/ends_spec.rb` 加三個例子（各讀一條的兩端，寫法照中山幹線那個例子）、路線清單的例子改成八條。驗證：`bundle exec rspec spec/models/route_page/ends_spec.rb spec/requests/routes_spec.rb spec/models/home_page/route_list_spec.rb` 全綠（9999 仍回 404）；`bin/rubocop spec/models/route_page/ends_spec.rb` 沒有警告；設定的註解由 agent 對照 design Context 的表逐欄看一次，六端的數字與站名都一樣。

## 2. 文件

- [x] 2.1 [after: 1.1] 套用 design「README 與詞彙表「路線頁」改成七條」：`README.md`「目前有路線頁的是…」那句與 `docs/spectra/LANGUAGE.md`「路線頁」的「在資料或程式碼裡」列出七條（15373 中山幹線、10712 251、11764 251區、16111 307 掛 19108 307西藏三民、10283 235、11833 復興幹線、10832 22），其餘文字不動。驗證：`grep -n "10283\|11833\|10832" README.md docs/spectra/LANGUAGE.md config/route_page.yml spec/models/route_page/ends_spec.rb` 四個檔都有三個 `Id`；兩句由 agent 看一次，沒有用到「變體」「子路線」這類詞彙表不要用的說法。

## 3. 真資料驗收

- [x] 3.1 [after: 1.1] 套用 design「真資料驗收只載 2026-10-22 一天，對照調查同一天的證據」：`TURNAROUND_DATA` 指向本機備份（路徑不寫進 repo），`bin/rails derived:load ROUTE=10283 DAY=2026-10-22`，11833 與 10832 同，三個都成功寫入；再用 `bin/rails runner` 透過 `RoutePage::Coverage`（`route_id`、`day: "2026-10-22"`、範圍 `day`）印 `RoutePage::LayoverStats` 每一端的筆數與中位數，跟調查 2026-10-22 單日的證據比（從 `tmp/end-natures/evidence/2026-10-22/<Id>/ends.csv` 與 `layovers.csv` 算的，`tmp/` 不進 repo，所以抄在這裡）：235 去程結束 交通部觀光署 114 筆、中位數 4.1 分鐘，返程結束 西盛 59 筆、40.7 分鐘；復興幹線 去程結束 景華公園 104 筆、3.3 分鐘，返程結束 建北站 53 筆、16.1 分鐘；22 去程結束 二二八和平公園 95 筆、1.8 分鐘，返程結束 松德站 79 筆、21.6 分鐘。通過條件照 design：每一端的筆數不多於調查、不少於調查的八成；停車端的中位數至少 10 分鐘、直接折返端不超過 5 分鐘。結果寫進 `design.md` 新的一節「真資料驗收」：三條六端兩邊的筆數與中位數、載入的日期與靜態快照、不符的項目。驗證：design 那一節有六端的數字且每一端都符合條件；任一條不符就先 `/spectra-ingest daan-top-three-routes` 改那一條的情境與設定，不改數字遷就。
- [x] 3.2 [after: 3.1] 開發環境（`bin/dev`；3000 被別的專案占住時另開 3100 並給 Vite `--cors`）看頁面：首頁「有頁面的路線」七張卡依序是 15373、10712、11764、16111、10283、11833、10832，後三張寫「最新資料 2026-10-22（四）平日」與停車端不到 15 分鐘的比例；`/routes/10283`、`/routes/11833`、`/routes/10832` 的摘要與折返停留卡兩端都有筆數、試算只算停車端；`/routes/11833` 的沿線載客圖是平的線（預期中，不處理），設施那一塊的調度站顯示「這個調度站還沒對過查核名單」。截圖存在 `tmp/` 底下，首頁與 11833 載客卡的樣子寫進 design「真資料驗收」。驗證：agent 看截圖，七張卡的順序與三條路線頁的內容跟上面一樣；使用者的驗收在 4.2。

## 4. 收尾

- [x] 4.1 [after: 2.1, 3.2] `bin/rails parallel:spec` 全綠；`bin/rubocop` 對這次改到的 `.rb` 沒有警告；`config/route_page.yml`、`spec/models/route_page/ends_spec.rb`、`turnaround-ends` 的情境、`README.md`、`docs/spectra/LANGUAGE.md` 是同一組七條路線。驗證：三個指令的輸出，與 `grep -c "10283" config/route_page.yml spec/models/route_page/ends_spec.rb docs/spectra/changes/daan-top-three-routes/specs/turnaround-ends/spec.md README.md docs/spectra/LANGUAGE.md` 每個檔至少 1。
- [x] 4.2 [after: 4.1] 使用者驗收：在開發環境打開首頁與 `/routes/11833`。驗證：使用者看到七張卡、後三張是 235、復興幹線、22，並確認復興幹線載客卡平線的處理留到之後的 change。
