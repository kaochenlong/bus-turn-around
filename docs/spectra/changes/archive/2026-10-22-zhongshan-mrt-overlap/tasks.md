<!--
每條任務寫兩件事：做完之後哪個行為可觀察、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
-->

## 1. 捷運出入口快照

- [x] 1.1 實作 MRT entrance snapshot 與 design「出入口快照：下載時轉成 UTF-8，算的時候用最新的一份並記下日期」的下載部分：一個下載類別接資料根目錄、台北日與可以替換的 fetcher（預設用 `Net::HTTP` 抓 data.gov.tw 128428 的下載網址），把 Big5 轉成 UTF-8、檢查表頭、資料列與經緯度，通過才寫 `external/taipei-mrt-exits/<台北日>.csv`；rake task `external:mrt_exits` 讀 `TURNAROUND_DATA` 呼叫它、印出寫了幾個出入口。驗證：spec 以假 fetcher 回傳用 `String#encode("Big5")` 做出的內容，斷言 Scenario「Big5 snapshot written as UTF-8」；另斷言 Scenario「Unexpected file」的四種情況（狀態 500、表頭不同、沒有資料列、緯度不是數字）都結束碼非零、不寫檔、既有快照不變；沒有 `TURNAROUND_DATA` 時印用法。測試不連網路。`bin/rubocop` 與 `bin/brakeman` 無 offense、無警告。

## 2. 站牌到最近出入口的距離

- [x] 2.1 讓 fixture 測得出距離：`spec/fixtures/analysis/static/2026-10-19/GetStop.gz` 的路線 9001 站牌改成分開的座標（去程第 0 到 4 站沿經度 121.5 往北每站約 278 公尺，返程第 5 到 9 站在東邊約 30 公尺、由北往南），其餘欄位不變；新增 `spec/fixtures/analysis/external/taipei-mrt-exits/2026-10-19.csv`（UTF-8，表頭照 MRT entrance snapshot），放兩個假出入口，一個在去程第 2 站的位置、一個在遠處；`analysis/10_load.sql` 的 `stops` 帶出 `latitude`、`longitude`（轉成 double）。`spec/fixtures/analysis/README.md` 寫出站牌與出入口的座標，以及手算的每站最近距離。驗證：`spec/analysis/fixtures_spec.rb` 斷言十個站牌座標兩兩不同、出入口檔有兩列；`bundle exec rspec spec/analysis` 全綠（design 已核對過目前沒有測試或程式讀站牌座標）。 [after: 1.1]
- [x] 2.2 新增 `analysis/mrt_overlap.sql` 實作 Nearest entrance of each stop，套用 design「重疊用站牌到最近捷運出入口的直線距離」與「距離用 DuckDB 的 haversine 巨集，不裝 spatial 擴充」：讀 `stops` 與變數 `mrt_exits_path`，建立 `stop_mrt_distances`（`go_back`、`seq`、`latitude`、`longitude`、`nearest_exit_name`、`nearest_exit_meters` 一位小數）；檔名不以數字開頭，`bin/health-card` 不會執行它。驗證：新增的 spec 對 fixture 斷言每站最近的出入口名稱與距離等於 `spec/fixtures/analysis/README.md` 手算的值（容許 0.1 公尺內的差），並以兩個出入口距同一站約 111 與 334 公尺的灌入資料斷言 Scenario「Nearest entrance chosen」；`spec/analysis/card_spec.rb` 仍全綠。 [after: 2.1]

## 3. 衍生表

