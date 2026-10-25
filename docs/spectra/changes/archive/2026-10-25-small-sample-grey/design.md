## Context

2026-10-24 使用者看 251區（11764）2026-10-22 當天的路線頁截圖，提議「樣本少」不要用字寫出來、改用顏色表示，討論中又問了樣本少的原因。這份 design 記下現況、只看一天為什麼會樣本少，以及改法。能力層級看得到的行為不變：路線頁、`run-time`、`round-trip-cycle` 規格的每一條照舊成立，改的只是這兩張表怎麼把樣本少標給讀者看。

現況（量到的與換算的分開標）：

- `RunTimeTableComponent` 與 `CycleTableComponent` 的模板：樣本少的列是 `tr[data-small-sample]`，整列 `text-slate-500`；其他列沿用路線頁 `main` 的 `text-slate-800`（`app/views/routes/show.html.erb`）。筆數格在數字後面接一個標籤，兩個模板的 markup 一樣：`ml-1.5 inline-block rounded-[5px] bg-slate-100 px-1.5 align-[1px] text-label-sm leading-5 font-medium text-slate-600 sm:ml-2 sm:px-1.75`，字是元件 `.yml` 的 `small_sample`（tw「樣本少」、en「small sample」）。這是 `01-route-page-visual-refresh`「樣本少：整列 slate-500，趟數旁加標籤」的結果。
- 來回一趟／週期表的全天那列 `font-semibold`，不是樣本少時再加 `text-slate-900`；行駛時間表的 p85 格 `font-semibold`，不是樣本少時再加 `text-slate-900`。行駛時間的橫條，樣本少的範圍是 `bg-slate-300`、p85 直線是 `bg-slate-500`，其他列是 `bg-teal-300`、`bg-teal-800`，沒有字（`02-route-page-mobile-first`「行駛時間的橫條用 HTML 定位，刻度兩個方向共用」）。
- 兩張表上方的說明，最後一句是：行駛時間「一列不到 5 趟就標「樣本少」。」，來回一趟與週期「一列不到 5 筆就標「樣本少」。」；en 各是 "Rows with fewer than 5 trips are marked as small samples." 與 "Rows with fewer than 5 values are marked as small samples."。
- 對比：slate-500 對卡片白底 4.76:1（`01-route-page-visual-refresh` 任務 3.1 在 headless Chrome 量到的）；slate-400 對白底 2.56:1（照 Tailwind v3 色碼換算）。樣本少的列（slate-500，v3 色碼 #64748b）對一般列（slate-800，#1e293b）約 3.1:1，也是照 v3 色碼換算的估計值；Tailwind v4 的色值是 oklch，任務 3.1 在瀏覽器量實際的值。
- 路線頁用到色相的地方：teal 是標題、橫條與焦點框；琥珀色（`bg-amber-50 border-amber-300`）是「這一塊沒有資料、要重新載入」的提示框，用在 `TurnaroundFacilitiesComponent`、`MrtOverlapComponent`、`RouteCoverageComponent`、`BufferTradeComponent`；sky 在載客剖面圖；violet 是端點地圖的靜止格。

只看一天為什麼會樣本少（2026-10-24 從開發資料庫算出來的，查詢附在這一節最後）：

- 表裡的一筆是一趟（行駛時間），或一個來回、一個週期。一個小時有幾筆，就是那個小時實際發了幾班車。n-gear 每 10 秒抓一次，決定的是每一趟的時刻準不準、會不會漏站，不會讓趟數變多。
- 251區 2026-10-22：15 台車，去程 54 趟（完整 51、缺起站 2、缺末站 1），返程 53 趟都完整。行駛時間扣掉起點或終點時刻取錯事件的 1 趟後，06 到 22 時每小時 2 到 4 趟。來回一趟全天 51 個、週期 38 個，平均每小時兩三個，所以每一列都不到 5。
- 中山幹線 2026-10-22：去程 83 趟裡有 23 趟缺起站；完整的 121 趟裡，有 30 趟的起點取自到站時刻或終點取自離站時刻，行駛時間不算；來回一趟剩 23 個。這條線的樣本少有一部分來自漏站：feed 每台車只留最新一筆，10 秒抓一次仍會漏站（`docs/data-sources.md` 動態 feed 那一段）。中山幹線起站缺得特別多的原因還沒查。

