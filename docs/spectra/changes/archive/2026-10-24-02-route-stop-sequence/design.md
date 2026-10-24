## Context

路線頁（`app/views/routes/show.html.erb`）由上到下是：頁首（`RouteCoverageComponent`：路線名稱、起迄、範圍切換、涵蓋的日子）、重點數字（`RouteSummaryComponent`）、區塊導覽（`SectionNavComponent`），接著是折返停留、來回一趟與週期、折返點設施（turnaround-facilities 正在加）、換休息試算、行駛時間、載客剖面、資料限制幾張卡。首頁（`pages#home`）的路線清單由 `RouteListComponent` 輸出，每條路線一張卡。

現在的狀態，2026-10-24 在 `/routes/11764` 與程式碼裡看到的：

- 每一站都在載客剖面那張卡最下面的逐站表（`LoadProfileTableComponent`）裡，收在預設關閉的 `<details>`，摘要寫「逐站數字：載客剖面表」與「91 站 × 4 個時段」。表上印的是資料的 `seq`，兩個方向連號：251區 去程 0 到 43、返程 44 到 90。
- 折返停留分佈圖的每個方向，標題寫「末站 到站 → 下一趟從 起站 出發」和折返方式，但看不出中間怎麼走。
- 折返停留那張卡的標題是「車在終點能停幾分鐘？」（`app/components/layover_chart_component.yml`），en 是 “How long does a bus stay at the end of the line?”。
- 頁首的 h1 是「251區」後面接一個灰色的 `11764`；首頁路線卡的名稱那一行也是一樣。還沒有資料的路線卡只顯示 `11764`。這是 ead9744（zhongshan-route-page 的第一版路線頁）帶進來的，archive 的 design 裡沒有理由。首頁 spec 的 Route list 要求卡片「show the route name, the Id」，沒有資料的卡「show only the Id」。
- 站名來自衍生表 `route_day_stops`（`go_back`、`seq`、`stop_name`、經緯度、最近的捷運出入口），每個路線日一份，取自那一天 `static_day` 的靜態快照。兩端的折返方式在 `config/route_page.yml`，由 `RoutePage::Ends` 讀，`#nature(go_back)` 回 `:stop` 或 `:pass_through`。
- `RoutePage::Coverage#route_days` 已經 `order(:day)`。`RoutePage::LayoverStats`、`RoutePage::LayoverDistribution`、`RoutePage::LoadProfile`、`RoutePage::MrtOverlap` 再接 `order(day: :desc).pick(:id)` 取「最新一天」，SQL 變成 `ORDER BY day ASC, day DESC`，7 天範圍時取到的是最早那天（2026-10-24 在 15373、day=2026-10-22、range=7d 實測拿到 10-19）。`RoutePage::Cycles` 改用 `reorder`，沒有這個問題。這是已知、還沒修的問題，不在這個 change 的範圍。

同時在進行的工作：另一個 session 在同一個工作目錄 apply turnaround-facilities（2026-10-24 03:50 的 `spectra list` 是 11 個任務做完 10 個），`app/views/routes/show.html.erb`、`app/components/section_nav_component.rb` 與 `.yml`、`app/components/data_limitations_component.yml`、`docs/spectra/LANGUAGE.md`、`spec/requests/routes_spec.rb`、`spec/requests/route_page_fixture_spec.rb` 都有它還沒 commit 的修改。turnaround-facilities 與 turnaround-map 的 delta 都 MODIFIED route-page 的 Page content。

使用者在 2026-10-24 的討論裡同意：四件事放一個 change；標題改詞與路線 Id 加標示在 Demo 交件（當天下午）前做，站序區塊與詞彙表交件後做。

## Goals / Non-Goals

**Goals:**

- 讀者在路線頁一打開就能看懂這條路線怎麼跑：兩個方向各停哪些站、兩個折返點在哪、哪一端車會停、下一趟從哪一站出發。
- 卡片標題不再用把讀者帶往遠端的「終點」。
- 路線 Id 只出現一次，帶著「路線 Id」標示，要對照開放資料的人不用點開什麼就找得到。
- 詞彙表有「站序」一條，站序區塊的小標對得回去。

**Non-Goals:**

