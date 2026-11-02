## Context

`GetSemiTimeTable.gz` 一列是一個時段的班距，`GetTimeTable.gz` 一列是一個定時班次的發車時刻，都以 `PathAttributeId` 與 `DateValue` 為鍵。n-gear 每天 04:30 存一份，鏡射裡 2026-10-18 到 11-01 的 15 份都有這兩支檔（2026-11-02 查的）。

2026-10-28 的快照量到的（全檔）：

- `GetSemiTimeTable.gz` 3,280 列。`LongHeadway` 是班距的下界、`LowHeadway` 是上界（名字容易看反），兩個都讀得成整數，沒有下界大於上界的列，169 列上下界相同。`StartTime`、`EndTime` 都是四位數字。15 列的 `EndTime` 不晚於 `StartTime`：10 列是 `0000`（棕2、棕6），意思是到午夜；5 列是 `1620` 到 `1620`（小15 的 `DateValue` 2 到 6）。propose 時這裡寫成都是 `0000` 是錯的，2026-11-02 apply 時對 16 份快照補查才看到；有路線頁的路線沒有 `1620` 這種列。
- `DateType` 只有 1 列不是 0，是 `DateValue` 20250101 這種指定日期。
- `GetTimeTable.gz` 35,493 列，`DateType` 全是 0。其他快照不一定：2026-10-26、10-31、11-01 的快照各有當天日期的 `DateType` 1 列（小36、小25、230；紅30、棕20；1717），有路線頁的路線 16 份快照都沒有。
- 有路線頁的路線：`DateValue` 2 到 6 的班距完全相同，1 與 7 完全相同；中山幹線、251區、22、235、復興幹線掛在跟路線 Id 相同的附屬路線上，307 掛在 157462、157463 兩條、內容相同。251 與 307西藏三民只有定時班次，251 一天 37 班。

既有的決定：`timetable-draft` 的「預設發車數取量到的每小時發車數，不讀公佈的班距」只管班表頁的預設值，這個 change 不動它；`run-time-vs-cycle` 與 `day-types` 把班表對照列為另開 change，就是這一個。

量到的對照見 proposal。查證差距不是量測誤差時用了三個來源：`trips` 的發車數、`bus_event` 在中途站的車數（2026-10-22 與 10-28，07 時每站 2 到 5 台）、`bus_data` 掛這條路線的車數（10-22 的 07 時 10 台、08 時 12 台、16 時 20 台）。事件裡屬於這條路線站牌、卻掛別的路線 Id 的只有 8／1,584 筆，所以也不是路線碼掛錯。

## Goals / Non-Goals

**Goals:**

- 衍生表存得到每個路線日的公告班距與定時班次。
- 一組路線日讀得到公告對量到的比較、路上的車、照公告要幾台，以及涵蓋日子裡改了什麼。

**Non-Goals:**

- 任何頁面：第一個讀這些數字的是 `03-monthly-card`。班表頁照舊用量到的發車數當預設（`timetable-draft`）。
- 判斷脫班、算班距達成率、對照單一班次準不準點：公開資料沒有核定班次與配車數，比不出「該發而沒發」。定時班次這裡只比數量，不逐班對時刻。
- 比「班表給了幾分鐘」：公開資料沒有排定的行駛時間。
- 解釋差距的原因：看不出來，只報數字。
- `GetSpecTimeTable.gz`（業者機動預排班表）：有路線頁的路線都不在裡面（`LANGUAGE.md` 的「班本」）。

## Decisions

### 公告班距與定時班次存進衍生表，一份快照的每個 DateValue 都存

`analysis/published_schedule.sql` 建兩個 view：`published_headways`（`route_id, path_attribute_id, date_value, start_minute, end_minute, low_minutes, high_minutes`）與 `published_departures`（`route_id, path_attribute_id, date_value, minute`），只留 `routes` 裡本頁路線 Id 的附屬路線。`derived_export.sql` 匯出同欄位的 CSV，照所有欄位排序，兩次匯出位元組相同。新表 `route_day_published_headways`、`route_day_published_departures`，外鍵到 `route_days`，刪路線日時一起刪。