小時列裡樣本少的列數（樣本少的列／有資料的列）。行駛時間是兩個方向合計；最近 7 天是同一天往前、同一類型的日子，這幾條路線都是 10-19 到 10-22 四個平日：

| 路線 | 範圍 | 行駛時間 | 來回一趟 | 週期 |
| --- | --- | --- | --- | --- |
| 251（10712） | 2026-10-22 當天 | 38／38 | 18／18 | 16／16 |
| 251（10712） | 最近 7 天 | 3／38 | 0／18 | 2／17 |
| 251區（11764） | 2026-10-22 當天 | 35／35 | 17／17 | 15／15 |
| 251區（11764） | 最近 7 天 | 2／36 | 1／18 | 1／15 |
| 中山幹線（15373） | 2026-10-22 當天 | 32／36 | 13／13 | 11／11 |
| 中山幹線（15373） | 最近 7 天 | 4／38 | 4／18 | 5／16 |
| 307（16111） | 2026-10-22 當天 | 3／39 | 4／19 | 4／19 |
| 307（16111） | 最近 7 天 | 2／40 | 2／19 | 2／19 |

查詢（`bin/rails runner`，在唯讀交易裡跑）：

```ruby
[10712, 11764, 15373, 16111].each do |route_id|
  %w[day 7d].each do |range|
    days = RoutePage::Coverage.new(route_id:, day: "2026-10-22", range:).route_days
    run_times = RoutePage::RunTimes.new(days).rows
    rows = RoutePage::Cycles.new(days, ends: RoutePage.ends(route_id)).rows
    round_trips = rows.select { it.n_round_trips.positive? }
    cycles = rows.select { it.n_cycles.positive? }
    puts [route_id, range, "#{run_times.count(&:small_sample)}/#{run_times.size}",
          "#{round_trips.count(&:round_trip_small_sample?)}/#{round_trips.size}",
          "#{cycles.count(&:cycle_small_sample?)}/#{cycles.size}"].join(" ")
  end
end

# 251區與中山幹線那一天的趟數
day = RouteDay.find_by!(route_id: 11764, day: Date.new(2026, 10, 22))
day.trips.distinct.count(:bus_id)                     # 車數
day.trips.group(:go_back, :completeness).count        # 依方向與完整度的趟數
day.trips.where(completeness: "complete", start_from_arrival: false, end_from_departure: false)
   .group(:go_back).group(Arel.sql("extract(hour from start_time at time zone 'Asia/Taipei')::int")).count
RoutePage::Cycles.new(RouteDay.where(id: day.id), ends: RoutePage.ends(11764)).total  # 全天的來回與週期
```

2026-10-25 補：照「樣本少：整列 slate-500，不加看得到的標籤」改完、任務 3.1 驗收之後，使用者看了畫面，認為樣本少的灰字跟一般列分不太出來，決定「把取樣數不足的數字改橘色就好」。量到的與換算的分開標：

- 量到的（任務 3.1，headless Chrome，計算字色用 canvas 換成 rgb）：樣本少的列 slate-500 是 rgb(98, 116, 142)，一般列 slate-800 是 rgb(29, 41, 61)，兩者之間 3.07:1，對卡片白底各是 4.76:1 與 14.62:1。3.1 記下的「分得出來」是 apply 時的目測，使用者看過畫面後推翻。
- 換算的：Tailwind v4 色票的 oklch 換成 sRGB，超出 sRGB 的部分截斷。同一套換算對 slate-500、slate-800 得到的 rgb 跟上面量到的一樣。任務 4.3 在瀏覽器量 orange-700 的實際值。

| 顏色 | rgb | 對卡片白底 | 對一般列 slate-800 |
| --- | --- | --- | --- |
| orange-600 | (245, 73, 0) | 3.6:1 | 4.06:1 |
| orange-700 | (202, 53, 0) | 5.22:1 | 2.8:1 |
| orange-800 | (159, 45, 0) | 7.37:1 | 1.98:1 |
| amber-700 | (187, 77, 0) | 5.03:1 | 2.91:1 |