- 標出 251區 跟 251 共用的站，或讓兩頁互相連結：會推翻 route-251-pages 的決定「251區 當成獨立的路線，不跟 251 配對」，那條的理由是 251區 跟 251 的關係還沒定義。
- 地圖上畫站牌或路線形狀：見決定「站序區塊自己一張卡，放在區塊導覽之後、預設收起，不加導覽連結」裡對 turnaround-map 那句非目標的讀法。
- 在站序上標出靠近捷運的站、車上人數或任何指標。
- 改逐站表、區塊導覽、資料限制那一張卡。
- 修 `LayoverStats`、`LayoverDistribution`、`LoadProfile`、`MrtOverlap` 取最新一天的問題。
- 307 合成一頁之後 Id 那一行怎麼寫兩個 Id；網址改用名稱。

## Decisions

### 折返停留那張卡的標題改問「折返點」

`LayoverChartComponent` 的標題，tw「車在終點能停幾分鐘？」改成「車在折返點能停幾分鐘？」；en “How long does a bus stay at the end of the line?” 改成 “How long does a bus stay at the turnaround?”。小標「折返停留」、說明、每個方向的圖說都不變。

理由：「終點」是 `docs/spectra/LANGUAGE.md`「起站、末站、折返點、調度站」那條列為不要用的詞。這個禁用 2026-10-22 02:21 就寫進詞彙表（f89102c），標題是同一天 16:12 加的（787a1d2），archive 的 design 裡找不到選這個詞的理由。用「一圈」來想的讀者會把終點讀成最遠那一頭，那正好是開過去就走、車不停的那一端。這張卡兩端都畫，「折返點」兩端都涵蓋，也跟首頁 H1「折返點實際能休幾分鐘？」用同一個詞（home-page 的決定「標題用網站今天答得出來的問題」）。en 的 end of the line 有同一個問題，改成首頁英文標題用的 turnaround。

替代方案：「車在末站能停幾分鐘？」（末站是照方向算的，用一圈來想的讀者一樣會讀成遠端，否決）；「車在停車端能停幾分鐘？」（卡上兩端都畫，包含開過去就走那一端，否決）。

### 路線 Id 加上「路線 Id」標示，放在起迄那一行

路線頁頁首的 h1 只放路線名稱。起迄那一行在「深坑－公館」之後接一段 `span[data-route-id]`，文字是「路線 Id 11764」，字級 `text-note`（比起迄小一級）、slate-500、整段不換行。首頁有資料的路線卡同樣處理：名稱那一行只放名稱，起迄那一行後面接「路線 Id」。沒有資料的卡沒有名稱可放（名稱來自 `route_days`），照舊只顯示 Id，但改成同樣帶「路線 Id」的文字。網址 `/routes/<Id>` 與所有 `data-route` 屬性不變。

理由：

- 名稱本身就分得開。2026-10-23 的 `GetRoute.gz` 有 416 個路線 Id，沒有兩個 Id 共用同一個 `nameZh`（量到的）；251 與 251區、307 與 307西藏三民 都是不同的名稱，所以 Id 不是拿來區分路線的。
- 要拿開放資料對照、要引用的人需要 Id，而且不該要點開什麼才找得到，所以 Id 留在看得到的地方。健檢卡已經是這個寫法：「路線：中山幹線（路線 Id 15373）」。
- 交件後的 307 要把 16111 與 19108 合成一頁（2026-10-23 使用者決定）。名稱旁邊只放一個號碼會是錯的；帶標示的一行放得下兩個，怎麼放由那個 change 決定。
- 文案不寫 RouteID：詞彙表「路線」那條把 RouteID 列為不要用，事件裡的 RouteID 指的是附屬路線。

替代方案：整個拿掉、只留在網址（要對照資料的人得從網址抄，否決）；放進站序區塊（收起來時看不到，而且站序區塊交件後才做，否決）；照舊接在名稱後面（沒有標示，讀者分不出那串數字是什麼，否決）；在 `config/route_page.yml` 替每條路線存名稱，讓沒有資料的卡也有名稱（這種卡只在剛加進設定、還沒載入資料時才出現；為了它重複一份 `GetRoute.gz` 已有的資料，還會跟資料不同步，否決）。

### 站序區塊自己一張卡，放在區塊導覽之後、預設收起，不加導覽連結

`show.html.erb` 在 `SectionNavComponent` 之後、折返停留那張卡（`CardComponent.new(id: "layovers")`）之前，render `CardComponent.new(id: "stops")`，裡面是 `StopSequenceComponent`。元件最外層是 `section[data-section="stop-sequence"]`：小標、標題，然後一個不帶 `open` 的 `details[data-stop-sequence]`。摘要寫兩個方向各幾站，展開後是清單；所有的列都在伺服器輸出裡，不需要 JS。區塊導覽不加連結，`SectionNavComponent` 不改。

