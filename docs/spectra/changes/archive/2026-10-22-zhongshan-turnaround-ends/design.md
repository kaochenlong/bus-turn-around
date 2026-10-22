## Context

路線頁 `/routes/:route_id` 現在依序有摘要、折返停留分佈圖、沿線人數圖、行駛時間、折返停留表、換休息試算、捷運重疊、載客剖面表、資料限制九塊（決策「兩張圖放在摘要後面，表格順序不變」，route-page-charts）。每一塊是一個查詢物件（`app/models/route_page/`）配一個 ViewComponent，查詢物件拿 `RoutePage::Coverage#route_days` 回的那幾天，在讀頁面時用 SQL 彙總衍生表（決策「衍生表存逐趟資料，彙總在讀頁面時用 SQL 算」，zhongshan-route-page）。

已核對的事實（2026-10-22）：

- `layovers` 每列有 `route_day_id`、`bus_id`、`go_back`、`end_time`、`next_start_time`；`go_back` 是結束那趟的方向。所以「路線的一端」在資料裡就是「結束在那一端的趟次方向」：中山幹線去程（0）結束在青年公園(馬場町)，返程（1）結束在職能發展學院二。
- `RoutePage::LayoverStats` 與 `RoutePage::LayoverDistribution` 已經按 `go_back` 分列、分圖；`RoutePage::BufferTrade` 的 `HOURS_SQL` 沒有 `go_back` 條件，兩端混在一起算。
- 路線清單在 `config/route_page.yml`：`shared` 的 `route_ids` 只有 15373，`test` 另外列了 fixture 路線 9001；`RoutePage.route_ids` 用 `Rails.application.config_for(:route_page)` 讀，`RoutesController#show` 用它判 404。railties 的 `config_for` 把 `shared` 與環境那一節深合併（`shared.deep_merge(config)`），所以清單改成對應表之後，`test` 只需要列 9001，15373 由 `shared` 帶入。
- 中山幹線兩端（靜態快照 2026-10-21 的 `GetStop.gz`）：職能發展學院二兩個方向的站牌（`Id` 16648 與 16738）相距約 10 公尺；去程末站青年公園(馬場町) 到返程起站青年社宅約 200 公尺。業者是光華巴士，三條附屬路線都掛天東站（`GetOrgPathAttribute.gz`）；`GetProvider.gz` 沒有營業站的座標。
- 青年公園端開過去就走的證據是人看的：2026-10-20 的 75 筆折返停留中位數 1.9 分鐘，`bus_data` 的 GPS 沒有離開馬場町到青年社宅這一段。這段話在工作樹裡 `docs/spectra/LANGUAGE.md`「起站、末站、折返點、調度站」那條還沒 commit 的修改裡。
- 衍生表裡 15373 的 2026-10-19 到 10-21 三天（量到的，緩衝 15 分鐘）：

  | 結束那趟 | 筆數 | 不到 5 分鐘 | 不少於 15 分鐘 | 補到 15 分鐘的差額 | p50 | p90 |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | 去程，青年公園(馬場町) | 214 | 201 | 0 | 2,735 分鐘 | 1.9 | 2.9 |
  | 返程，職能發展學院二 | 119 | 11 | 68 | 346 分鐘 | 17.2 | 153.9 |

  現在的頁面（兩端混算）：每天多 17.1 到 27.7 車時，達成率 20.4%。只算返程結束那一端：每天多 1.9 到 9.9 車時，達成率 57.1%；最忙小時下限是 19 點 0.4 台，上限是 12 點 0.9 台（12 點與 20 點各 11 筆並列，取較早的）。三天 510 趟、102 車日，每天平均 34.0 台車。

詞彙依 `docs/spectra/LANGUAGE.md`：折返點、末站、起站、折返停留、換休息試算、路線頁、衍生表。這個 change 給「折返點」加一個屬性：停車或開過去就走。按詞彙表的定義，青年公園端仍然是折返點（一趟結束、下一趟開始的地方），只是車不停。