- 路線頁已經用到橘色與琥珀色的地方：路線圖的兩條線是 `#e95f00`（`03-route-shape-map`，使用者指定），從色碼算對白底 3.44:1；「這一塊沒有資料、要重新載入」的提示框是 `bg-amber-50 border-amber-300`（上面現況那一條列的四個元件）。

## Goals / Non-Goals

**Goals:**

- 兩張表上看不到「樣本少」字樣；樣本少的列只有筆數那一格是橘色，表格上方一行說明橘色的意思（2026-10-25 從整列灰字改過來），哪些列算樣本少跟現在一樣。
- 樣本少的列在一般列之間看得出來，由使用者看截圖判斷。
- 小時列的筆數跟全天那列一樣，貼齊格子右緣。
- 螢幕報讀唸到樣本少那一列的筆數時，接著唸「樣本少」。
- 說明那一句跟畫面一致。

**Non-Goals:**

- 門檻 5、哪些列算樣本少、百分位數與筆數；能力層級看得到的行為（規格不改）。
- 比 orange-700 淺的橘、給樣本少的列加底色、行駛時間的橫條改色。
- 在說明裡寫為什麼樣本少。
- 其他表格（折返停留、載客剖面），它們沒有樣本少的標示。

## Decisions

### 樣本少：整列 slate-500，不加看得到的標籤

**Supersedes**: 01-route-page-visual-refresh / 樣本少：整列 slate-500，趟數旁加標籤

2026-10-25 起，顏色那一半由下一條「樣本少：整列 orange-700，不加看得到的標籤」取代，拿掉標籤那一半照舊。以下是 2026-10-24 的原文。

兩張表樣本少的列照舊整列 `text-slate-500`，筆數格只留數字，拿掉 Context 列的那段標籤 markup。來回一趟／週期表全天那列的字重與顏色、行駛時間表 p85 格的字重與顏色、行駛時間的橫條都照舊。`tr[data-small-sample]` 與門檻 5 不變，`zhongshan-route-page`「樣本少的格子用趟數門檻標出來」照舊成立：數字照樣顯示，它記的理由「它只決定哪些格子要提醒讀者，不影響任何數字」也照舊，只是提醒的方式從字變成灰色。

理由：

- 灰字本身就是提示，標籤是第二個。只看一天時，251、251區、中山幹線的小時列幾乎全是樣本少（Context 的表），同一個標籤重複十幾次，等於沒在提醒。標籤有淺底色、字也比數字深（slate-600 對 slate-500），一整排標籤比數字還搶眼。
- 標籤擠在筆數格，小時列的筆數被推離格子右緣，跟沒有標籤的全天那列對不齊。
- 行駛時間的橫條本來就只用灰色標樣本少、沒有字。拿掉標籤之後，整頁的灰色都是同一個意思。
- 被取代的那條決定，標籤是用來取代舊的括號字「（樣本少）」，整列 slate-500 是為了白底對比不低於 4.5:1。對比那一半這次照留。

替代方案：

- 換一個色相（例如琥珀色）：不採。路線頁的琥珀色已經是「這一塊沒有資料、要重新載入」的提示框，一整排暖色會被讀成出了問題。「用顏色標好壞或門檻」是 `route-page-charts`、`01-route-page-visual-refresh`、`02-route-page-mobile-first`、`run-time-vs-cycle` 的非目標，路線頁規格的 Round trip and cycle block 也寫明 SHALL NOT colour values by their size。灰色依的是筆數夠不夠，不是數字大小，跟這些不衝突；換成暖色，讀者分不出依的是哪一個。
- 換成 slate-400：白底 2.56:1，低於 4.5:1。
- 給樣本少的列加底色（例如 slate-50）：只看一天時整張表幾乎都會上底色，等於沒標；底色加灰字，又是兩個提示講同一件事。
- 只在同一張表裡也有不是樣本少的列時才顯示標籤：同一個標示會依表裡其他列出現或消失，讀者對不起來。
- 保留標籤、只改樣式（變小、拿掉底色）：還是每一列重複，也還是把筆數推離右緣。

### 樣本少：整列 orange-700，不加看得到的標籤

