<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
先決條件：03-monthly-card 已歸檔（2026-11-02）；01、02、03 的程式碼還沒 commit，這個 change 接著改同一個工作目錄。
mini 與正式站上的步驟都由使用者用 ! 跑。
-->

## 1. 印製

- [x] 1.1 套用 design「第一份是 2026 年 11 月，設定放 config/route_cards.yml」與「PDF 的位元組放在自己的表」：設定檔與讀它的 `CardMonths`（比照 `DerivedDays`）；migration 在 `route_cards` 加 `pdf_sha256`、`pdf_bytes`、`program_version`、`printed_at`、`revision_reason`，建 `route_card_pdfs`；`RouteCard` 加 `printed` scope 與存一份印好的 PDF 的方法，已印的列唯讀。驗證：model 的 spec 涵蓋設定檔格式不對的訊息、到期的月份（`first_month` 到上個台北月）、第一份的月份（`first_month` 與上個月取較晚）、`printed` 只列印好的列、已印的列 `update!` 會失敗、印好的欄位不能只有一部分；`spec/models/derived_push_command_spec.rb` 涵蓋 `route_card_pdfs` 不是衍生表。
- [x] 1.2 [after: 1.1] 套用 design「印之前確認頁面是那一份，印好確認是 PDF」、「定稿的 PDF 在 Mac mini 用 Chrome 印好存進資料庫」與「存的摘要與程式版本都從頁面讀」，實作 Requirement「Checks around the printer」與「Month card page」：`CardPrinter`，月卡頁加 `turnaround-card`、`turnaround-program-version`、`turnaround-card-summary` 三個 meta，提醒改標 `data-card-incomplete`。驗證：`spec/models/card_printer_spec.rb` 用假的 HTTP 與假的 chrome 腳本涵蓋規格的七個情境；`spec/requests/route_cards_spec.rb` 涵蓋規格的「Which card the page is」與「Days not loaded again」。
- [x] 1.3 [after: 1.2] 套用 design「每小時檢查，資料到齊才印，不固定日期」與「跟 bin/nightly-load 共用一把鎖」，實作 Requirement「Monthly cards command」與「Printing a month that is ready」：`MonthlyCardsCommand` 與 `bin/monthly-cards`；`NightlyLoadCommand` 的鎖、轉送與 migration 版本檢查移到 `ProductionSession`，兩個指令共用。驗證：`spec/models/monthly_cards_command_spec.rb` 涵蓋計畫不寫入、還沒有到期的月份、看不懂的參數、拿不到鎖、到齊印、印過不再印、還在等跳過且結束碼 0、還沒重算跳過且結束碼 0、一條失敗不擋其他、這個月不算；`spec/models/production_session_spec.rb` 涵蓋鎖與 migration 版本；`spec/models/nightly_load_command_spec.rb` 全綠，只有鎖的訊息改成點名兩個指令；`bin/monthly-cards` 在非 production 時停下來。
- [x] 1.4 [after: 1.3] 套用 design「印過的版本不再改，更正要出新版並寫原因」與「試印不存：--sample 印到指定的檔」，實作 Requirement「Corrected versions」、「Sample print」與「Preparing a route card」。`cards:prepare` 碰到已印的月份時拒絕。驗證：`spec/models/monthly_cards_command_spec.rb` 涵蓋更正版、舊版位元組不變、缺原因、沒有已印版本的月份、涵蓋沒到齊的更正、更正失敗後再跑一次不多版本號、試印後資料庫沒有多一列、試印失敗也不留列、已有的列不動、涵蓋還在等時印提醒；`spec/models/route_card_prepare_command_spec.rb` 涵蓋已印的月份。
- [x] 1.5 [after: 1.4] 套用 design「本機副本不覆寫，資料庫不見時灌回去」，實作 Requirement「Local copy of a printed card」與「Restoring printed cards」：`RouteCardLocalCopy`，`bin/monthly-cards --restore`。驗證：`spec/models/route_card_local_copy_spec.rb` 涵蓋兩個檔的內容、已有同名檔時失敗而且原檔不變；`spec/models/monthly_cards_command_spec.rb` 涵蓋規格的「Local copy」、「Database rebuilt」、「An earlier write failed」、「Rebuilt database」、「Already there」、「Different bytes」、「Damaged copy」，以及只印計畫時也點名、`--revise` 也擋。
- [x] 1.6 [after: 1.5] 依 design「第一份是 2026 年 11 月，設定放 config/route_cards.yml」2026-11-02 的修改，把第一份提前成 2026 年 10 月：`config/route_cards.yml` 的 `first_month` 改成 `2026-10`，`docs/decisions.md` 第 15 條跟著改。驗證：`spec/requests/route_cards_spec.rb` 的「還沒有檔案」不依賴 repo 裡的設定，`spec/models/card_months_spec.rb` 讀得出 repo 的設定；開發庫用真的 Chrome 印出 15373 與 16111 的 2026-10，清單頁列出來、標部分月份。