理由：

- 先看懂路線怎麼跑，再看數字，所以放在所有數字的卡之前。
- 預設收起，照 02-route-page-mobile-first 的決定「逐站表收進預設關閉的 details」：`<details>` 不需要 JS，鍵盤與螢幕報讀都原生支援。251 一個方向 55 站（2026-10-23 的快照），展開的清單會把折返停留推到很下面。
- 區塊就在導覽正下方，導覽多一個連結沒有用處。`SectionNavComponent` 也是 turnaround-facilities 正在改的檔，不改就不會撞。
- turnaround-map 的 proposal 在 Non-Goals 寫「路線形狀（`GetBusShape`）、沿線站牌、捷運出入口上圖：這張圖只回答折返點附近的問題，沿線的事在載客那張卡」。這裡把它讀成「那張地圖不畫沿線站牌」的範圍限制，不是「沿線的東西只能放在載客那張卡」。這個區塊是文字清單，不在地圖上，載客那張卡也不動。

替代方案：不加區塊，把逐站表改得好找、在去程與返程的交界加折返標記（讓人看懂路線的東西會壓在乘客人數底下、排在頁面最後，否決）；預設展開（否決，理由如上）；放進頁首（`RouteCoverageComponent` 管的是範圍與涵蓋的日子，混進清單就不只一個責任，否決）。

### 站序取涵蓋日子裡最新一天，用 reorder 取

新的查詢物件 `RoutePage::StopSequence.new(route_days)` 用 `route_days.reorder(day: :desc).pick(:id, :static_day)` 取涵蓋日子裡最新的那一天，讀那一天的 `route_day_stops`，一次查詢，依 `go_back`、`seq` 排序。快照日用那一天的 `static_day`，不用 `day`。

理由：

- 照 route-page-charts 的決定「沿線人數圖的橫軸取最新那一天的站序」，同一頁的站序只有一個取法。
- `RoutePage::Coverage#route_days` 已經 `order(:day)`，`order(day: :desc)` 只會附加第二個排序，取到的是最早那天。`RoutePage::Cycles` 已經改用 `reorder`，這裡照它。測試要傳跟 `Coverage#route_days` 一樣、由舊到新排好的 relation，才測得出 `order` 與 `reorder` 的差別。
- 站序來自那一天用的靜態快照，`static_day` 才是快照的日期。兩者通常是同一天，但區塊說的是「取自哪一份快照」。

替代方案：沿用 `RoutePage::LoadProfile#stops`（會帶著上面那個問題，7 天範圍取到最早那天，否決）；把 `LoadProfile` 等四個查詢物件一起修（那是另一個問題，要先決定改呼叫端還是改 `Coverage`，另開 change，否決）。

### 清單標出起站、末站與折返，不印站序號碼

每個方向一組，依 `go_back` 由小到大。每組先是標題列「去程 44 站」，接著一個 `ol`，每個站牌一個 `li`，依 `seq` 排序，只寫站名；第一個 `li` 加「起站」、最後一個加「末站」的小標籤。`ol` 之後一列 `p[data-turnaround]`：「折返」加上那一端折返方式的標籤（`ApplicationComponent#nature_tag`，停車或開過去就走，性質讀 `RoutePage::Ends#nature(go_back)`），以及「下一趟從 {另一個方向的起站} 出發」。區塊最後一句寫站序取自哪一天的靜態快照。640px 以上兩個方向左右並排，以下上下排。

理由：

- 下一趟的起站取另一個方向的起站，跟 route-page-charts 的決定「圖的標題寫「末站 → 下一趟起站」，起站取另一個方向的起站」同一個取法，那條的根據是量到的 333/333：下一趟全部是另一個方向。
- 折返方式的標籤照 01-route-page-visual-refresh 的決定「折返方式改成標籤，兩種同一個樣式」：不用顏色，兩種只有字不同。
- 不印號碼：資料的站序兩個方向連號，251區 返程第一站台電大樓是 44（2026-10-23 的快照），印出來讀者會以為前面少了 43 站。清單要的只是順序，`ol` 本身就是順序。逐站表照舊印號碼，不在這個 change 的範圍。
- 折返那一列放在 `ol` 外面，`ol` 的項目數就等於那個方向的站牌數，螢幕報讀唸出的數量也對。`ol` 帶 `role="list"`，因為拿掉項目符號之後，Safari 的 VoiceOver 會把它當成不是清單。