**Supersedes**: small-sample-grey / 樣本少：整列 slate-500，不加看得到的標籤

同一天由下一條「樣本少：只有筆數格用 orange-700，表格上方一行說明」取代。以下是原文。

兩張表樣本少的列，整列的字從 `text-slate-500` 改成 `text-orange-700`：發車時、筆數（趟數）與百分位數都是橘色。筆數格只留數字、看不到「樣本少」字樣，跟被取代的那條一樣。來回一趟／週期表的全天那列照舊 `font-semibold`，不是樣本少時再加 `text-slate-900`，所以全天那列樣本少時是粗體橘字；行駛時間表的 p85 格照舊 `font-semibold`，不是樣本少時再加 `text-slate-900`。行駛時間的橫條不改：樣本少的範圍照舊 `bg-slate-300`、p85 直線 `bg-slate-500`。`tr[data-small-sample]`、門檻 5、筆數格裡的 `sr-only` 都不變。

理由：

- 2026-10-25 使用者看了改成灰字之後的畫面，認為分不太出來（量到 3.07:1，Context）。範圍照使用者的話「把取樣數不足的數字改橘色就好」：樣本少那幾列的數字改色，橫條不是數字，不動。
- orange-700 是對白底不低於 4.5:1 的橘色裡最淺的一階（換算 5.22:1，Context）。4.5:1 是 `01-route-page-visual-refresh` 捨 slate-400 用 slate-500 的同一條線。
- 兩張表各改一個 class（`RunTimeTableComponent` 的 `tr`、`CycleTableComponent` 的 `class_names`），列上的屬性與哪些列算樣本少的分支都不變。

替代方案：

- orange-600 或路線圖的 `#e95f00`：比較亮，跟一般列的明暗差也比較大（orange-600 換算 4.06:1），但當文字對白底只有 3.6:1 與 3.44:1，低於 4.5:1，不採。
- amber-700（換算對白底 5.03:1）：琥珀色是路線頁「這一塊沒有資料」提示框的色相，使用者說的是橘色，不採。
- 只有筆數那一格改橘色，同一列其他格維持灰或回到一般列的深色：使用者要的是取樣數不足的數字改色，不採。
- 橫條也改成橘色：使用者只要求數字，這次不改；之後要改，跟這一條一起看橘色在橫條上的對比。
- 維持灰色：使用者看過畫面後否決。

### 樣本少：只有筆數格用 orange-700，表格上方一行說明

**Supersedes**: small-sample-grey / 樣本少：整列 orange-700，不加看得到的標籤

樣本少的列只有筆數（趟數）那一格加 `text-orange-700`，同一列其他格跟一般列一樣：`tr` 不帶字色 class；行駛時間表的 p85 格一律 `font-semibold text-slate-900`；來回一趟／週期表的全天那列一律 `font-semibold text-slate-900`，全天那列樣本少時只有它的筆數是橘色。行駛時間的橫條照舊：樣本少的範圍 `bg-slate-300`、p85 直線 `bg-slate-500`。筆數格裡的 `sr-only` 與 `tr[data-small-sample]` 不變。

兩張表的表格正上方各一行 `p[data-small-sample-legend]`，文字讀 `small_sample_legend_html`，`%{orange}` 換成 `span.font-semibold.text-orange-700` 包住的「橘色」：行駛時間那一行在有列時出現（`scale` 不是 nil），來回一趟與週期那一行在有來回時出現，跟表格同一個分支。說明段落裡講顏色的那一句拿掉，改由這一行講。

理由：使用者 2026-10-25 看過整列橘字的做法後說「只要「筆數」就好，不用整個 row 變色」，又要「在表格上方註記橘色是取樣不足的意思」，句子照使用者給的「橘色數字表示樣本少於 5 筆。」。橘色只落在跟門檻 5 比的那個數字上，百分位數不上色。

替代方案：整列橘字（上一條，使用者否決）；說明照舊放在說明段落的最後一句（使用者要放在表格上方）。

### 筆數格帶只給螢幕報讀的「樣本少」

