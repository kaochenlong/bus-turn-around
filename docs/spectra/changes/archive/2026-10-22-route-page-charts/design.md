## Context

路線頁（`/routes/:route_id`）目前依序是摘要、行駛時間、折返停留、換休息試算、捷運重疊、載客剖面、資料限制，全部是表格。專案的兩個核心問題「折返點實際能休幾分鐘」「重疊路段實際載多少人」的答案都在頁面上，但要逐列對照才看得出來。

中山幹線 2026-10-19 到 10-21 三天（量到的，開發資料庫）：

- 折返停留共 333 筆。用健檢卡的分組（0、5、10、15、30、60 分鐘），去程結束（青年公園(馬場町)）214 筆是 201、10、3、0、0、0；返程結束（職能發展學院二）119 筆是 11、24、16、29、16、23。
- 333 筆的下一趟全部是另一個方向（去程接返程 214 筆、返程接去程 119 筆），沒有同方向接同方向的。返程起站是青年社宅（seq 46），去程起站是職能發展學院二（seq 0）。
- 500 公尺內有捷運出入口的站：去程 seq 17 到 37、返程 seq 57 到 74，各是一段連續的站。
- 每站中位數的最大值：去程早尖峰 28.5、日間 19.0、晚尖峰 37.0、其餘 12.0；返程早尖峰 52.0、日間 18.0、晚尖峰 27.0、其餘 17.0。

現有程式：
- `RoutePage::LayoverStats` 算百分位數，不算分組筆數。
- `RoutePage::LoadProfile#rows` 給每個方向、時段、站的中位數與 p90。
- `RoutePage::MrtOverlap#stretches` 每一段都會再查一次那段的車上人數。
- 前端只有 Turbo 與 Alpine。`app/frontend/stylesheets/application.css` 已有 `[x-cloak]` 的規則。
- 分組下界在 `analysis/params.sql` 的 `layover_bin_lower_bounds`，健檢卡的 JSON 輸出 `bin_lower_bounds` 與 `bin_counts`。`spec/models/route_page/card_consistency_spec.rb` 已經用同一份 fixture 比對路線頁與健檢卡的數字。

## Goals / Non-Goals

**Goals:**

- 第一次打開路線頁的人，在摘要下面先看到兩張圖：兩端的折返停留分佈、沿線車上人數與捷運重疊段的位置。
- 圖的數字跟下面的表格、健檢卡是同一批趟次，不會出現第二套定義。

**Non-Goals:**

- 拿掉或改寫任何表格。
- 修改任何指標定義。
- 標示審議門檻或合規顏色。
- 查證青年公園端的折返停留。
- 健檢卡加圖、其他路線、平假日分開。
- JS 圖表套件、提示框、縮放、動畫。

範圍內：`RoutePage::LayoverDistribution`（新）、`RoutePage::LoadProfile#stops`（新方法）、`RoutePage::MrtOverlap#stretch_ranges`（新方法）、`LayoverChartComponent`、`LoadChartComponent`、`app/views/routes/show.html.erb` 的順序。
範圍外：`analysis/` 的任何 SQL、衍生表結構、`bin/health-card`、現有表格元件。

## Decisions

### 圖由伺服器輸出成內嵌 SVG，不用圖表套件

ViewComponent 直接算座標、輸出 `<svg>`。每根長條、每個點、每段底色帶都帶 `data-*` 屬性，元件測試用 Nokogiri 驗數字，跟現有表格元件的測法一樣。

不選 Chart.js 這類套件，原因有三：
- 要新增 npm 相依。
- 數字只存在 JS 裡，元件測試看不到。
- 頁面要等 JS 才有圖。

圖的尺寸用 `viewBox` 加 `width: 100%`，手機寬度會跟著縮放。每張 `<svg>` 帶 `role="img"` 和一句 `aria-label`；精確數字仍在下面的表格。

### 分組下界在 Ruby 再寫一次，由一致性測試守住

`RoutePage::LayoverDistribution::BIN_LOWER_BOUNDS = [0, 5, 10, 15, 30, 60]`。`analysis/params.sql` 是 DuckDB 的變數，Rails 讀不到。

`card_consistency_spec.rb` 新增一個例子，比對同一份 fixture 上的這兩組：
- 健檢卡的 `bin_lower_bounds` 對 Ruby 的常數。
- 每個方向的 `bin_counts` 對 Ruby 算出的筆數。

兩邊有一邊改了，這個測試就會失敗。

### 圖的標題寫「末站 → 下一趟起站」，起站取另一個方向的起站

標題寫出量的是哪兩個點：末站到站，到下一趟從起站離站。

下一趟起站取「另一個方向的起站」（最新那一天 `route_day_stops` 裡，另一個方向 seq 最小的站），不逐筆去查下一趟是哪個方向。根據是上面量到的 333/333：下一趟全部是另一個方向。

如果之後別的路線出現同方向接同方向的折返停留，這個標題會不準，那時再改成逐筆查。

這個決定的用意在青年公園那一端：末站是馬場町，下一趟卻從青年社宅出發。標題把兩個站名都寫出來，讀的人看得到這組數字量的是兩個不同的站。

### 長條長度在同一個方向內按筆數比例畫

最長的那根長條等於該方向的最大筆數。兩個方向各用各的比例。

去程 214 筆、返程 119 筆，總數不同。如果兩個方向用同一個比例，返程每根長條都短，讀的人會先看到「去程比較多」，而不是「兩端分佈形狀不同」。每根長條旁邊寫出筆數。