替代方案：印方向內的位置 1、2、3（同一頁的逐站表把同一站印成 44，兩個號碼對不起來，否決）；照 `RoutePage::Cycles` 的前段方向，從停車端那一個方向開始排（`config/route_page.yml` 的鍵本來就是方向，去程先、返程後跟頁面上其他區塊一致，否決）。

### 詞彙表補「站序」一條

`docs/spectra/LANGUAGE.md` 的「路網物件」在「站牌與站位」之後加這一條：

```markdown
### 站序

- 定義：一條路線一個方向的站牌，照 `seqNo` 由小到大排出來的順序。第一站是那個方向的起站，最後一站是末站。站序取自靜態快照，不是量到的；兩份快照的站序不同，就是那一天改了。
- 在資料或程式碼裡：`GetStop.gz` 的 `seqNo`，兩個方向連號（中山幹線去程 0 到 45、返程 46 到 90；251區 去程 0 到 43、返程 44 到 90，2026-10-23 的快照）。衍生表 `route_day_stops` 的 `go_back`、`seq`、`stop_name`，每個路線日一份，取自那一天 `static_day` 的快照。路線頁的站序區塊由 `RoutePage::StopSequence` 讀。
- 邊界：路線頁涵蓋好幾天時，站序取涵蓋日子裡最新的那一天，區塊寫出取自哪一天的快照。站序區塊只排順序、不印 `seq`，逐站表照舊印 `seq`，所以同一站在逐站表上是 44 這類號碼。`LoadProfile` 等四個查詢物件在 7 天範圍取到的是最早那天的站序（已知問題，還沒修），修好之前兩處的站名可能不同。
- 不要用：停靠站（分不出是站牌還是站位）、站點順序。
```

「路線」那條的邊界最後補一句：「畫面上要給路線 Id 時寫成「路線 Id 11764」，放在起迄之後，不接在名稱後面。」

理由：02-route-page-mobile-first 的決定「文案」寫「小標用 `docs/spectra/LANGUAGE.md` 裡的正式名稱，讀者能對回詞彙表」。站序區塊的小標是「站序」，所以這一條要在區塊上線之前就存在。「站序」在詞彙表的附屬路線、區間車、去返程、漏站、捷運重疊幾條裡都用到，卻沒有自己的定義。「停靠站」是這次討論裡自然出現的說法，它分不出是某條路線某個方向的站牌，還是多條路線共用的站位，所以列為不要用。

### Page content 以 turnaround-facilities 的版本為底，archive 排在它之後

route-page 的 Page content 這次的 MODIFIED，是把 turnaround-facilities 那份 delta 的 Page content 整段照抄，只在區塊導覽之後插入站序區塊，並把「Overlap block in place」的區塊順序改成 summary、stop sequence、layover chart，其餘不變。

理由：turnaround-facilities 與 turnaround-map 也都 MODIFIED 這一條。archive 時整條會被替換，以誰的版本為底，誰的內容就留下來。turnaround-facilities 11 個任務做完 10 個，會比這個 change 的站序任務先 archive；turnaround-map 一個任務都還沒做，而且它的 Page content 本來就要重寫（那份裡沒有來回一趟與週期那一塊）。

做法：

- 站序區塊的任務開始前，先確認 turnaround-facilities 已經 archive，再跑 `/spectra-drift 02-route-stop-sequence`，把這裡的 Page content 改成**那時候主 spec**（`docs/spectra/specs/route-page/spec.md`）的 Page content 加上站序區塊。以主 spec 為準，不以 turnaround-facilities 的 delta 檔為準，因為它在 archive 之前還可能改。
- archive 這個 change 之前再核對一次：turnaround-map 若已經先 archive，同樣以主 spec 為底重寫。
- 標題與路線 Id 兩個任務不碰 Page content。

替代方案：以現在的主 spec 為底（turnaround-facilities 一 archive，這裡 archive 時就會把設施那一塊從 Page content 拿掉，否決）；站序區塊只寫成一條 ADDED、不改 Page content（Page content 寫的是「依這個順序」，順序那個情境會跟頁面對不上，否決）；把站序區塊拆成另一個 change（使用者 2026-10-24 選了四件事放一個 change；拆開也一樣要以那時候的主 spec 為底，這個問題不會消失，否決）。

