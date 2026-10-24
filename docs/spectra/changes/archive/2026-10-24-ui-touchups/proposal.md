## Why

這個 change 服務第一樣交付物「路線健檢卡」與第二樣「換休息試算」在網站上的呈現，以及每一頁共用的網站名稱列：數字都在路線頁 `/routes/:route_id` 上給人讀。不新增任何資料，讀的仍是衍生表，資料來源不變；名稱列新增的連結指向作者自己寫的介紹文章（https://kaochenlong.com/bus-turn-around，2026-10-24 發佈）。

2026-10-24 使用者看正式站 16111（307）時提出四件事，討論後的結論：

- 折返停留分佈圖的 15 分鐘分隔線，字「15 分鐘」跟 10–15 那一列的筆數「75」黏在一起。字畫在虛線上方，落在 10–15 那一列的高度裡；筆數接在長條尾端之後。10–15 是這個方向最多的一組時長條畫滿，兩段字的位置重疊（正式站 16111 去程結束的 10–15 是 75 筆、最多；返程結束最多的是 15–30 的 74 筆，沒有撞）。307 兩端折返停留的中位數在 13 到 15 分鐘附近（`02-route-307-page`「307 兩端都停車，查證寫進設定」，一天版的證據），所以這不是少見的資料。
- 說明文字在桌機上沒有滿版，右邊空一塊。這是 `max-w-[46em]` 的行寬上限（一行最多約 46 個中文字），從第一個路線頁 commit 就在，但沒有任何文件寫下理由，同一串 class 散在 9 個元件、14 處。討論時建議保留寬度、併成一個有名字的寬度；2026-10-24 使用者看過畫面還是沒有滿版，聽完行長的理由後改成滿版，14 處一起拿掉上限。
- 區塊導覽那排 pill 的字會被選取：全選時整排反白，複製頁面內容也會帶上。結論是控制項（導覽、切換、按鈕）的字不能選取，內容的字照舊。
- 名稱列右上角：先討論過放「資料最後更新時間」，因為資料新不新是看路線的、資料庫裡也沒有推上正式站的時刻而放棄；改放「關於這個網站」連到介紹文章。駕駛是直接打開自己那條線的路線頁（`docs/use-cases.md` 第 11 項），看不到首頁的起點區塊，名稱列是每一頁都有的地方。

另外，`docs/spectra/LANGUAGE.md`「路線頁」的定義寫「每天更新」與「最近一個月」，跟現況（人工載入、範圍是某一天與最近 7 天）不符，一起改正。

## What Changes

- 分佈圖：15 分鐘分隔線那裡多留一段空白（14 個 viewBox 單位），虛線畫到底軌末端為止，「15 分鐘」接在虛線之後、跟虛線同高。字所在的那段高度沒有任何長條或筆數，筆數幾位數都不會再撞。圖寬、長條最長、字級都不變，圖高多 14 單位。
- 說明文字的行寬：9 個元件裡 14 處 `max-w-[46em]` 全部拿掉，路線頁各區的說明、粗體摘要、表下註記與首頁 hero 的摘要，跟所在的卡片或欄位一樣寬。手機上本來就碰不到這個上限，看起來不變。
- 控制項的字不能選取：路線頁的區塊導覽、範圍切換、來回一趟與週期／行駛時間／載客剖面的切換按鈕、換休息試算那一塊的控制項，以及首頁起點區塊的連結與 hero 動畫的暫停按鈕，加 `select-none`。重點數字卡、路線清單卡、表格、日期連結這些內容不加。
- 名稱列：logo 右邊加一個連結「關於這個網站」（en：About this site），連到 https://kaochenlong.com/bus-turn-around，在原分頁開、不加圖示，字不能選取。手機上跟 logo 同一行。名稱列改成左右排列之後，高度從 83px 變成 77px（logo 上下各 14px，量到的），使用者選了保留。
- 詞彙表：「路線頁」的定義改成符合現況。
- 測試：照專案 `.spectra.yaml` 的 `tdd: true` 與它的測試範圍規則，寫死的 class、文字、版面不寫斷言（那種斷言只會在有人改那個字時紅）。分佈圖的元件測試加一條「分隔線的字整個落在 10–15 與 15–30 兩根長條之間的空白裡」，因為分隔線之後的列要往下移，是算出來的位置；`select-none`、拿掉 `max-w-[46em]` 與名稱列的新連結是寫死的內容，不寫斷言，在開發站量 `user-select`、`max-width`、全選、連結的文字與網址驗收；`spec/system/rest_command_spec.rb` 點回首頁的選擇器改成只選 `href="/"` 的那個連結，因為名稱列有兩個連結之後原本的選擇器會選到兩個。

