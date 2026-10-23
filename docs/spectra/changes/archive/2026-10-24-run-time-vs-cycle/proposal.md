## Why

這個 change 服務三樣交付物的第一樣路線健檢卡在網站上的形式，也就是路線頁：在每條路線的頁面上多一塊，回答「跑得完嗎」。它需要的資料全部已經在衍生表裡：`trips` 的趟次與 `layovers` 的折返停留；不讀原始檔、不讀靜態快照，不需要新的資料來源。

專案最主要要解決的問題寫在 `docs/background.md`「機制：班表是怎麼把人逼快的」：班表給的時間比一趟實際要跑的時間少，差額由駕駛用開快或少休息吸收。路線頁現在把這件事拆在兩塊裡，行駛時間一塊、折返停留一塊，讀者要自己把兩個數字湊起來才看得出缺口。這個 change 把缺口直接量出來：

- 「來回一趟」：同一台車從停車端發車，經過另一端，回到停車端，一共花了幾分鐘。這就是報導與駕駛口中的「一趟」，等於兩個趟次。
- 「週期」：同一台車回到停車端，到下一次回到停車端的間隔。這是業者實際維持的節奏，班表給一台車跑一個來回的時間就藏在這裡。
- 週期減來回一趟，就是在停車端剩下的折返停留。

`docs/background.md`「四個平日量到的缺口」已經用 2026-10-19 到 10-22 四個平日算過一次（量到的，不能引用）：中山幹線與 251區 最緊的一成週期跟來回一趟的中位數幾乎一樣長，251 的週期則留了五十幾分鐘。同一套量法分得出哪條線在逼人、哪條線沒有。現在做，是因為這張表已經是 demo 的論點，卻還只在投影片與文件裡，不在每天更新的頁面上。

## What Changes

- 新的衍生指標「來回一趟」與「週期」，在讀頁面時從 `trips` 與 `layovers` 算，不改 `analysis/` 的 SQL、不加衍生表：
  - 起算的方向由 `config/route_page.yml` 的兩端性質決定：從停車端發車的那個方向是前段，另一個方向是後段。三條已設定的路線前段都是去程。
  - 來回一趟：前段趟次的起站離站，到同一台車接著那趟後段趟次的末站到站；兩趟都要完整、兩趟之間在 `layovers` 裡有配對，前段起點是到站時刻或後段終點是離站時刻的不算，跟 `run-time` 排除的規則一樣。
  - 週期：同一台車相鄰兩次後段趟次到末站的間隔，中間經過一個前段趟次，兩段相接都要在 `layovers` 裡有配對；兩次到站都要是實際量到的到站時刻。用到站而不用發車，是因為停車端的離站事件常常漏掉（中山幹線四個平日裡去程完整趟次有三成起點是到站時刻，量到的），到站事件幾乎不漏。
  - 兩者都按前段趟次發車的台北小時分組，給筆數與百分位數：來回一趟 p50 與 p85，週期 p10 與 p50，線性內插、一位小數；另加一列全天。一列筆數少於 5 就標樣本少，門檻跟行駛時間同一個常數。
- 路線頁在折返停留那張卡之後、換休息試算之前，多一張卡：小標是指標名，標題是一句問題；一段說明寫出這條路線的起站與末站站名；一句用全天那列的數字寫成的白話；兩張按發車小時的表，來回一趟一張、週期一張，640 px 以下一次看一張、用跟行駛時間相同的切換方式。不上色、不標門檻、不出現「合規」。
- 區塊導覽多一個連結，順序跟頁面一致。
- 資料限制多一條：來回一趟與週期只用兩段都量到端點、而且在 `layovers` 裡配得起來的趟次；一台車當天第一個來回沒有週期；週期是車的節奏，不是某個駕駛的班表。
- `docs/spectra/LANGUAGE.md` 的「指標」多「來回一趟」與「週期」兩條；「趟次與班次」的邊界補上「報導與駕駛口中的一趟是一個來回，等於兩個趟次」。