### 文案

tw 與 zh-TW 用同一份（照既有的 `<<: *tw`），en 另寫。

- `LayoverChartComponent` 的 `title`：「車在折返點能停幾分鐘？」／“How long does a bus stay at the turnaround?”。
- `RouteCoverageComponent` 與 `RouteListComponent` 各加 `route_id`：「路線 Id %{id}」／“Route ID %{id}”。沒有資料的路線卡用同一個 key。
- `StopSequenceComponent`：
  - `eyebrow`：「站序」／“Stop sequence”。
  - `title`：「這條路線停哪些站、在哪裡折返？」／“Which stops does this route serve, and where does it turn around?”。
  - `count`：「%{direction} %{count} 站」／“%{direction}: %{count} stops”。摘要把兩個方向的 `count` 用「・」接起來，例如「去程 44 站・返程 47 站」；en 用 “ · ”。每個方向的標題列也用 `count`。
  - `directions`：「去程」「返程」／“Outbound” “Inbound”。
  - `first_stop`：「起站」／“First stop”；`last_stop`：「末站」／“Last stop”。
  - `turnaround_html`：「折返 %{nature}，下一趟從 %{next_first_stop} 出發」／“Turnaround %{nature}; the next trip leaves %{next_first_stop}”；另一個方向沒有站牌時用 `turnaround_only_html`：「折返 %{nature}」／“Turnaround %{nature}”。
  - `natures`：`stop`「停車」、`pass_through`「開過去就走」／“Stops” “Drives on”，跟 `LayoverTableComponent` 的標籤同一組字。
  - `snapshot`：「站序取自 %{day} 的靜態快照，涵蓋好幾天時只列最新那一天的。」／“Stops from the static snapshot of %{day}; over several days only the latest is listed.”，`%{day}` 用 `iso8601`，跟捷運重疊那一塊的快照日同一個寫法。
  - `no_stops`：「這幾天沒有站序。」／“No stop sequence for these days.”。
- 這個 change 的任何文案都不出現「終點」「停靠站」「循環」「一圈」，也不寫 RouteID。

理由：小標用詞彙表的正式名稱、標題是問句，照 02-route-page-mobile-first 的決定「文案」（「標題是問句、不寫斷言」）。標題直接接上使用者原本的問法「這條路線的停靠站」，同時點出折返點，又不用「停靠站」這個詞。

## Implementation Contract

**Behavior**

- `GET /routes/11764`：h1 的文字只有「251區」；h1 下面那一行是「深坑－公館」，後面接「路線 Id 11764」。首頁 `/` 的 251區 卡：名稱那一行只有「251區」，起迄那一行後面接「路線 Id 11764」。設定裡有、還沒有資料的路線卡寫「路線 Id 」加上那個 Id，以及還沒有資料那一句。
- 折返停留那張卡的標題是「車在折返點能停幾分鐘？」。
- 路線頁在區塊導覽之後、`#layovers` 之前有 `div#stops` 包住 `section[data-section="stop-sequence"]`。`details` 預設收起，摘要是「去程 44 站・返程 47 站」；展開後是兩個方向的清單與各自的折返列（三條路線的內容見驗收表）。
- 選的那一天沒有資料時，站序區塊跟其他卡一樣不出現，頁首也沒有起迄與 Id 那一行（沒有可用的路線日）。
- 頁面不顯示任何車牌；站序區塊不標示靠近捷運、車上人數或任何門檻。

**Interface / data shape**

- `RoutePage::StopSequence.new(route_days)`：
  - `#directions -> [Direction]`，`Direction = Data.define(:go_back, :stop_names, :next_first_stop)`。依 `go_back` 排序；`stop_names` 依 `seq` 排序；`next_first_stop` 是另一個方向 `seq` 最小的站名，另一個方向沒有站牌時是 `nil`。只有那一天 `route_day_stops` 裡出現的方向才有。
  - `#static_day -> Date | nil`：涵蓋日子裡最新那一天的 `static_day`；沒有任何路線日時是 `nil`。
  - `#any? -> Boolean`：`directions` 不是空的。
  - 建構時用一次查詢取最新那一天（`route_days.reorder(day: :desc).pick(:id, :static_day)`）；`directions` 用一次查詢讀那一天的站牌（依 `go_back`、`seq` 取 `go_back` 與 `stop_name`），同一個物件呼叫兩次只查一次。
