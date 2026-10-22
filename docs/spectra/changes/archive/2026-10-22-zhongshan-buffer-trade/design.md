## Context

路線頁 `/routes/:route_id` 現在依序有摘要、行駛時間、折返停留、與捷運重疊、載客剖面、資料限制六塊。每一塊是一個查詢物件（`app/models/route_page/`）配一個 ViewComponent，查詢物件拿 `RoutePage::Coverage#route_days` 回的那幾天，在讀頁面時用 SQL 彙總衍生表（決策「衍生表存逐趟資料，彙總在讀頁面時用 SQL 算」，zhongshan-route-page）。

已核對的事實：

- `layovers` 每列有 `route_day_id`、`bus_id`、`go_back`、`end_time`、`next_start_time`（timestamptz），只收相鄰兩趟都完整、同一路線 `Id` 的配對（`layover-metrics` 的 Layover definition）。`RoutePage::LayoverStats` 用 `extract(epoch FROM next_start_time - end_time) / 60` 算分鐘，`SHORT_MINUTES = 15`。
- `trips` 每列有 `route_day_id`、`bus_id`、`band`、`start_time`、`end_time`、`completeness`。
- `RoutePage::Coverage` 在 `range`、`day` 不合法時丟 `RoutePage::Coverage::InvalidParameter`，`RoutesController#show` 把它轉成 400。
- 前端：`app/frontend/entrypoints/application.js` 載入 `@hotwired/turbo-rails`、`alpinejs` 與 `alpine-turbo-drive-adapter`；Gemfile 有 `turbo-rails`。
- 中山幹線 15373，衍生表裡 2026-10-19 到 10-21 三天（量到的，2026-10-22 查詢）：

  | 日期 | 趟次 | 車數 | 量到的折返停留 | 不到 15 分鐘 | 補到 15 分鐘的差額 | 中位數 |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | 10-19 | 163 | 32 | 77 | 76.6% | 653 分鐘 | 2.5 分鐘 |
  | 10-20 | 179 | 35 | 81 | 76.5% | 710 分鐘 | 2.6 分鐘 |
  | 10-21 | 168 | 35 | 89 | 71.9% | 707 分鐘 | 4.1 分鐘 |

  量到的折返停留不到趟次的一半，所以涵蓋率一定要出現在頁面上。

詞彙依 `docs/spectra/LANGUAGE.md`：折返停留、趟次、換休息試算、路線頁、衍生表、台北日。「緩衝」照詞彙表是班表上留的時間，跟實測的折返停留不同；這裡的「加緩衝」就是那個意思：假設班表在每次折返留 B 分鐘。

## Goals / Non-Goals

**Goals:**

- 站長與公運處在路線頁上看得到：每趟加 B 分鐘緩衝，每天多幾車時、尖峰小時多幾台車，用一個誠實的區間表達。
- 目前的休息達成率與涵蓋率跟著數字一起出現。
- 緩衝分鐘數可以拉、網址可以分享。

**Non-Goals:**

- 縮駛、改區間、離峰改預約；受影響乘客數。
- 推算量不到的折返停留。
- 駕駛工時、排班、班表產生；門檻與合規標示。
- 平日與假日分開、其他路線、健檢卡加試算、排程與部署。
- 修改已驗過的趟次、折返停留、載客剖面、行駛時間、捷運重疊定義。

## Decisions

### 增加車時用下限與上限的區間，不給單一數字

對緩衝 B 分鐘與量到的每次折返停留 m 分鐘：

- 下限（補足）：`max(B − m, 0)` 加總。只有不到 B 分鐘的折返停留需要補。
- 上限（每趟加）：`B` 乘以量到的折返停留次數。這是 `docs/100-days.md` 試辦項目的算法。

兩者除以涵蓋的天數（`route_days` 筆數）再除以 60，報每天平均車時，四捨五入到一位小數。

理由：折返停留包含回場、加油、洗車、等發車，是休息的上限（`layover-metrics` 的 Purpose）。停了 15 分鐘不等於休了 15 分鐘，所以只補差額會低估；但每次都加滿 B 分鐘又忽略了已經停夠的那些。真實的成本落在兩者之間，給區間比挑一個點誠實。