存全部 `DateValue` 而不是只存當天那一個，是因為「補假日跑哪一種班距」還沒確認（見「每一天用哪一個 DateValue」），規則放在讀取時，之後改規則不用重算。列數很少：中山幹線一個路線日 32 列班距、28 列定時班次（量到的）。

替代方案：Rails 直接讀快照。否決：`docs/decisions.md` 第 2 條，正式站沒有原始檔。

### 兩支檔只由 published_schedule.sql 讀，快照沒有這兩支檔時不擋那一天

照 `GetProvider.gz` 的做法：`RouteDayLoader` 找當天快照的檔案，沒有就給 `{"BusInfo":[]}` 的暫存檔並印一行「靜態快照沒有 GetSemiTimeTable.gz，路線 N 這一天沒有公告班距」。`route_days.published_schedule_day` 記讀到的快照日；兩支檔都缺時是空的。`Day eligibility` 不變。

理由：這是月卡的一段，不是趟次的前提，舊快照缺檔不該讓整天載不進來。

### 欄位怎麼讀：下界是 LongHeadway，到午夜算 24:00，指定日期的列不存，讀不懂就失敗

- `low_minutes` 是 `LongHeadway`、`high_minutes` 是 `LowHeadway`，名字反直覺，寫在 SQL 註解與 `analysis/README.md`。
- `StartTime`、`EndTime` 四位數字換成當天第幾分鐘；`EndTime` 不晚於 `StartTime` 時加 1440，所以 `1730` 到 `0000` 是 1050 到 1440。
- 只留 `DateType` 是 0 的列。其他列是指定日期（2026-10-28 的快照只有 1 列），意思還沒查，不存。
- 本頁路線的列讀不成整數，或下界大於上界，整天失敗，訊息指名檔案與值；其他路線的列不管。

理由：全檔目前都讀得懂（見 Context），讀不懂就表示格式改了，要有人看。替代方案：跳過讀不懂的列。否決：對照表會少一段而沒有人知道。

2026-11-02 apply 時確定的細節：讀不懂還包括班距是 0（換算每小時班數要除以它）、`12.5` 這種帶小數的值（`TRY_CAST` 會讀成 12）、`2500` 這種不是時刻的值，以及 `DateType` 本身讀不成整數（否則會被當成不留的列悄悄丟掉）。API 說明文件 V6.3 把 `LongHeadway` 寫成「發車間距(高)」、`LowHeadway` 寫成「發車間距(低)」，16 份快照裡前者都不大於後者，所以下界還是 `LongHeadway`。規格的「不晚於就加 1440」會把小15 的 `1620` 到 `1620` 讀成 24 小時的時段；這條路線沒有路線頁，這次照規格實作，它上路線頁之前要先處理。

### 每一天用哪一個 DateValue：平日用當天星期，假日的週一到週五用星期日

`DateValue` 是星期幾，1 是日、2 是一、7 是六（API 說明文件 V6.3，2026-11-02 查的；`LANGUAGE.md`「日型別」）。規則在 `RoutePage::ScheduleComparison` 讀取時套用：

| 路線日 | 用的 `DateValue` |
| --- | --- |
| 平日，週一到週五 | 當天星期，週一是 2、週五是 6 |
| 假日，週六 | 7 |
| 假日，週日 | 1 |
| 假日，週一到週五（補假、國定假日） | 1 |
| 平日，週六或週日（補班） | 2 |

理由：有班距資料的頁面路線 1 與 7 內容相同、2 到 6 內容相同（Context），所以補假選 1 就是假日的表。補假日實際跑哪一種還沒確認：10-26 中山幹線 142 趟，介於週末的 107、116 與平日的 148 到 176 之間（量到的）。這是假設，寫在資料限制裡。

### 同一條路線的附屬路線合併去重

`ScheduleComparison` 讀一個路線 Id 的班距時，對 `date_value, start_minute, end_minute, low_minutes, high_minutes` 去重，不看 `path_attribute_id`；定時班次對 `date_value, minute` 去重。