- `StopSequenceComponent.new(stop_sequence:, ends:)`，用 `bin/rails g view_component:component StopSequence stop_sequence ends --locale` 產生，同層 `.yml` 有 tw、zh-TW、en。輸出：
  - `section[data-section="stop-sequence"]` 裡依序是小標（`eyebrow`）、`h2` 標題、`details[data-stop-sequence]`（不帶 `open`）。`summary` 是兩個方向的站數。
  - 每個方向一個 `div[data-direction="0"]` 或 `div[data-direction="1"]`：標題列、`ol[role="list"]`。每個站牌一個 `li`，文字是站名；第一個 `li` 帶 `data-first-stop` 與「起站」標籤，最後一個帶 `data-last-stop` 與「末站」標籤（只有一站時兩個都帶）。`ol` 之後是 `p[data-turnaround]`，帶 `data-end-nature`（`stop` 或 `pass_through`），另一個方向有起站時再帶 `data-next-first-stop`。
  - `p[data-static-day]`，值與文字裡的日期都是 `iso8601`。
  - 沒有站序（`any?` 為假）時，不輸出 `details`，改成 `p[data-no-stops]`。
- `show.html.erb`：`SectionNavComponent` 之後是 `CardComponent.new(id: "stops")`，包住 `StopSequenceComponent.new(stop_sequence: RoutePage::StopSequence.new(route_days), ends: @ends)`。
- `RouteCoverageComponent`：h1 只輸出 `route_day.route_name`；起迄的 `p` 裡，在起迄之後輸出 `span[data-route-id]`，文字是 `t(".route_id", id:)`。
- `RouteListComponent`：有資料的卡，名稱那一行只輸出名稱，起迄那一行之後接 `span[data-route-id]`；沒有資料的卡，第一行的文字改成 `t(".route_id", id:)`。

**Failure modes**

- 最新那一天沒有站牌（`route_day_stops` 是空的）：區塊照樣出現，顯示小標、標題與「這幾天沒有站序。」，不輸出 `details`；其他卡不受影響。
- 只有一個方向有站牌：只列那個方向；折返列只寫折返方式，不寫「下一趟從…出發」，也不帶 `data-next-first-stop`。
- `config/route_page.yml` 缺一端的性質：照現況由 `RoutePage::Ends.from_config` 在 controller 擋下（`RoutePage::Ends::InvalidConfiguration`），這裡不另外處理。
- 選的那一天沒有資料：整塊不出現（`@coverage.data?` 為假時不 render）。

**Acceptance criteria**

- `spec/models/route_page/stop_sequence_spec.rb`：傳進去的 relation 跟 `RoutePage::Coverage#route_days` 一樣依 `day` 由舊到新排序，兩天的站序不同時，讀到的是較新那一天的站牌與 `static_day`；方向與站序的順序；`next_first_stop` 是另一個方向的起站；另一個方向沒有站牌時是 `nil`；沒有站牌時 `any?` 為假；`directions` 呼叫兩次只查一次資料庫。
- `spec/components/stop_sequence_component_spec.rb`：`details` 不帶 `open`；摘要的兩個站數；每個方向 `li` 的文字依序是站名，第一個與最後一個帶起站與末站標籤；沒有任何 `li` 含站序號碼；折返列的 `data-end-nature` 與 `data-next-first-stop`；快照日；沒有站序時的那一句。
- 固定的文案（折返停留卡的新標題、站序區塊的小標與標題、「路線 Id」標示、`StopSequenceComponent` 的 `.yml`）用內容檢查驗：逐字對照上面「文案」那一條，確認 tw 與 en 都沒有「終點」「停靠站」「循環」「一圈」「RouteID」。不為固定的字另寫測試。
- `spec/components/route_coverage_component_spec.rb`：h1 的文字只有路線名稱；`[data-route-id]` 的文字是「路線 Id 9001」，而且跟起迄在同一個 `p` 裡。
- `spec/components/route_list_component_spec.rb` 與 `spec/requests/pages_spec.rb`：有資料的卡，名稱那一行只有名稱，`[data-route-id]` 是「路線 Id 9001」；沒有資料的卡寫「路線 Id 15373」，而且沒有連結。
- `spec/requests/routes_spec.rb`：區塊順序變成 summary、stop-sequence、layover-chart、layovers、cycles、facilities、buffer-trade、run-times、load-chart、mrt-overlap、load-profile、limitations；區塊導覽的連結不變；Bullet 不報 N+1。
- 真資料驗收：衍生表已經有三條路線，看各自最新的一天（`range=day`），站數、起站、末站與折返列要對得上下表（2026-10-23 的 `GetStop.gz` 快照量到的；最新那一天的 `static_day` 若不是 10-23，以那一份快照重查）：

  | 路線 | 去程 | 去程結束那一端 | 返程 | 返程結束那一端 |
  | --- | --- | --- | --- | --- |
  | 中山幹線 15373 | 46 站，職能發展學院二 → 青年公園(馬場町) | 開過去就走，下一趟從青年社宅出發 | 45 站，青年社宅 → 職能發展學院二 | 停車，下一趟從職能發展學院二出發 |
  | 251 10712 | 55 站，福安居 → 臺北車站(開封) | 開過去就走，下一趟從重慶南路一段出發 | 55 站，重慶南路一段 → 福安居一 | 停車，下一趟從福安居出發 |
  | 251區 11764 | 44 站，福安居 → 捷運公館站 | 開過去就走，下一趟從台電大樓出發 | 47 站，台電大樓 → 福安居一 | 停車，下一趟從福安居出發 |

  中山幹線返程的末站與下一趟的起站同名（職能發展學院二），它們是兩個不同的站牌（`Id` 16738 與 16648，見詞彙表「站牌與站位」），清單照實寫，不是錯。
