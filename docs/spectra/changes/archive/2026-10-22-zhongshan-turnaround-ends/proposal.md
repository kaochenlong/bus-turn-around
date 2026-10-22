## Why

這個 change 服務三樣交付物的第二樣「換休息」試算，以及第一樣路線健檢卡在路線頁上的折返停留表與分佈圖。它補的是系統裡還沒有的一個概念：折返點。專案叫折返點，詞彙表卻寫「折返點沒有任何欄位直接給」，衍生表只有末站；路線的每一端車到底停不停，目前沒有任何地方記著。

現在就要做，因為換休息試算的前提對中山幹線的一端不成立。試算把兩個方向結束的折返停留混在一起算（`RoutePage::BufferTrade` 的 SQL 沒有分方向），下限是把每一次不到 B 分鐘的折返停留補足。但青年公園那一端是開過去就走的折返：去程末站青年公園(馬場町) 到返程起站青年社宅約 200 公尺（兩站座標算的直線距離），車不停，2026-10-20 的 75 筆折返停留中位數 1.9 分鐘，GPS 沒有離開這一段。route-page-charts 的非目標「查清楚青年公園那一端的折返停留是不是量錯地方」這次查清楚了：量的地方沒錯，但那裡不是休息機會。中山幹線 15373 在衍生表裡的 2026-10-19 到 10-21 三天（量到的，2026-10-22 查詢），緩衝 15 分鐘：

| 結束那趟 | 末站 | 筆數 | 不到 5 分鐘 | 不少於 15 分鐘 | 補到 15 分鐘的差額 |
| --- | --- | ---: | ---: | ---: | ---: |
| 去程 | 青年公園(馬場町) | 214 | 201 | 0 | 2,735 分鐘 |
| 返程 | 職能發展學院二 | 119 | 11 | 68 | 346 分鐘 |

下限 3,081 分鐘裡有 2,735 分鐘是在補一個車不停的地方。頁面現在報的是每天多 17.1 到 27.7 車時、休息達成率 20.4%；只算停車那一端是每天多 1.9 到 9.9 車時、達成率 57.1%。兩組數字差了將近一個數量級，站長要拿去排班的是後者。

需要的資料：全部已經在衍生表裡（`layovers` 的 `go_back` 是結束那趟的方向），不用新的資料來源。哪一端停車是逐路線查證後寫進設定的事實，不從資料算；中山幹線的查證用了 n-gear 收的 `bus_data` GPS 與靜態快照 `GetStop.gz` 的站牌座標，查證本身不進程式。

## What Changes

- 新概念「折返點的性質」：路線的每一端，依結束在那一端的趟次方向（`go_back`）標記為「停車」或「開過去就走」。這是逐路線查證後寫進 `config/route_page.yml` 的設定，附查證的日期與證據；路線清單從只有 `Id` 的列表改成每條路線一個項目，清單裡的路線兩端都必須標記，缺一端就以指出路線與方向的錯誤訊息擋下。中山幹線：去程結束的青年公園端是開過去就走，返程結束的職能發展學院二端是停車。
- **BREAKING**（試算定義變更）：換休息試算只算停車端的折返停留。下限是停車端不到 B 分鐘的差額加總，上限是 B 乘停車端的筆數，休息達成率是停車端不少於 B 分鐘的比例，最忙小時也只看停車端；開過去就走那一端的折返停留照報筆數，標成「不是休息機會」。中山幹線三天的數字從每天多 17.1 到 27.7 車時變成 1.9 到 9.9 車時。
- 路線頁的折返停留表與分佈圖，在每一端標出它的性質；開過去就走那一端寫明車不停、不是休息機會。表與圖的數字不變。
- 資料限制補上：哪一端停車是查證後寫進設定的，不是從資料算的，業者改折返方式時要跟著改；開過去就走那一端的折返停留不是休息機會，試算不補它。
- `docs/spectra/LANGUAGE.md`：「折返點」一條加上「停不停車」這個屬性與青年公園端這個邊界案例（工作樹裡那條還沒 commit 的修改併進來）；「換休息試算」一條的邊界改成只算停車端。

## Non-Goals

非目標，這個 change 不做：