## Goals / Non-Goals

**Goals:**

- 系統裡有「折返點的性質」：每條有路線頁的路線，兩端各是停車或開過去就走，查證後寫進設定，缺了就擋下。
- 換休息試算只以停車端的折返停留為基礎，數字對得上站長能排的班；另一端的筆數照報並標明不算。
- 路線頁的折返停留表、分佈圖與試算那一塊，讓讀的人一眼看到哪一端車不停。
- 詞彙表記下這個屬性與青年公園端這個邊界案例。

**Non-Goals:**

- 折返點設施（末站 300 公尺內的公廁、能不能停大車）：下一個 change。
- 從折返停留分佈或 GPS 自動推哪一端停車。
- 假設青年公園端之後設了停車位、兩端一起加緩衝的試算；那是一個建議動作，等設施盤點之後再談。
- 區分停車端是調度站還是路邊：`GetProvider.gz` 沒有座標確認不了，折返停留本來就是含回場在內的上限。
- 改 Markdown 健檢卡（`bin/health-card`）：折返停留的定義沒變，卡的「全部」那列照舊。
- 改班次串：開過去就走那一端的折返停留全部不到 15 分鐘，本來就不進休息額度（決策「班次串不跟著放寬」，layover-endpoints）。
- 修改趟次、折返停留、行駛時間、載客剖面、捷運重疊的定義；其他路線；平日與假日分開；排程與部署。

## Decisions

### 折返點的性質是逐路線查證後寫進設定的事實，不從資料推

每條有路線頁的路線，在 `config/route_page.yml` 裡對兩端各寫一個值：`stop`（車在這一端停）或 `pass_through`（開到下一趟的起站，不停）。鍵是結束在那一端的趟次方向 `go_back`（0 或 1）。值旁邊用註解記查證的日期與證據。

理由：中山幹線的查證是人看 GPS 軌跡與兩站距離做的，不是一條規則算出來的。要自動推（例如那一端的折返停留 p90 不到 5 分鐘就算開過去就走），得先在幾條路線上看過它推得對不對；現在只有一條路線，寫成規則等於拿一個樣本定門檻。推錯的代價是試算整個換掉基礎，而且沒有人會發現。寫進設定的壞處是會過期：業者改折返方式時要有人改設定，資料限制要寫明。

替代方案：從折返停留分佈推（一個樣本定門檻，否決）；從閒置車 GPS 聚類推（留給設施那個 change 之後）。

### 路線清單改成以路線 Id 為鍵的對應表，兩端的性質缺一就擋下

`config/route_page.yml` 從 `route_ids` 列表改成 `routes` 對應表：

```yaml
shared:
  routes:
    15373:              # 中山幹線
      ends:
        0: pass_through # 去程結束在青年公園(馬場町)，下一趟從約 200 公尺外的青年社宅出發；2026-10-22 看 2026-10-20 的資料：75 筆折返停留中位數 1.9 分鐘，GPS 沒有離開這一段
        1: stop         # 返程結束在職能發展學院二

test:
  routes:
    9001:               # fixture 路線，兩端都停車，既有的數字不變
      ends:
        0: stop
        1: stop
```

`RoutePage.route_ids` 回對應表的鍵（整數陣列），`RoutesController#show` 判 404 的方式不變。`RoutePage.ends(route_id)` 回一個 `RoutePage::Ends`；由 `RoutePage::Ends.from_config(hash, route_id:)` 建，缺了 0 或 1 任一個方向、或值不是 `stop` 與 `pass_through` 之一，就丟 `RoutePage::Ends::InvalidConfiguration`，訊息寫出路線 `Id`、方向，值不對時也寫出那個值。檢查在讀的時候做，不另設 initializer。