樣本少的列，筆數格在數字後面接一個 `<span class="sr-only">`，內容是一個半形空白加上 `small_sample` 的文案。空白放在 `sr-only` 裡面，看得到的格子只有數字。這個空白是為了讓報讀時數字跟「樣本少」（en「small sample」）分成兩個詞，但 span 絕對定位之後，開頭的空白可能在排版時被拿掉，所以要在瀏覽器的無障礙樹確認；沒有分開時改用 Implementation Contract「失敗的樣子」寫的另一種放法。`sr-only` 是 Tailwind v4 內建的 utility，絕對定位、1px、裁掉，不佔版面，所以數字跟全天那列一樣貼齊格子右緣。不是樣本少的列沒有這個 span。

理由：顏色（原本的灰、2026-10-25 起的橘）只對看得到的人有用，報讀軟體唸不出來。筆數就在格子裡、說明寫了 5，看得到的人可以自己比；聽的人要記住 5 再比大小。專案已經用 `sr-only` 給螢幕報讀補字：折返停留表的 `<caption>`、名稱列的站名，以及這兩張表在手機上的方向或表名標題（`max-sm:sr-only`）。

替代方案：

- 不給螢幕報讀任何字：聽的人只有筆數，要自己跟說明裡的 5 比。
- 在 `<td>` 加 `aria-label`：它會取代格子的內容當名稱，數字要在 label 裡再寫一次，兩份容易對不上。
- 用 `title`：手機上沒有滑鼠移上去這件事，報讀軟體也不一定唸。

### 行駛時間表與來回一趟／週期表一起改

兩張表的標籤是同一段 markup、同一個 `small_sample` 文案，一起改。`run-time-vs-cycle`「按前段發車的台北小時分組，加一列全天，樣本少的門檻共用」記的理由是「門檻共用是為了同一個「樣本少」在同一頁只有一個意思」；只改一張的話，同一頁就有兩種標法。

替代方案：只改使用者截圖裡的來回一趟／週期表。不採，理由同上。

### 文案

- 行駛時間（`app/components/run_time_table_component.yml`）：`note` 拿掉最後一句「一列不到 5 趟就標「樣本少」。」（en "Rows with fewer than 5 trips are marked as small samples."）。表格上方那一行用新鍵 `small_sample_legend_html`：tw「%{orange}數字表示樣本少於 5 趟。」，en "Numbers in %{orange} mean the sample has fewer than 5 trips."；新鍵 `orange`：tw「橘色」，en "orange"。
- 來回一趟與週期（`app/components/cycle_table_component.yml`）：`note_html` 拿掉最後一句「一列不到 5 筆就標「樣本少」。」（en "Rows with fewer than 5 values are marked as small samples."）。`small_sample_legend_html`：tw「%{orange}數字表示樣本少於 5 筆。」，en "Numbers in %{orange} mean the sample has fewer than 5 values."；`orange` 同上。
- 經過：任務 1.1、2.1 把最後一句寫成「一列不到 5 趟（筆）就用灰字，表示樣本少。」，4.1、4.2 改成「一列不到 5 趟（筆），數字就用橘色，表示樣本少。」，2026-10-25 同一天再改成上面的做法（任務 4.5），表格上方那一句是使用者給的。
- 兩個檔的 `small_sample`（tw「樣本少」、en「small sample」）留著，改給 `sr-only` 用。zh-TW 照舊 `<<: *tw` 共用 tw。
- 說明的其他句子不動，照 `run-time-vs-cycle`「文案」；新句子跟那條一樣，不出現合規、達標、門檻。

替代方案：在這句加上原因，例如「只看一天時，一個小時通常只有幾班車」。不採：這句不是每條路線都對。307 在 2026-10-22 當天，行駛時間 39 列只有 3 列樣本少；中山幹線當天的樣本少，有一部分是漏站（Context）。

### 測試沿用既有的分支例子，class 與文字在瀏覽器驗

專案 `.spectra.yaml` 開了 `tdd: true`。照 tasks 的驗證規則，寫死的 class、元素與文字（沒有分支選它、沒有輸入填它）用內容檢查或畫面檢查驗，不寫斷言；分支照常用測試守。這個 change 沒有新的分支：哪些列帶「樣本少」、帶 `data-small-sample`，跟改之前一樣由 `small_sample` 決定。所以不新增例子，也沒有改之前會失敗的例子。