- 折返點設施：末站 300 公尺內有沒有公廁、能不能停大車。那是下一個 change，資料來源是環保局的公廁點位。
- 從折返停留分佈或 GPS 自動推哪一端停車。中山幹線的查證是人看 GPS 與距離做的；自動推要先在幾條路線上看過它推得對不對。
- 「在開過去就走那一端設停車位之後兩端都補」的試算。那是一個建議動作，要先知道那裡停不停得下車，是設施那個 change 之後的事。
- 區分停車端是調度站還是路邊。`GetProvider.gz` 的營業站沒有座標，中山幹線掛的天東站是不是就在職能發展學院二旁邊確認不了；折返停留本來就定義成含回場在內的上限（詞彙表「折返停留」），這次不需要這個區分。
- 改 Markdown 健檢卡（`bin/health-card`）。折返停留的定義沒變，變的是哪一端算休息機會；卡的「全部」那列照舊。
- 改班次串。開過去就走那一端的折返停留全部不到 15 分鐘，本來就不進休息額度（決策「班次串不跟著放寬」，layover-endpoints），結果不會變。
- 修改趟次、折返停留、行駛時間、載客剖面、捷運重疊的定義；其他路線；平日與假日分開；排程與部署。

## Capabilities

### New Capabilities

- `turnaround-ends`：折返點的性質。每條有路線頁的路線，兩端各標記停車或開過去就走：設定的形狀、缺漏時的失敗方式，以及「開過去就走那一端的折返停留不是休息機會」這條規則由誰遵守。

### Modified Capabilities

- `buffer-trade`：試算的基礎從「量到的折返停留」改成「停車端量到的折返停留」，開過去就走那一端只報筆數；達成率、車時區間、最忙小時跟著改。
- `route-page`：折返停留表、分佈圖與試算那一塊標出每一端的性質；資料限制多一點。

## Impact

- 修改 `config/route_page.yml`（路線清單改成每條路線一個項目，帶兩端的性質與查證證據）與 `app/models/route_page.rb`（讀清單與每端的性質，缺漏時丟指出路線與方向的錯誤）；`RoutesController#show` 對不在清單裡的路線仍回 404。
- 修改 `app/models/route_page/buffer_trade.rb`（接收兩端的性質，只算停車端）、`app/components/buffer_trade_component.rb`、`app/components/buffer_trade_component.html.erb`、`app/components/buffer_trade_component.yml`（顯示開過去就走那一端的筆數與說明）。
- 修改 `app/components/layover_table_component.rb`、`app/components/layover_table_component.html.erb`、`app/components/layover_table_component.yml`、`app/components/layover_chart_component.rb`、`app/components/layover_chart_component.html.erb`、`app/components/layover_chart_component.yml`（每一端的性質標示）；`app/views/routes/show.html.erb`（把性質傳進三個元件）；`app/components/data_limitations_component.yml`。
- 查詢物件 `RoutePage::LayoverStats` 與 `RoutePage::LayoverDistribution` 不改，`spec/models/route_page/card_consistency_spec.rb` 比對的數字不受影響。
- 修改測試：`spec/models/route_page/buffer_trade_spec.rb`、`spec/components/buffer_trade_component_spec.rb`、`spec/components/layover_table_component_spec.rb`、`spec/components/layover_chart_component_spec.rb`、`spec/requests/routes_spec.rb`；測試用的路線 9001 在設定裡兩端都標停車，既有的 fixture 數字不變。
- 修改 `docs/spectra/LANGUAGE.md` 的「折返點」與「換休息試算」兩條。
- 不新增 migration，不改 `analysis/` 的 SQL，不重跑 `derived:load`，不加 Gemfile 依賴。
- 資料限制與假設：車不等於人，折返停留仍是駕駛休息的上限，雙班制下一台車兩人開；停車端只是「車在這裡停」，停了 B 分鐘不等於休息了 B 分鐘；10 秒輪詢會漏站，漏了末站或下一趟起站的配對量不到，試算只用量到的；跨小時檔的重複在趟次重建前已去除，不影響配對；哪一端停車是查證那一天的事實，業者改折返方式時設定要跟著改；車上人數與刷卡率不牽涉這個定義。