- 畫面檢查：`bin/dev` 起來之後，在 375px 與 1280px 寬各看一次 `/routes/11764` 與首頁：h1 只有名稱；Id 那一段不會從中間斷開換行；站序區塊收起時只佔標題與一列摘要；展開後 1280px 兩欄並排、375px 一欄。

**Scope boundaries**

- 在範圍內：折返停留卡的標題、頁首與首頁路線卡的 Id 那一行、新的查詢物件與元件、`show.html.erb` 裡的位置、`docs/spectra/LANGUAGE.md` 的「站序」與「路線」一句、route-page 與 home-page 的規格、上面列的測試。
- 不在範圍內：逐站表、區塊導覽、資料限制那張卡、地圖、`LayoverStats` 等四個查詢物件取最新一天的問題、`analysis/` 與衍生表、健檢卡、265區 與 307、網址、部署。

## Risks / Trade-offs

- [Risk] 另一個 session 正在同一個工作目錄 apply turnaround-facilities，`app/views/routes/show.html.erb`、`app/components/section_nav_component.rb` 與 `.yml`、`docs/spectra/LANGUAGE.md`、`spec/requests/routes_spec.rb`、`spec/requests/route_page_fixture_spec.rb` 現在都有它還沒 commit 的修改 → 交件前的兩個任務只碰 `app/components/layover_chart_component.yml`、`app/components/route_coverage_component.*`、`app/components/route_list_component.*`、它們的元件測試與 `spec/requests/pages_spec.rb`，這些檔它都沒有改；詞彙表與站序的任務等它 archive 之後才做。標任務完成時用明確的檔案清單，不讓對方的修改算進這個 change。
- [Risk] Page content 同時被三個 change MODIFIED → 照決定「Page content 以 turnaround-facilities 的版本為底，archive 排在它之後」：站序任務開始前與 archive 前，各用 `/spectra-drift 02-route-stop-sequence` 以那時候的主 spec 為底重寫一次。
- [Risk] 7 天範圍時，站序區塊取最新一天，逐站表與沿線人數圖卻取到最早那天（已知問題）；這幾天裡改過站序的話，兩處的站名會不同 → 站序區塊寫出快照日；已知問題另開 change 修，修好之後兩處就一致。
- [Risk] 首頁的 Id 搬到起迄那一行之後，卡片文字裡仍然有號碼，原本「卡片文字含 9001」的斷言（`spec/requests/pages_spec.rb`、`spec/components/route_list_component_spec.rb`）不會壞，但也測不出 Id 在不在對的那一行 → 改成讀 `[data-route-id]` 的文字與名稱那一行的文字。
- [Trade-off] 251 一個方向 55 站，展開後很長 → 預設收起，640px 以上兩欄並排。
- [Trade-off] 折返列的「下一趟起站」取另一個方向的起站，不逐筆查 → 跟分佈圖的標題同一個取法；之後如果出現同方向接同方向的折返（route-page-charts 那條決定寫的條件），兩處一起改。