- [x] 3.1 實作 Derived export 的修改與 design「衍生表存每個站牌的最近距離，門檻在讀頁面時套用」：`derived_export.sql` 的 `stops.csv` 加 `latitude`、`longitude`、`nearest_exit_name`、`nearest_exit_meters`，`route_day.csv` 加 `mrt_exits_day`；migration 在 `route_day_stops` 加這四欄、在 `route_days` 加 `mrt_exits_day`（不回填）；`RouteDayLoader` 選資料夾裡檔名日期最新的快照傳給 `mrt_overlap.sql`、附加檔順序是 `mrt_overlap.sql` 再 `derived_export.sql`，並把新欄位寫進資料表。驗證：`spec/analysis/derived_export_spec.rb` 的欄位名斷言改成新欄位、仍斷言連跑兩次位元組相同；`spec/models/route_day_loader_spec.rb` 斷言寫入後站牌帶著 2.2 的距離、Scenario「Newest snapshot used」（暫存目錄放 2026-10-20 與 2026-10-22 兩份，`mrt_exits_day` 是 2026-10-22）；跑完 migration 後 `bin/rails parallel:setup`，`make test` 全綠。 [after: 2.2]
- [x] 3.2 實作 Day eligibility 的修改：`DerivedLoadCommand` 的可算條件加上「`external/taipei-mrt-exits/` 至少有一份快照」，不符合時那一天失敗、訊息帶出 `bin/rails external:mrt_exits`。驗證：`spec/models/derived_load_command_spec.rb` 以沒有 `external/` 的暫存資料根目錄斷言 Scenario「No entrance snapshot」（結束碼非零、訊息含 `bin/rails external:mrt_exits`、資料庫沒有那一天）；既有的 example 仍全綠。 [after: 3.1]

## 4. 路線頁

- [x] 4.1 實作 Overlap share and overlap stretches 與 On-board counts along a stretch，套用 design「重疊路段的車上人數沿用載客剖面的值」：路線頁的查詢物件，對一組已寫入的日子，以最新那一天的站牌給每個方向的站牌數與 300、500、800 公尺的重疊度（門檻是常數）、500 公尺下的重疊路段（方向、起訖站序與站名、站數），以及每段各時段的中位數、p90、趟數；站牌沒有距離時回報「需要重算」而不是 0%；不選車牌欄位。驗證：spec 以灌入的資料斷言 Scenario「Shares and stretches of one direction」（900、400、250、450、700 公尺得 20%、60%、80%，路段第 1 到 3 站）、「Single near stop」、「Pooled counts」（10、20、30 得 2 趟、中位數 20.0、p90 28.0），以及距離為空時的「需要重算」。 [after: 3.2]
- [x] 4.2 實作 Page content 與 Data limitations on the page 的修改，套用 design「頁面只報數字，不標示門檻」：新增「與捷運重疊」的 ViewComponent（`bin/rails g view_component:component` 產生、文案放同層 `.yml`），放在折返停留與載客剖面之間，顯示每個方向三種門檻的重疊度、500 公尺的重疊路段與每段各時段的車上人數、出入口快照日；資料限制元件加上重疊定義的限制。驗證：component spec 斷言重疊度、路段與車上人數的表格內容，以及距離為空時顯示需要重算；`spec/requests/routes_spec.rb` 的區塊順序改成摘要、行駛時間、折返停留、捷運重疊、載客剖面、資料限制（Scenario「Overlap block in place」）並斷言 Scenario「Distances missing」；`spec/requests/route_page_fixture_spec.rb` 以 fixture 寫入後斷言頁面出現快照日 2026-10-19、仍沒有任何車牌、Bullet 不報 N+1。資料限制的文字是固定文案，照專案的 TDD 規則不寫斷言，只斷言這一節存在。 [after: 4.1]

## 5. 文件與真資料

- [x] 5.1 文件：`docs/spectra/LANGUAGE.md` 新增「捷運重疊」一條（定義、在資料或程式碼裡、邊界、不要用），`analysis/README.md` 加上 `mrt_overlap.sql` 的輸入輸出與 `external:mrt_exits`，`docs/data-sources.md` 把捷運車站出入口座標的狀態改成已抓、寫明 Big5 與存放位置。驗證：內容審查對照 design 的 Implementation Contract 與 `mrt-overlap` spec。 [after: 4.2]
- [x] 5.2 以真資料驗收：`TURNAROUND_DATA` 指到資料根目錄（不寫進任何檔案），執行 `bin/rails external:mrt_exits`，再 `bin/rails derived:load ROUTE=15373 FROM=2026-10-19 TO=2026-10-21`；`/routes/15373?day=2026-10-19` 的去程 500 公尺重疊度 45.7%、返程 40.0%，與 design 的試算相同（出入口快照若已更新，記下新數字與差異）。驗證：rake 輸出、頁面數字對照 design；用 `bin/dev` 開頁面做人工內容審查，確認「與捷運重疊」一塊與資料限制都在、沒有任何「超過門檻」的字樣、沒有車牌。 [after: 5.1]