理由：307 的兩條附屬路線內容相同，各算一次會變兩倍。如果某條路線兩條附屬路線內容不同，兩邊的列都會出現，讀的人看得到，不用另外判斷。

### 量到的發車是起點落在時段裡的趟次，路上的車是每半小時有在跑的車數取平均

- 量到的每小時發車：該路線 Id 起點落在時段裡的趟次（不分完整性，同 `RoutePage::MeasuredDepartures`），每個方向分開，除以涵蓋天數與時段的小時數，不四捨五入。
- 路上的車：把時段切成 30 分鐘一格，每天每格數有趟次跟這一格重疊的車（趟次起點早於格子結束、終點晚於格子開始），所有天所有格取平均。在折返停留裡的車不算。
- 趟次的時刻照台北時間。

理由：路上的車回答「這段時間到底有幾台在跑」，用格子平均才不會像「這一小時出現過幾台」那樣高估。

### 照公告要幾台是週期中位數除以公告班距

`needed_low` 是週期 p50 ÷ `high_minutes`、`needed_high` 是週期 p50 ÷ `low_minutes`，四捨五入成整數；週期取 `RoutePage::Cycles` 全天那一列的 p50。沒有週期時兩個都是 nil。

理由：一台車每個週期發一班，要維持班距 h 就要 週期 ÷ h 台。用全天的週期是因為按時段切樣本太少。中山幹線離峰算出 12 到 18 台，路上實際 14 到 16 台，對得上，所以這個算法可以拿來看尖峰。週期含停留，所以這是照現在的節奏要幾台，不是最低需求。

### 涵蓋日子裡公告改過就分開算

`ScheduleComparison#versions` 回傳一到多個版本：照日期排序，相鄰兩天用的班距與定時班次（去重之後）相同就併在一起。每個版本只用自己那幾天的趟次算。

理由：月中改了班距卻用同一張表比，前半個月的數字就錯了。替代方案：只用最新一天的公告。否決：同上。

### 頁面路線只比自己的趟次，成員路線另外一列

時段列只用 `route_id` 等於頁面路線的趟次與車。成員路線（307 的 307西藏三民）在 `member_rows` 各一列，只用自己的趟次，內容是定時班次或班距。週期照 `RoutePage::Cycles` 合併成員。

理由：公告是一條路線一份，混進成員的趟次就比不了。

### 其餘時段併成一列：定時班次與時段外的趟次

`others` 回傳不在任何公告時段裡的定時班次（分鐘清單）與起點不在任何時段裡的趟次（每方向每天幾趟）、路上的車。只有定時班次的路線（251）整天都是其餘時段。沒有定時班次也沒有時段外趟次時是 nil。

理由：定時班次一天幾十班，不能跟每小時班距放同一種列；這一列只比總數，不逐班對時刻。

### 靜態快照差異在讀取時比，不另外存

`RoutePage::SnapshotChanges#changes` 回傳日期遞增的清單，每筆是一個路線日與那一天相對前一個涵蓋日改了什麼：`:published_schedule`（兩張表任一列不同，只比有 `published_schedule_day` 的日子）、`:stops`（頁面路線每個方向的 `seq`、`stop_name`、`stop_location_id` 不同）、`:shape`（`route_day_shapes.shape_updated_at` 不同）。`#shape_updated_at` 是最新一天的軌跡更新時間。第一天沒有前一天，不算改動。

理由：衍生表每天都存這些，比對就有了，不用新表。只比得到載入過的日子，颱風跳過的那幾天看不到。

### 顯名聲明與資料來源文件多兩支 feed