## Non-Goals

- 指標、資料、衍生表一律不動。
- 名稱列不放時間：資料新不新是每條路線各自的（首頁卡片與路線頁頁首已經寫了），`route_days.loaded_at` 是筆電算好的時刻、不是推上正式站的時刻；`home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」也不讓頁面暗示更新頻率。
- 名稱列不做選單；車牌查詢、回報表單、月報等連結有了再說。
- 文章連結不開新分頁、不加外部連結圖示：跟起點區塊連到《未來城市》的連結一致，整個 app 沒有開新分頁的連結。
- 說明文字以外的寬度（卡片、表格、圖）不動。
- 不拿掉「15 分鐘」，也不改它的樣式（`fill-slate-500 text-label-sm`）；分佈圖照舊不用顏色標任何一邊。
- 不加 `select-none` 的：重點數字卡、首頁路線清單卡、表格、日期連結、樣本少標籤、`<summary>` 收合列（站序、逐站表、公廁清單；它們的字是那一塊的標題與說明）、footer 與起點區塊出處裡的連結。
- 介紹文章本身的內容（文中寫網站有三條路線，正式站現在是四條）由使用者決定要不要改，不在這個 change。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `site-layout`: 「Site name bar on every page」：名稱列除了回 `/` 的站名連結，再帶一個連到介紹文章的「關於這個網站」，在原分頁開。

## Impact

- Affected specs: site-layout
- Affected code:
  - Modified: app/components/layover_chart_component.rb, app/components/layover_chart_component.html.erb, spec/components/layover_chart_component_spec.rb, app/components/load_chart_component.html.erb, app/components/turnaround_facilities_component.html.erb, app/components/mrt_overlap_component.html.erb, app/components/layover_table_component.html.erb, app/components/home_hero_component.html.erb, app/components/buffer_trade_component.html.erb, app/components/cycle_table_component.html.erb, app/components/run_time_table_component.html.erb, app/components/section_nav_component.html.erb, app/components/route_coverage_component.html.erb, app/components/origin_story_component.html.erb, app/components/site_bar_component.rb, app/components/site_bar_component.html.erb, spec/system/rest_command_spec.rb, docs/spectra/LANGUAGE.md
  - New: app/components/site_bar_component.yml
  - Removed: (none)
- 排程：`buffer-trade-cost-curve`（2026-10-24 已有 15 個任務、暫存中）的 3.1 到 3.4 重做 `app/components/buffer_trade_component.html.erb`，4.1 讓拉桿在瀏覽器裡移動、有 JavaScript 時隱藏重算按鈕；換休息試算那一塊的 `select-none` 排在這五條之後。說明文字行寬原本也排在它之後（它的 1.1 與 design 風險那條這樣寫），2026-10-24 改成滿版時它還沒開始（暫存、0/15），換休息試算那 3 處跟其他 11 處一起先做，它那兩句因此過時，要不要更新那個 change 由使用者決定。`01-pass-through-wording` 的任務只跑 `spec/components/layover_chart_component_spec.rb` 驗收、不改它；它與 `buffer-trade-cost-curve` 都改 `docs/spectra/LANGUAGE.md` 的別的條目。`02-end-nature-survey`（2026-10-24 出現、暫存）沒有提到這個 change 剩下要改的檔。細節在 design 的 Implementation Contract「順序」。