理由：路線清單跟兩端的性質是同一件事（這條路線能不能上頁面、上去之後怎麼算），放在同一個項目裡，不會一邊加了路線另一邊忘了。缺了就擋，是因為預設成「兩端都停車」會讓新路線悄悄回到混算的試算。兩條路線的清單不值得一個 initializer；讀的時候丟錯，開發機第一次開頁面就看到，request spec 也會抓到。

替代方案：`route_ids` 旁邊另開一個 `ends` 對應表（兩份清單要同步，否決）；缺值時預設 `stop`（悄悄回到舊算法，否決）。

### 查詢物件與元件不讀設定，由控制器解出兩端的性質再傳進去

`RoutesController#show` 在 404 判定之後算 `@ends = RoutePage.ends(route_id)`；`app/views/routes/show.html.erb` 把 `@ends` 傳給 `RoutePage::BufferTrade.new(route_days, minutes:, ends:)`、`LayoverTableComponent.new(layover_stats:, ends:)`、`LayoverChartComponent.new(layover_distribution:, ends:)`。`RoutePage::LayoverStats` 與 `RoutePage::LayoverDistribution` 不改，所以 `spec/models/route_page/card_consistency_spec.rb` 比對的筆數、百分位數、分組筆數都不動。

理由：相依寫在簽章上，測試用字面的 `RoutePage::Ends` 就能試開過去就走的行為，不用對設定做 stub，也不用替每條合成路線補設定。

替代方案：查詢物件自己呼叫 `RoutePage.ends`（隱藏相依，每個用 9001 的測試都得先有它的設定，否決）。

### 試算只算停車端的折返停留，開過去就走那一端只報筆數

`RoutePage::BufferTrade` 的 `HOURS_SQL` 多一個條件：只取 `go_back` 在停車端清單裡的折返停留；另外數結束在開過去就走那一端的筆數。對外：`#n_layovers` 是停車端的筆數，也就是試算的基礎；新增 `#n_pass_through_layovers`；`#achieved_share`、`#vehicle_hours`、`#peak` 都只用停車端。停車端一筆都沒有時，`#n_layovers` 是 0，走既有的「沒有折返停留」分支，不會除以零。

理由：緩衝只能加在車停得下來的地方。把青年公園端 2 分鐘的「停留」補到 15 分鐘，不是任何站長排得出來的班；它佔了三天下限 3,081 分鐘裡的 2,735 分鐘，不拿掉，頁面上的數字對站長沒有用。

替代方案：保留混算的數字、另外加一行分端明細（標題數字仍差一個數量級，否決）；算「在開過去就走那一端設停車位之後兩端都補」（那是建議動作，要先知道停不停得下車，列為非目標）。

### 頁面上每一端標出性質：文案用「停車」與「開過去就走」，程式用 stop 與 pass_through

- 折返停留表：每一列（`tr[data-direction]`）加 `data-end-nature`，值是 `stop` 或 `pass_through`；多一欄寫「停車」或「開過去就走」。路線有開過去就走的一端時，表下面多一句說明：車到末站不停、直接開到下一趟的起站，這一端的折返停留不是休息機會。
- 分佈圖：每個方向的 `figcaption` 加 `data-end-nature`，標題句尾接上「停車」或「開過去就走」。
- 試算那一塊：涵蓋率那句改成報停車端的筆數；路線有開過去就走的一端時，多一句報那一端的筆數（`data-value="pass-through-layovers"`），寫明不是休息機會、不算；沒有這種一端時這個元素不出現。沒有停車端的折返停留時，說明文字寫「沒有量到停車端的折返停留」。
- 文案放各元件同層的 `.yml`（tw、zh-TW、en）。不用顏色、不標合不合規，`buffer-trade` 的「No threshold or compliance marking」照舊。

理由：「停車」與「開過去就走」是詞彙表那條修改裡已經用的說法，讀頁面的司機與站長一看就懂；程式用 `stop` 與 `pass_through`，照 `docs/decisions.md` 第 10 條程式碼全英文。

替代方案：第三種值「調度站」（確認不了，列為非目標）；只在試算那一塊標、表與圖不標（讀的人看到青年公園端 214 筆全在 0 到 5 分鐘，不知道那是車不停，否決）。