`docs/data-sources.md` 授權一節第一行、`app/components/attribution_component.yml`、`bin/health-card` 的第一行，在 `業者營運基本資料（GetProvider）` 後面加 `機動班次時刻表（GetSemiTimeTable）、預定班表資訊（GetTimeTable）`。`docs/data-sources.md` 的查證表加兩列：[臺北市機動班次時刻表](https://data.gov.tw/dataset/129027)（TstSemiTimeTable.json）、[臺北市預定班表資訊](https://data.gov.tw/dataset/129028)（TstTimeTable.json），查證日期 2026-11-02，提供機關都是臺北市公共運輸處，授權都是政府資料開放授權條款第 1 版。

理由：`spec/analysis/attribution_spec.rb` 要求程式讀到的每一支 feed 都被第一行點名。

### 詞彙表新增公告班距、路上的車、照公告要幾台

`docs/spectra/LANGUAGE.md`「指標」底下新增三條，照四行格式。「日型別」的邊界把 `DateValue`「只在中山幹線上看過」改成這次的查證範圍。「趟次與班次」不動：這裡比的是公告的班距對量到的趟次，兩個詞照舊不互換。「不要用」要列脫班率、達成率：這裡算不出來。

### 用真資料驗收：中山幹線七個平日的對照表跟 proposal 相同

本機把 15373 的七個平日載入開發庫，`ScheduleComparison` 讀出來的四個時段跟 proposal 的表相同，週期 p50 是 182.2；再載入 10712（251）一天，`others` 是 37 班定時班次。

2026-11-02 驗收結果：`bin/rails derived:load` 把 15373 的 10-19 到 22、27 到 29 與 10712 的 10-22 寫進開發庫，每個路線日存 32 列班距、28 列定時班次（15373）與 0 列、259 列（10712）。`ScheduleComparison` 讀到（15373，週期 p50 182.2，七天同一個版本）：

| 公告時段 | 公告班距 | 量到每小時發車（去程／返程） | 路上的車 | 照公告要幾台 | proposal 有沒有列 |
| --- | ---: | ---: | ---: | ---: | --- |
| 05:30–06:30 | 10–15 分 | 1.9／5.3 | 5.3 | 12–18 | 沒有 |
| 06:30–08:00 | 4–6 分 | 5.5／2.5 | 10.0 | 30–46 | 相同 |
| 08:00–16:00 | 10–15 分 | 4.3／5.1 | 13.6 | 12–18 | 相同 |
| 16:00–17:30 | 4–6 分 | 7.4／4.1 | 16.7 | 30–46 | 相同 |
| 17:30–20:00 | 10–15 分 | 4.4／5.5 | 15.7 | 12–18 | 相同 |
| 20:00–21:00 | 15–20 分 | 4.6／4.0 | 12.6 | 9–12 | 沒有 |

其餘時段 4 班定時班次（21:00、21:30、22:00、23:00），每天去程 10.6、返程 6.6 趟，路上 6.8 台。10712 的 `others` 有 37 班定時班次，10-22 每個方向 37 趟，路上 5.3 台，沒有時段列。兩條路線 `SnapshotChanges` 都沒有改動。七天讀一次 `ScheduleComparison` 加 `SnapshotChanges` 約 0.16 秒（本機量到的），載入一個路線日約 5.7 秒。另外載入 16111（307）的 10-22 看成員路線：班距 68 列與定時班次 510 列去重後是 6 個時段與 37 班，成員路線 19108 一列、37 班、每天每個方向 36 趟，它的 72 趟沒有算進 307 的時段列。

## Implementation Contract

**行為**：`derived:load` 與 `bin/nightly-load` 多存公告的列。任何頁面都不多顯示東西，除了頁尾顯名聲明第一行多兩支 feed。

**資料形狀**：

- `RoutePage::ScheduleComparison.new(route_days, route_id:, cycles:)`：`cycles` 是 `RoutePage::Cycles`，由呼叫端給，測試可以換。
  - `versions`：`Version`（`days`、`periods`、`others`）的陣列。
  - `Period`：`start_minute, end_minute, low_minutes, high_minutes, per_hour_low, per_hour_high, departures_per_hour`（`{ 0 => Float, 1 => Float }`）`, on_road, needed_low, needed_high`。`per_hour_low` 是 60 ÷ `high_minutes`。
  - `Others`：`departures`（分鐘的陣列）`, trips_per_day`（`{ 0 => Float, 1 => Float }`）`, on_road`。
  - `member_rows`：`MemberRow`（`route_id, route_name, days, periods, others`）的陣列。
  - `hours`：`Hour`（`hour, departures`（同上）`, on_road`）的陣列，頁面路線有趟次的小時，給畫圖用。
  - `needs_reload?`：涵蓋日子有任何一天 `published_schedule_day` 是空的。
- `RoutePage::SnapshotChanges.new(route_days)`：`changes`（`Change`：`day, kinds`）、`shape_updated_at`、`n_days`。
- 兩個物件都不回傳車牌。

**apply 時補的細節**（2026-11-02，都比上面的決定細，沒有改變它們）：

- 成員路線的公告在涵蓋日子裡改過時，`member_rows` 照 `versions` 的規則分成幾列，所以 `MemberRow` 多一個 `days`。平常一條成員路線一列。理由：同一個規則，每列只用自己那幾天的趟次；只取一張表的話，改版前的日子會比錯。
- 其餘時段的 `on_road`：不在任何時段裡的時間切成 30 分鐘一格，只算當天有車在跑的格子，都沒有車時是 0.0。理由：只有定時班次的路線整天都是其餘時段，把半夜沒有車的格子算進去會拉低數字：251 的 10-22 有車的格子平均 5.3 台，48 格全算是 4.6 台（量到的）。時段列照規格，沒有車的格子照算 0。
- `hours` 列出頁面路線有車在跑的小時，只跑不發車的小時也列，那一小時的發車是 0。跨午夜的趟次只算到 23 時。
- 新表的索引不是 unique：`(route_day_id, route_id, date_value)`。去重是讀的時候的事，同一時刻兩班車也不該擋住整天。

**失敗模式**：本頁路線的列讀不懂時整天失敗，舊資料不變（既有的「Replace one route day atomically」）。快照缺檔不失敗，印一行。

**驗收**：fixture 定義在 tasks 1.1；`derived:load ROUTE=9001 DAY=2026-10-19` 存 18 列班距、6 列定時班次。

**範圍**：只動分析、衍生表、查詢物件、顯名聲明與文件。

## Risks / Trade-offs

- [補假日可能不跑假日班距] → 資料限制寫明還沒確認；規則在讀取時，改了不用重算。
- [`DateType` 1 的特殊日期列不存，那一天若跑特殊班表，比的還是星期的表] → 有路線頁的路線 16 份快照都沒有這種列（Context）。哪條路線開始有，再決定要不要讀。
- [漏掉起站的趟次，起點是第一個觀測到的站，時刻偏晚，可能落到下一個時段；起點只有到站時刻的趟次則偏早] → 只影響跨時段邊界的少數趟次（中山幹線 2026-10-19 漏起站 21／163 趟，量到的），每小時的數字可能差一兩班，尖峰的差距遠大於這個。文件寫「量到的發車」，不寫實際班次。
- [路上的車不算折返停留裡的車，週期卻含停留，兩者不是完全同一把尺] → 離峰對得上（Context），而且尖峰差距遠大於這個偏差。文件寫明算法。
- [公開這個差距可能被讀成業者脫班] → 只寫數字與「原因公開資料看不出來」，詞彙表把脫班率列為不要用。
- [本頁路線的列讀不懂會擋住那條路線當天的載入] → 每晚的 log 會報，其他路線不受影響（「One failing route day does not stop the others」）；這是刻意的，格式改了要有人看。

## Migration Plan

1. 合併後 deploy（有 migration）。
2. 在 mini 跑 `bin/nightly-load --recompute --load`，舊的路線日才有公告；由使用者用 `!` 跑。可以跟 `01-rest-windows` 併成一次。
3. 退回：migration 只加表與一欄。

## Open Questions

沒有。`DateValue` 的官方定義 2026-11-02 對過了：API 說明文件 V6.3 寫 `DateType` 0 是星期、1 是特殊日期，星期的 `DateValue` 1 是星期日、2 是星期一、7 是星期六，特殊日期是 yyyymmdd，跟這裡的讀法相同。
