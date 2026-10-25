## Why

這個 change 服務第一樣交付物「路線健檢卡」在網站上的呈現：路線頁 `/routes/:route_id` 的行駛時間表與來回一趟／週期表。不新增任何資料，讀的仍是衍生表 `trips` 與 `layovers`；哪些列算樣本少（筆數少於 `RoutePage::RunTimes::SMALL_SAMPLE`，也就是 5）不變，不牽涉指標定義。

2026-10-24 使用者看 251區（11764）2026-10-22 當天的路線頁，來回一趟 17 列、週期 15 列全部是樣本少，每一列的筆數旁都掛著「樣本少」標籤，提議不要用字寫出來、改用顏色表示。討論後的結論：

- 樣本少的列本來就整列灰字（`text-slate-500`，其他列是頁面的 slate-800），標籤是疊在灰字上的第二個提示。只看一天時幾乎每一列都樣本少，同一個標籤重複十幾次；標籤有淺底色、字又比數字深（slate-600），一整排標籤比數字還搶眼。標籤擠在筆數那格，小時列的筆數被推離右緣，跟全天那列的筆數對不齊。
- 只看一天會樣本少，是因為表裡的一筆是一趟（或一個來回），一個小時有幾筆，就是那個小時實際發了幾班車；10 秒輪詢決定每一趟量得多準，不會讓趟數變多。從開發資料庫算出來，2026-10-22 當天 251、251區、中山幹線的表，小時列幾乎全是樣本少；同一天的最近 7 天（涵蓋四個平日）只剩少數幾列。數字與查詢在 design 的 Context。
- 行駛時間的橫條本來就只用灰色標樣本少、沒有字。拿掉標籤之後，整頁的灰色都是同一個意思。

2026-10-25 補：照上面改完、驗收之後，使用者看了畫面，認為樣本少的灰字跟一般列分不太出來（slate-500 對一般列的 slate-800，任務 3.1 在瀏覽器量到 3.07:1），決定「把取樣數不足的數字改橘色就好」。拿掉標籤、改帶螢幕報讀的「樣本少」照舊；行駛時間的橫條不是數字，維持灰色。原本 Non-Goals 寫的「不加新的色相」因此拿掉，它擔心的讀法（暖色被讀成數字有問題）與路線頁別處的橘色、琥珀色，記在 design 的 Risks。同一天再改：只有筆數（趟數）那一格用橘色，整列不變色；表格正上方加一行說明橘色的意思，說明段落裡講顏色的那一句移到這一行。

## What Changes

- 行駛時間表與來回一趟／週期表：樣本少的列只有筆數（趟數）那一格改成 `text-orange-700`，同一列其他格跟一般列一樣（原本是整列 `text-slate-500`）；拿掉筆數格裡看得到的「樣本少」標籤；筆數格改帶一段只給螢幕報讀的「樣本少」（`sr-only`）。看得到的只剩數字，跟全天那列一樣靠右對齊。行駛時間的橫條（樣本少時是灰色）、`tr[data-small-sample]` 都不變。
- 兩張表上方的說明：最後一句「一列不到 5 趟（筆）就標「樣本少」」拿掉（任務 1.1、2.1 一度改成「用灰字」），改在表格正上方獨立一行「橘色數字表示樣本少於 5 趟（筆）。」，「橘色」兩個字用橘色；tw（zh-TW 共用）與 en 一起改，其他句子不動。
- 測試：照 `.spectra.yaml` 的 `tdd: true` 與 tasks 的驗證規則，寫死的 class、元素與文字用畫面檢查或內容檢查驗，不寫斷言。哪些列帶「樣本少」是分支，由既有的例子斷言：`spec/components/cycle_table_component_spec.rb` 的「筆數少於 5 的列都標成樣本少，並在筆數旁寫出來」與「同一列兩個量各自判斷樣本少：來回 5 筆不標，週期 4 筆標」，`spec/components/run_time_table_component_spec.rb` 的「樣本少的列在趟數旁標出樣本少，其他列沒有」。`sr-only` 裡的字也算在 Nokogiri 的 `.text` 裡，所以這三個例子改完前後都綠；只把標題裡的「並在筆數旁寫出來」「在趟數旁標出」改成講螢幕報讀，免得標題跟畫面不符。`text-orange-700` 跟原本的 `text-slate-500` 一樣是寫死的 class，不寫斷言；2026-10-25 grep `spec/`，沒有例子斷言這兩個 class，行駛時間的「樣本少的列也有橫條，顏色比較淡」斷言的是橫條的 `bg-slate-300`，橫條不改色，照舊成立。

## Non-Goals

- 門檻 5、哪些列算樣本少、百分位數與筆數都不動。
- 行駛時間的橫條不改色：使用者只要求數字改橘色（2026-10-25），橫條照舊用灰色標樣本少（範圍 `bg-slate-300`、p85 直線 `bg-slate-500`）。
- 不用比 orange-700 淺的橘：orange-600 對白底 3.6:1、路線圖的線用的 `#e95f00` 3.44:1（換算值，算法在 design 的 Context），都低於 4.5:1；`01-route-page-visual-refresh` 當初捨 slate-400（2.56:1）改用 slate-500，也是這條線。
- 不給樣本少的列加底色：只看一天時幾乎整張表都會上底色。
- 說明不加「為什麼樣本少」：一句通用的原因不是每條路線都對。307 在 2026-10-22 當天的行駛時間 39 列只有 3 列樣本少；中山幹線當天的樣本少，有一部分是起站漏抓。
- 不改規格：路線頁、`run-time`、`round-trip-cycle` 的規格只寫列要 marked as a small sample，沒寫怎麼標。`01-route-page-visual-refresh` 把同一個標示從括號字改成標籤時也是 `no-spec`。路線頁規格的 Round trip and cycle block 寫的是 SHALL NOT colour values by their size；橘色依筆數決定、不依數值大小，不牴觸這一條。
- 其他表格（折返停留、載客剖面）沒有樣本少的標示，不在範圍內。

## Impact

- Affected specs: none
- Affected code:
  - New: (none)
  - Modified: app/components/run_time_table_component.html.erb, app/components/run_time_table_component.yml, app/components/cycle_table_component.html.erb, app/components/cycle_table_component.yml, spec/components/run_time_table_component_spec.rb, spec/components/cycle_table_component_spec.rb
  - Removed: (none)
- Compatibility: no capability-level observable behavior changes
- 順序：兩個 `.html.erb` 在工作區有 `ui-touchups`（已歸檔、未 commit）的修改（`select-none`、拿掉 `max-w-[46em]`）。apply 前先 commit 那一批，這個 change 的 commit 才不會混進去。進行中的 `02-end-nature-survey` 沒有碰到這六個檔。