- 分支由既有的例子守：`spec/components/cycle_table_component_spec.rb` 的「筆數少於 5 的列都標成樣本少，並在筆數旁寫出來」與「同一列兩個量各自判斷樣本少：來回 5 筆不標，週期 4 筆標」，`spec/components/run_time_table_component_spec.rb` 的「樣本少的列在趟數旁標出樣本少，其他列沒有」。它們用 `small_sample_marks` 或同樣的寫法，斷言每一列的 `data-small-sample` 與文字含不含 `small_sample`。`render_inline` 回傳的是 Nokogiri 節點，`.text` 會含 `sr-only` 裡的字，所以這三個例子改完前後都綠，斷言不動。
- 改兩個標題，讓標題跟畫面一致：「筆數少於 5 的列都標成樣本少，並在筆數旁寫出來」改成「筆數少於 5 的列都標成樣本少，筆數格帶給螢幕報讀的「樣本少」」；「樣本少的列在趟數旁標出樣本少，其他列沒有」改成「樣本少的列在趟數格帶給螢幕報讀的「樣本少」，其他列沒有」。`cycle_table_component_spec.rb` 的 `cell_text` 註解「without the small sample label inside it」改成「without the screen reader words inside it」；它用 `./text()` 只取格子自己的字，本來就略過 span，行為不變。
- 看得到與看不到（`sr-only`）、拿掉的標籤、說明的文字，都是寫死的內容，在瀏覽器與內容檢查驗，步驟在 Implementation Contract 的「驗收」。
- 改成橘色也一樣：`text-orange-700` 是寫死的 class，不寫斷言。2026-10-25 grep `spec/`，沒有例子斷言 `text-slate-500` 或 `text-orange-700`；`spec/components/run_time_table_component_spec.rb` 的「樣本少的列也有橫條，顏色比較淡」斷言的是橫條的 `bg-slate-300`，橫條不改色，照舊成立。兩個 spec 檔不用改。後來只有筆數格橘色、表格上方多一行說明，也是寫死的內容：那一行放在既有的分支裡（行駛時間的 `if scale`、來回一趟與週期的 `if any_round_trips?`），不另寫斷言。

替代方案：新增例子，斷言樣本少那一格的「樣本少」在 `.sr-only` 裡、列帶 `text-slate-500`。不採：這是在斷言寫死的 class，只會在有人改 class 時紅，照專案的測試範圍規則不寫。

## Implementation Contract

**行為（使用者看到的）**

- 路線頁的行駛時間表與來回一趟／週期表：樣本少的列只有筆數那一格是橘色（`text-orange-700`），同一列其他格跟一般列一樣；筆數格只有數字，看不到「樣本少」字樣；小時列的筆數跟全天那列一樣貼齊右緣。不是樣本少的列跟現在一樣。
- 行駛時間的橫條不變。
- 兩張表的表格正上方各一行說明橘色的意思，寫的是 design「文案」那兩句；說明段落不再講顏色。
- 螢幕報讀唸到樣本少那一列的筆數時，接著唸「樣本少」（en「small sample」）。
- 能力層級看得到的行為不變：路線頁、`run-time`、`round-trip-cycle` 規格的每一條照舊成立；列照舊標成樣本少、門檻照舊是 5、數字照樣顯示。

**介面與資料形狀**

- Ruby 不改：`RunTimeTableComponent`、`CycleTableComponent`、`RoutePage::RunTimes::Row#small_sample`、`RoutePage::Cycles::Row#round_trip_small_sample?` 與 `#cycle_small_sample?` 都不動，只改兩個模板與兩個 `.yml`。
- 樣本少那一列的筆數格：數字之後接 `<span class="sr-only">`，內容是半形空白加 `t(".small_sample")`（無障礙樹裡沒有分開時，空白改放在數字與 span 之間，見「失敗的樣子」）；兩個模板都沒有 `rounded-[5px]`。
- `tr[data-small-sample]` 不變，`tr` 不帶字色 class。樣本少那一列的筆數格帶 `text-orange-700`；行駛時間的 p85 格一律 `font-semibold text-slate-900`，來回一趟／週期表的全天那列一律 `font-semibold text-slate-900`；橫條的 `bg-slate-300` 與 `bg-slate-500` 不變。表格上方一行 `p[data-small-sample-legend]`，讀 `small_sample_legend_html` 與 `orange`。