## Non-Goals

非目標，這個 change 不做：

- 業者公告的班距對每小時實際發車數。它要把靜態快照裡的 `GetSemiTimeTable.gz` 與 `GetTimeTable.gz` 寫進一張新的衍生表才能在頁面上讀（`docs/decisions.md` 第 2 條：Rails 只查衍生表），而且早尖峰發車數跟班距要求的差距還沒查證：中山幹線四個平日 07 時去程平均一小時 5 班，班表要求 4 到 6 分一班（量到的，原因未查）。另開 change。
- 重點數字那張卡加新的數字。`02-route-page-mobile-first` 的非目標「重點數字以外的新彙總值…卡上只放表格裡已經有的值」照舊；這一塊自己的白話句子只用它自己表格裡全天那列的值。
- 用顏色或門檻標示任何數字的好壞（`route-page-charts`、`01-route-page-visual-refresh`、`02-route-page-mobile-first` 三次的非目標照舊），包括「週期比來回一趟短」這種對比。頁面只並排數字。
- 推算量不到的來回與週期：起點或終點漏掉的趟次、兩趟之間跑了別條路線的配對，只不算，不補。`layover-endpoints` 與 `zhongshan-buffer-trade` 否決過推算，理由是量不到的趟次情況本來就跟量到的不一樣。
- 改變趟次、行駛時間、折返停留、班次串的定義；改 `analysis/` 的 SQL、`bin/health-card`、衍生表的結構；一致性測試不需要新的 SQL 對照，因為健檢卡沒有這兩個指標。
- 從停車端的「發車」算週期。中山幹線停車端的離站事件漏得太多，照 `run-time` 的規則排除之後，四個平日只剩 39 個週期（量到的）；到站對到站有 101 個。
- GPS 速度、搶黃燈本身。資料看不到黃燈，只看得到缺口。
- 排程與部署、最近 30 天、其他路線。

資料限制與假設：車不等於人，週期是一台車的節奏，雙班制下一台車兩個人開，對不回單一駕駛；來回一趟與週期只用兩段都量到端點的趟次，10 秒輪詢漏掉起站或末站的趟次不算，所以筆數少於趟次數；跨小時檔的重複在趟次重建前已去除；車上人數不在這個 change 裡。

## Capabilities

### New Capabilities

- `round-trip-cycle`: 來回一趟與週期的定義、排除規則、起算方向與按發車小時的彙總。

### Modified Capabilities

- `route-page`: 「Page content」多一塊並改順序；「Section links」從六個連結變七個；「Data limitations on the page」多一條陳述；新增「Round trip and cycle block」描述這張卡的內容。

## Impact

- 新增：app/models/route_page/cycles.rb、spec/models/route_page/cycles_spec.rb、app/components/cycle_table_component.rb、app/components/cycle_table_component.html.erb、app/components/cycle_table_component.yml、spec/components/cycle_table_component_spec.rb。
- 修改：app/views/routes/show.html.erb（多一張卡）、app/components/section_nav_component.rb 與 app/components/section_nav_component.yml（多一個連結）、app/components/data_limitations_component.yml（多一條）、spec/requests/routes_spec.rb（區塊順序與七個連結）、spec/requests/route_page_fixture_spec.rb（fixture 的數字）、docs/spectra/LANGUAGE.md（兩條新詞與一條邊界）。
- 不碰：analysis/、bin/health-card、db/、lib/tasks/、首頁、RouteSummaryComponent、BufferTradeComponent、RunTimeTableComponent。
- 跟進行中的 `home-origin-story` 重疊：它也要改 docs/spectra/LANGUAGE.md 的「趟次與班次」邊界，寫的是同一句話；兩個 change 哪個先 archive，後面那個就只確認那句話已經在。
- 不加 migration、不加依賴、不改 `derived:load`。讀頁面多兩個查詢，Bullet 在測試環境會檢查 N+1。