### 測試路線 9001 兩端都標停車，開過去就走的行為用明確傳入的性質測

`test` 環境的設定給 9001 兩端都是 `stop`，所以 `spec/models/route_page/buffer_trade_spec.rb`、`spec/components/buffer_trade_component_spec.rb`、`spec/components/layover_table_component_spec.rb`、`spec/components/layover_chart_component_spec.rb`、`spec/requests/route_page_fixture_spec.rb` 與 `spec/models/route_page/card_consistency_spec.rb` 既有的數字一個都不變。開過去就走的情境在 model spec 與 component spec 裡用字面建的 `RoutePage::Ends` 傳進去測；`RoutePage::Ends.from_config` 的錯誤用字面的 hash 測；`RoutePage.ends(15373)` 在 test 環境讀到的是 `shared` 的值，用它測「中山幹線去程 `pass_through`、返程 `stop`」。

理由：不動既有的手算值，新行為的測試資料自己寫清楚；不多造一條 fixture 路線。

替代方案：再加一條兩端不同的測試路線 9002（多一組設定與資料要維護，否決）。

## Implementation Contract

**Behavior**

- `GET /routes/15373?day=2026-10-21&range=7d&buffer=15` 回 200。試算那一塊報：涵蓋 3 天；停車端量到 119 次折返停留；開過去就走那一端 214 次，不算；同期 510 趟；達成率 57.1%；每天多 1.9 到 9.9 車時；最忙小時下限 19 點 0.4 台、上限 12 點 0.9 台；每天平均 34.0 台車。改之前同一頁報的是 333 次、20.4%、17.1 到 27.7 車時。
- 同一頁的折返停留表：去程那列末站青年公園(馬場町)，標「開過去就走」；返程那列末站職能發展學院二，標「停車」；筆數 214 與 119、百分位數與不到 15 分鐘的比例跟改之前相同。分佈圖兩個方向的標題帶同樣的標示。
- `GET /routes/9999` 仍回 404。`day`、`range`、`buffer` 不合法仍回 400。
- 設定裡某條路線缺一個方向或值不認得時，開那條路線的頁面丟 `RoutePage::Ends::InvalidConfiguration`，訊息含路線 `Id` 與方向；這是設定錯誤，故意讓它炸，不回退到舊算法。
- 頁面不出現任何車牌；不標任何門檻或合不合規。

**Interface / data shape**

- `config/route_page.yml`：`routes` 對應表，鍵是路線 `Id`（整數），每條有 `ends`，鍵 0 與 1，值 `stop` 或 `pass_through`，形狀見上面的決定。
- `RoutePage.route_ids -> Array<Integer>`：對應表的鍵。
- `RoutePage.ends(route_id) -> RoutePage::Ends`。
- `RoutePage::Ends.from_config(hash, route_id:)`：缺方向或值不對丟 `RoutePage::Ends::InvalidConfiguration`。`#nature(go_back) -> :stop | :pass_through`、`#stopping?(go_back)`、`#stopping_go_backs -> Array<Integer>`、`#pass_through_go_backs -> Array<Integer>`、`#pass_through? -> true | false`（有沒有任何一端是開過去就走）。
- `RoutePage::BufferTrade.new(route_days, minutes:, ends:)`：`#n_layovers` 是停車端的筆數；新增 `#n_pass_through_layovers`；`#n_days`、`#n_trips`、`#vehicles_per_day`、`#achieved_share`、`#vehicle_hours`、`#peak`、`#minutes` 介面不變，計算只用停車端。
- `LayoverTableComponent.new(layover_stats:, ends:)`、`LayoverChartComponent.new(layover_distribution:, ends:)`；`BufferTradeComponent.new(buffer_trade:, coverage:)` 簽章不變。
- 頁面上可斷言的標記：`[data-section=layovers] tr[data-direction][data-end-nature]`、`[data-section=layover-chart] figcaption[data-end-nature]`、`[data-section=buffer-trade] [data-value=pass-through-layovers]`。