**失敗的樣子**

- 漏改其中一張表：那張表的標籤還在，測試照樣綠。驗收用 grep 確認兩個模板都沒有 `rounded-[5px]`，再兩張表都看畫面。
- 報讀時數字跟「樣本少」黏在一起（無障礙樹裡那一格的名稱中間沒有空白，`sr-only` 開頭的空白被拿掉）：把空白從 span 裡移到數字與 span 之間，當成格子裡的文字。這個空白在行尾、後面只接絕對定位的元素，照 CSS 的空白規則應該也會被拿掉，數字仍然貼齊右緣；改完再量一次對齊與無障礙樹，在 tasks.md 記下最後用的是哪一種放法。兩種都不行就停下來回報。
- 漏改其中一張表的顏色：那張表的樣本少列還是整列上色，測試照樣綠。驗收用 grep 確認兩個模板都沒有 `"text-slate-500" if row.small_sample`、`"text-slate-500": small_sample` 或 `"text-orange-700": small_sample`，再用開發資料庫算出來的表確認橘色的 `td` 都是筆數格，兩張表都看畫面。

**驗收**

- 分支：`bundle exec rspec spec/components/run_time_table_component_spec.rb spec/components/cycle_table_component_spec.rb` 改之前與改之後都綠。
- grep：`grep -n "rounded-\[5px\]" app/components/run_time_table_component.html.erb app/components/cycle_table_component.html.erb` 沒有結果。
- 內容檢查：`git diff app/components/run_time_table_component.yml app/components/cycle_table_component.yml` 只有說明最後一句的 tw 與 en，其他鍵與句子不變。
- 畫面（`bin/dev`，開發資料庫）：開 `/routes/11764?day=2026-10-22`（截圖那一天，三種表的小時列全是樣本少）與 `/routes/15373?day=2026-10-22&range=7d`（行駛時間 38 列有 4 列、週期 16 列有 5 列樣本少，Context 的表），1280 寬與 390 寬（headless Chrome 最窄 500px，390 用 CDP 模擬；手機上兩張表、兩個方向各切一次）：
  - 截圖裡兩張表都看不到「樣本少」字樣。
  - 每一個 `tr[data-small-sample]` 的筆數格裡，含「樣本少」的元素只有一個，計算後的 `position` 是 `absolute`、寬是 1px。
  - 同一張表裡，每一列筆數文字（格子裡的第一個文字節點，用 Range 量）的 `getBoundingClientRect().right` 相差不到 1px；來回一趟／週期表包含全天那列。
  - 15373 最近 7 天那頁：樣本少的列與一般列的計算字色，用 canvas 換成 rgb，記下兩者之間的對比，再看截圖裡灰色列在一般列之間分不分得出來。分不出來就停下來回報，不自己加顏色或底色。
  - 用 CDP 的 `Accessibility.getPartialAXTree` 取一個樣本少那一列的筆數格，名稱含數字與「樣本少」，兩者之間有空白；沒有空白時照「失敗的樣子」改放法，再量一次。
  - 結果記在 tasks.md 那條任務下面。