替代方案：只給下限（看起來便宜，會被讀成成本就這麼多）；只給上限（等於說量到的折返停留完全沒有休息）。

### 增加車數按折返停留結束的台北小時估

把每次折返停留的增加分鐘（下限與上限各算一次）按 `end_time` 的台北小時分組，每小時的加總除以 60 再除以涵蓋天數，得到那個小時平均多佔幾台車；取最大的那個小時報出，四捨五入到一位小數，並標出是幾點。同時報涵蓋天數裡每天平均用到幾台車（每天不同車牌數的平均）作對照。

理由：路線要加幾台車由最忙的時段決定，不是全天平均。一台車在一小時裡多停 60 分鐘就是多佔一台車，這是平均佔用的算法，不需要排班模型。

替代方案：按現有的時段（早尖峰、日間、晚尖峰、其他）分組。時段的起訖小時只寫在 `analysis/params.sql`，Rails 不知道每段幾小時，「其他」時段的長度也不固定；照搬到 Ruby 會讓同一個定義寫在兩個地方。按小時分組不需要任何時段定義。

### 只報量到的折返停留，標出涵蓋率

試算只用 `layovers` 裡的折返停留，不推算其他趟次。頁面同時報量到的折返停留次數與同期的趟次數。

理由：量不到的趟次（當天最後一趟、下一趟換附屬路線、不完整的趟次）情況本來就跟量到的不一樣，按比例推全天等於假設它們一樣。

### 休息達成率是不少於 B 分鐘的比例

量到的折返停留中 `m >= B` 的比例。B 是 15 時，它等於折返停留那一塊「不到 15 分鐘」的另一半，兩塊對得上。頁面寫明這是上限。

### 緩衝分鐘數用網址參數 `buffer`，在 server 算

`buffer` 是 0 到 20 的整數，預設 15；不是整數或超出範圍回 400，跟 `day`、`range` 一樣。拉桿是一個 `<input type="range" name="buffer">`，放在 GET 表單裡，表單帶著目前的 `day` 與 `range` 當 hidden 欄位；放開拉桿（`change` 事件）時用 Alpine 送出表單。整塊包在 `turbo_frame_tag "buffer-trade"` 裡，表單在 frame 內送出，只替換這一塊；frame 設 `data-turbo-action="advance"`，網址會更新成帶 `buffer` 的版本，可以分享。拉的過程中用 Alpine 顯示目前的分鐘數。

理由：計算留在 Ruby 的查詢物件裡，用 RSpec 直接測；網址就是試算的完整狀態。zhongshan-route-page 的非目標「換休息試算、任何互動式試算」是那個 change 的範圍界線，不是拒絕，這裡不推翻任何決策。

替代方案：在瀏覽器裡用 JavaScript 算（要把每次折返停留的分鐘數送到頁面上，計算邏輯不在 RSpec 能測的地方）。

### `buffer` 不合法時沿用 `RoutePage::Coverage::InvalidParameter`

`RoutePage::BufferTrade.minutes(param)` 把參數轉成整數，空值回 15，不合法丟 `RoutePage::Coverage::InvalidParameter`。控制器已經把這個例外轉成 400，不用多一個 rescue。

## Implementation Contract

**Behavior**

- `GET /routes/15373?day=2026-10-19&buffer=10` 回 200，頁面在折返停留之後、與捷運重疊之前有一塊 `section[data-section="buffer-trade"]`，用 10 分鐘算。
- 沒有 `buffer` 時用 15。`buffer=21`、`buffer=-1`、`buffer=abc`、`buffer=1.5` 都回 400。
- 這一塊顯示：緩衝分鐘數；涵蓋的天數；量到的折返停留次數與同期趟次數；休息達成率（百分比一位小數）；增加車時的下限與上限（每天平均，一位小數）；增加車數的下限與上限（最忙那個小時的平均，一位小數）與那個小時；每天平均用到幾台車（一位小數）。
- 量到的折返停留是 0 次時，這一塊說明沒有量到折返停留，不顯示達成率與增加量。
- 頁面不顯示任何車牌，不標示任何門檻或合不合規。