15 分鐘處畫一條分隔線，標「15 分鐘」，所有長條用同一個顏色，不用紅綠標示好壞。這跟 `zhongshan-mrt-overlap` 的決策「標示門檻會被讀成官方認定」一致：15 分鐘是現有表格「不到 15 分鐘」那一欄，不是審議門檻。

### 沿線人數圖：同一個方向四個時段共用縱軸，預設早尖峰

縱軸的頂端取該方向四個時段裡最大的中位數，再往上取到 10 的倍數。去程是 37.0 → 40，返程是 52.0 → 60。

共用縱軸是為了切換時段時看得出高低：如果各時段自動縮放，日間的 19 人會畫得跟晚尖峰的 37 人一樣高。

四個時段都在伺服器上畫好，用 Alpine 的 `x-show` 切換。早尖峰以外的三組，以及切換按鈕，都帶 `x-cloak`。沒有 JS 時只看得到早尖峰，按鈕不出現。

只畫中位數，不畫 p90。p90 留在表格裡；兩條線會讓圖的重點從「這一段載多少人」變成「分佈多寬」。

某站在某個時段沒有人數時，線在那裡斷開，不連到下一站，也不補值。

### 重疊段用 `MrtOverlap#stretch_ranges`，不查車上人數

新增 `stretch_ranges`，回傳 `{ go_back => [first_seq..last_seq, ...] }`，跟 `stretches` 用同一個 `runs` 切法，只是不呼叫 `loads`。`stretches` 改成從 `runs` 組出來，行為不變。

`needs_reload?` 為真時，`stretch_ranges` 回傳空的 Hash，圖上就不畫底色帶。

圖只用底色標出重疊段的位置，旁邊寫出兩端的站名，不寫「可被捷運取代」。

### 沿線人數圖的橫軸取最新那一天的站序

新增 `LoadProfile#stops`，回傳最新那一天 `route_day_stops` 的 `(go_back, seq, stop_name)`，依方向與 seq 排序。

橫軸用這份站序，不用 `rows` 裡出現過的 seq：一站在所有時段都沒有人數時，橫軸上仍要有它的位置，線在那裡斷開。

### 兩張圖放在摘要後面，表格順序不變

頁面順序變成：摘要、折返停留分佈圖、沿線人數圖、行駛時間、折返停留表、換休息試算、捷運重疊、載客剖面表、資料限制。

兩張圖的標題各是一句問題，文案放在元件的 `.yml`，屬於固定文案，照專案規則不寫斷言。

## Implementation Contract

**看得到的行為**

- `/routes/15373?day=2026-10-21&range=7d` 在摘要下面先出現兩張圖：
  - 折返停留分佈：每個方向一張橫條圖。去程那張的標題有「青年公園(馬場町)」與「青年社宅」，返程那張的標題有兩個「職能發展學院二」。
  - 沿線車上人數：兩個方向各一張折線圖，有早尖峰、日間、晚尖峰、其餘四個按鈕，去程 seq 17–37、返程 seq 57–74 有底色帶。
- 下面的表格跟現在一模一樣。

**介面**

- `RoutePage::LayoverDistribution.new(route_days)`
  - `BIN_LOWER_BOUNDS = [0, 5, 10, 15, 30, 60]`
  - `#directions` 回傳 `[Direction(go_back:, last_stop:, next_first_stop:, counts:)]`，依 `go_back` 排序。
  - 最新那一天有的方向都有一筆；沒有折返停留的方向 `counts` 全是 0。
  - 分鐘數用 `next_start_time - end_time`，跟 `LayoverStats` 相同。分組在 SQL 裡算，一次查詢。
- `RoutePage::LoadProfile#stops` 回傳 `[Stop(go_back:, seq:, stop_name:)]`，來自最新那一天。
- `RoutePage::MrtOverlap#stretch_ranges` 回傳 `{ Integer => [Range] }`。
- `LayoverChartComponent.new(layover_distribution:)`
  - `section[data-section=layover-chart]`
  - 每個方向一個 `[data-direction=<go_back>]`
  - 長條是 `[data-bin=<下界>][data-count=<筆數>]`
  - 分隔線是 `[data-divider=15]`
  - 沒有折返停留的方向是 `[data-no-layover]`
- `LoadChartComponent.new(load_profile:, mrt_overlap:)`
  - `section[data-section=load-chart]`
  - 每個方向一個 `[data-direction=<go_back>][data-scale-top=<頂端>]`
  - 每個時段一組 `[data-band=<band>]`，裡面的點是 `[data-seq][data-median]`
  - 底色帶是 `[data-span-from][data-span-to]`

**錯誤與邊界**

- 這段期間沒有任何資料：路線頁原本就不畫任何區塊（`@coverage.data?`），兩張圖也不畫。
- 一個方向在所有時段都沒有人數：畫出空的座標軸，縱軸頂端取 10。
- 沒有新的網址參數，也沒有新的 400。
- 這次不改動 SQL 階段、衍生表、健檢卡。

**驗證**

- 元件與模型的 RSpec。
- `card_consistency_spec.rb` 的分組一致性。
- `spec/requests/routes_spec.rb` 的區塊順序。
- 中山幹線真資料上的筆數，對照上面量到的 201/10/3 與 11/24/16/29/16/23。
- 用 `bin/dev` 開頁面截圖，看桌面與手機寬度。