- 全部：`bin/rubocop` 對改到的兩個 spec 檔沒有 offense；`bin/rails parallel:spec` 全綠。
- 改成橘色之後（任務 4.1 到 4.5，最後的做法是 4.5）：
  - 分支：`bundle exec rspec spec/components/run_time_table_component_spec.rb spec/components/cycle_table_component_spec.rb` 改之前與改之後都綠。
  - grep：`grep -n "text-orange-700" app/components/run_time_table_component.html.erb app/components/cycle_table_component.html.erb` 兩個檔各兩處（筆數格與表格上方那一行的「橘色」）；`grep -n '"text-slate-500" if row.small_sample\|"text-slate-500": small_sample\|"text-orange-700": small_sample' app/components/run_time_table_component.html.erb app/components/cycle_table_component.html.erb` 沒有結果。
  - 內容檢查：`git diff app/components/run_time_table_component.yml app/components/cycle_table_component.yml` 只有說明拿掉最後一句，以及新增 `small_sample_legend_html` 與 `orange`（tw、en）。
  - 畫面：同樣兩頁、兩種寬度。樣本少那一列筆數格的計算字色用 canvas 換成 rgb，對卡片白底不低於 4.5:1（換算 5.22:1），量到低於 4.5:1 就停下來回報；同一列其他格跟一般列一樣。全天那列是粗體 slate-900；行駛時間的橫條樣本少時仍是 `bg-slate-300`、`bg-slate-500`。對齊、`sr-only` 的元素與無障礙樹照上面的方法各再量一次；表格正上方那一行是「文案」那兩句。截圖時表頭不被固定的區塊導覽列蓋住。截圖的完整路徑交給使用者，使用者看過、說樣本少的列在一般列之間分得出來，才算通過；分不出來就停下來回 design，不自己換顏色。結果記在 tasks.md 那條任務下面。
  - 全部：`bin/rails parallel:spec` 全綠。

**範圍**

- 範圍內：`app/components/run_time_table_component.html.erb`、`app/components/run_time_table_component.yml`、`app/components/cycle_table_component.html.erb`、`app/components/cycle_table_component.yml`、`spec/components/run_time_table_component_spec.rb`、`spec/components/cycle_table_component_spec.rb`。
- 範圍外：`app/models/`、`analysis/`、衍生表、規格、詞彙表、其他元件。
- 順序：兩個 `.html.erb` 在工作區有 `ui-touchups`（已歸檔、未 commit）的修改（`select-none`、拿掉 `max-w-[46em]`），apply 前先請使用者 commit 那一批。進行中的 `02-end-nature-survey` 的 proposal 與 tasks 沒有提到這六個檔（2026-10-24 用檔名比對過）。同一個工作目錄有別的 session 時，標任務完成用 `spectra task done … --file`。

## Risks / Trade-offs

- [最近 7 天時樣本少的列是少數，拿掉標籤後只靠灰字跟一般列區分] → 灰字對一般列約 3.1:1（換算值），差在明暗不在色相，色盲的讀者也分得出；驗收在 15373 最近 7 天那頁量實際的對比、看截圖。分不出來就回報，不在這個 change 自己加顏色。2026-10-25 這條風險成真：3.1 量到 3.07:1，使用者看過畫面認為分不太出來，改成橘色（「樣本少：整列 orange-700，不加看得到的標籤」）。
- [橘色數字被讀成「這幾個小時的數字有問題」：這一塊的標題是「跑得完嗎？」，暖色容易被當成警告] → 橘色只在筆數，百分位數不上色；表格正上方一行寫明橘色表示樣本少於 5 趟（筆）；使用者 2026-10-25 聽過這個顧慮後決定用橘色。
- [orange-700 跟一般列的明暗差（換算 2.8:1）比灰色（量到 3.07:1）小，看得出來主要靠色相；紅綠色弱的讀者可能比灰色更難分] → 使用者接受；任務 4.3 量實際的對比記下來。
- [路線頁別處已有橘色與琥珀色：路線圖的線 `#e95f00`、「沒有資料」提示框的 amber] → 在不同區塊，不會跟這兩張表的列混在一起；使用者接受。
- [同一列的筆數是橘色、橫條是灰色] → 使用者只要求筆數改色；橫條的灰從 `02-route-page-mobile-first` 起就表示樣本少，表格上方那一行只講數字。
- [沒讀說明的人不知道橘色是什麼意思] → 表格正上方那一行寫明；筆數照樣顯示，全天那列是粗黑字。
- [分支例子用 `.text` 找字，分不出「樣本少」看得到還是看不到] → 看不看得到由寫死的 class 決定，照專案的測試範圍規則在瀏覽器驗；之後若有人拿掉 `sr-only`，字會重新出現在畫面上，測試不會紅，這是規則接受的取捨。
- [`ui-touchups` 未 commit 的修改在同兩個模板] → apply 前先 commit 那一批。

## Migration Plan

沒有資料、設定或衍生表要動，正式站不用重跑 `derived:load`。跟著下一次部署上線；要回復，就是還原這六個檔。

## Open Questions

（無）