**Interface / data shape**

- `RoutePage::BufferTrade`
  - `DEFAULT_MINUTES = 15`，`MINUTES_RANGE = 0..20`
  - `self.minutes(param) -> Integer`：空值回 `DEFAULT_MINUTES`；只接受 `/\A\d+\z/` 且落在範圍內的值，否則丟 `RoutePage::Coverage::InvalidParameter`。
  - `new(route_days, minutes:)`
  - `#minutes`、`#n_days`、`#n_layovers`、`#n_trips`
  - `#achieved_share -> Float | nil`：沒有折返停留時是 `nil`
  - `#vehicle_hours -> Bound(lower:, upper:)`：每天平均車時
  - `#peak -> Bound(lower: Peak(hour:, vehicles:), upper: Peak(hour:, vehicles:))`：同一個小時有並列時取較早的小時
  - `#vehicles_per_day -> Float`
- `BufferTradeComponent.new(buffer_trade:, coverage:)`，同層 `.yml` 有 tw、zh-TW、en。
- `RoutesController#show` 先算 `@buffer_minutes = RoutePage::BufferTrade.minutes(params[:buffer])`，再建 `Coverage`；兩者任一丟 `InvalidParameter` 都回 400。

**Failure modes**

- 不合法的 `buffer`：400，跟 `day`、`range` 一致。
- 涵蓋的天數沒有任何折返停留：這一塊顯示說明，不報數字，不會除以零。
- 選的那天沒有資料：跟其他塊一樣整塊不出現（`@coverage.data?` 為 false 時不 render）。

**Acceptance criteria**

- `spec/models/route_page/buffer_trade_spec.rb` 用手算的資料驗證下限、上限、達成率、最忙小時與並列取早、沒有折返停留、多天平均。
- `spec/components/buffer_trade_component_spec.rb` 驗證數字出現在對應的 `data-*` 欄位、表單有 `input[type=range][name=buffer][min=0][max=20]` 與 hidden 的 `day`、`range`、frame id 是 `buffer-trade`。
- `spec/requests/routes_spec.rb` 驗證區塊順序、`buffer` 的預設與 400。
- 真資料驗收：`buffer=15`、`day=2026-10-19` 時，量到的折返停留 77 次、趟次 163、達成率 23.4%、增加車時下限 10.9、上限 19.3（由上面量到的 653 分鐘與 77 次推得：653 ÷ 60 = 10.88，77 × 15 ÷ 60 = 19.25）。`bin/dev` 打開頁面拉動拉桿，只有這一塊重新載入、網址帶上 `buffer`。

**Scope boundaries**

- 在範圍內：查詢物件、元件、控制器參數、路線頁位置、資料限制文案、`docs/spectra/LANGUAGE.md` 的「換休息試算」一條。
- 不在範圍內：任何 migration、`analysis/` 的 SQL、`derived:load`、健檢卡、其他動作與受影響乘客。

## Risks / Trade-offs

- [下限與上限差將近一倍，讀者可能只記住其中一個] → 兩個數字並列、同樣大小，說明各自代表什麼，不挑一個加粗。
- [按小時平均會低估瞬間的需求：一台車在 7:55 結束、要補 12 分鐘，那 12 分鐘全算在 7 點] → 頁面寫明這是按小時平均的估計，不是排班結果。用 7 天範圍時每小時的樣本才夠，單日的最忙小時可能只有幾次折返停留。驗收時量到的（15373，緩衝 15 分鐘）：下限的最忙小時單日各是 17 點 1.3 台（10-19）、19 點 1.4 台（10-20）、9 點 1.2 台（10-21），三天合起來是 9 點 1.1 台；上限三個單日都是 9 點（2.0、1.8、2.0 台），合起來 9 點 1.9 台。下限的最忙小時單日不穩定，引用時要用多天的範圍。
- [量到的折返停留不到趟次的一半，增加量只代表量到的那一半] → 涵蓋率跟數字放在同一行，資料限制再寫一次。
- [達成率在 B = 0 時恆為 100%] → 這是定義的結果，不特別處理。