## 2. 下載與清單

- [x] 2.1 [after: 1.1] 套用 design「下載網址一個月一個，舊版用 version 參數」，實作 Requirement「Downloading a printed card」。驗證：`spec/requests/route_cards_spec.rb` 涵蓋最新版、舊版、還沒印的 404、版本不存在的 404、版本不是數字的 404、檔名、`ETag`、`Cache-Control`，帶 `If-None-Match` 時 304 而且 SQL 沒有讀 `route_card_pdfs`；印過的月份開月卡頁時 SQL 沒有讀 `route_card_pdfs`。
- [x] 2.2 [after: 2.1] 實作 Requirement「Month card list」：`RouteCardsController#index` 與 ViewComponent。驗證：同一個 request spec 與 component spec 涵蓋一份已印、更正過、部分月份、還沒有檔案時的那一句（`first_month` 與上個月取較晚）、沒有 PDF 的列不出現、成員路線 404；SQL 沒有讀 `route_card_pdfs`。

## 3. 名稱列

- [x] 3.1 [after: 2.2] 套用 design「名稱列多一個連結，點了到月份清單，不做下拉」與「手機上縮標誌、間距與字級」，符合 Requirement「Site name bar on every page」：`SiteBarComponent` 第三個路線連結與 `current: :cards`，640px 以下的尺寸。驗證：`spec/requests/site_layout_spec.rb` 更新連結數與 `aria-current`，涵蓋清單頁與月卡頁；`spec/system/route_page_mobile_spec.rb` 用 CDP 模擬 390 與 360 寬，`document.documentElement.scrollWidth` 不超過視窗寬、四個路線連結與「關於」都看得到；1400 寬時標誌高度與連結字級不變。

## 4. 文件與收尾

- [x] 4.1 [after: 1.5, 2.2, 3.1] 套用 design「定稿與排程記進 decisions.md」：`docs/decisions.md` 第 15 條、`AGENTS.md` 常用指令、`docs/spectra/LANGUAGE.md`「健檢卡」補定稿與更正。驗證：內容檢查，沒有主機、路徑與要跟誰談這類文字。
- [x] 4.2 [after: 4.1] 全套檢查。驗證：`bin/rails parallel:spec` 全綠、對改到的 `.rb` 跑 `bin/rubocop` 沒有警告、`bin/brakeman` 沒有新告警，`git status` 列出的檔案都屬於這個 change 或還沒 commit 的 `01-rest-windows`、`02-published-schedule`、`03-monthly-card`。

## 5. 上線

- [x] 5.1 [after: 4.2] 套用 design「用真資料驗收：mini 印得出中山幹線 10 月」：使用者 deploy 之後，在 mini 用 `!` 跑 `ROUTE=15373 MONTH=2026-10 OUT=<路徑> bin/monthly-cards --sample`。驗證：PDF 開得起來、不超過 6 頁、掃描文字沒有車牌，記下秒數與大小取代 proposal 的估計；正式站 `route_cards` 沒有多一列。
- [x] 5.2 [after: 5.1] 使用者把 `bin/monthly-cards --print` 接進 mini 上包一層的 script。那支 script 開了 `set -e`，要分別記下 `bin/nightly-load --load` 與 `bin/monthly-cards --print` 的結束碼，兩個都跑完才結束，有一個非零整支就非零。驗證：下一個小時的 log 有 `bin/monthly-cards` 的輸出，每條頁面路線的 2026-10 印好 v1，或點名還在等、還沒重算的日子。
- [x] 5.3 [after: 5.2] 第一批（2026 年 10 月）印好之後，使用者打開清單、下載一份；2026-12-01 再確認 11 月自己印出來。驗證：每條頁面路線都有 2026 年 10 月而且標部分月份，檔案跟 mini 上留的那份 SHA-256 相同，使用者確認內容；12-01 之後每條頁面路線都有 2026 年 11 月，log 裡開頁面的秒數沒有超過 kamal-proxy 的 30 秒。