**Failure modes**

- 設定缺漏或值不對：`RoutePage::Ends::InvalidConfiguration`，訊息含路線 `Id`、方向，值不對時含那個值；在開頁面時丟出，不在啟動時。
- 路線兩端都是 `pass_through`：試算基礎是 0 筆，顯示沒有量到停車端的折返停留，不報達成率與增加量，不會除以零。
- 選的那天沒有資料：跟其他塊一樣整塊不出現（`@coverage.data?` 為 false 時不 render）。

**Acceptance criteria**

- `spec/models/route_page/ends_spec.rb`（新）：`from_config` 的三種情況（兩端齊全、缺方向、值不對）與 `RoutePage.ends(15373)`、`RoutePage.route_ids`。
- `spec/models/route_page/buffer_trade_spec.rb`：既有例子加上兩端都停車的 `ends` 後數字不變；新增 `buffer-trade` delta spec 的 Scenario「Pass-through end reported, not counted」「Pass-through layovers do not count」「Layovers only at a pass-through end」與 Example「Pass-through layovers add nothing」「Pass-through hour ignored」。
- `spec/components/layover_table_component_spec.rb`、`spec/components/layover_chart_component_spec.rb`：`data-end-nature` 與文案；`spec/components/buffer_trade_component_spec.rb`：`pass-through-layovers` 欄位有無與值。
- `spec/requests/routes_spec.rb`：9001 兩列都標停車、試算沒有 pass-through 欄位；404 與 400 的例子不變。
- 真資料：`bin/rails runner` 對 15373 三天、緩衝 15 分鐘印出上面 Behavior 的數字；`bin/dev` 開 `/routes/15373?day=2026-10-21&range=7d` 人工看表、圖、試算三處的標示。
- `bundle exec rspec`、`bin/rubocop`（改到的檔）、`bin/brakeman` 全綠。

**Scope boundaries**

- 在範圍內：`config/route_page.yml`、`app/models/route_page.rb`、新的 `app/models/route_page/ends.rb`、`app/models/route_page/buffer_trade.rb`、`app/controllers/routes_controller.rb`、`app/views/routes/show.html.erb`、折返停留表、分佈圖、試算三個元件及其 `.yml`、`app/components/data_limitations_component.yml`、對應的 spec、`docs/spectra/LANGUAGE.md` 的「起站、末站、折返點、調度站」與「換休息試算」兩條。
- 不在範圍內：任何 migration、`analysis/` 的 SQL、`derived:load`、`bin/health-card`、`RoutePage::LayoverStats`、`RoutePage::LayoverDistribution`、班次串、其他路線、公廁。

## Risks / Trade-offs

- [達成率從 20.4% 跳到 57.1%，會被讀成休息變好了] → 這是定義變更的結果，不是改善。試算那一塊的說明寫明只算停車端；資料限制寫明；本 design 記下前後兩組數字，之後的月報引用時要帶定義。
- [設定是人工查證的事實，業者改折返方式後會過期] → 值旁邊的註解記查證日期與證據；資料限制寫明會過期；偵測留給設施那個 change 之後，GPS 聚類有了再談。
- [`data-value="layovers"` 的意義從全部變成停車端，既有的讀法會變] → 9001 兩端都停車，測試數字不變；開過去就走那一端另有 `pass-through-layovers` 欄位，兩個數字並列。
- [上限的最忙小時 12 點與 20 點並列（各 11 筆）] → 照 `buffer-trade` 的規則取較早的小時，報 12 點；驗收時核對。單日的最忙小時仍不穩定（zhongshan-buffer-trade 的 Risks），引用要用多天範圍。
- [只有一條路線，`stop` 與 `pass_through` 兩種值夠不夠要等第二條路線] → 值不對就擋下，加第三種值時是一次明確的設定與程式修改，不會悄悄發生。
