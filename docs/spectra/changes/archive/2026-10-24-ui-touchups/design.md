## Context

2026-10-24 看正式站 16111（307）時提出的四件畫面上的事，加上一處詞彙表與現況不符。四件事彼此無關，放在同一個 change 是因為都小、都在畫面層，而且動到的檔案有重疊（見 Implementation Contract 的順序）。

現況（量到的與換算的分開標）：

- 分佈圖 `LayoverChartComponent` 的尺寸照 `01-route-page-visual-refresh`「分佈圖改成一張 300 寬的 SVG，手機與桌機共用」：`WIDTH = 300`、`LABEL_WIDTH = 40`、`BAR_MAX = 190`、`ROW = 30`、`BAR_HEIGHT = 18`，長條從 x = 48 開始，分隔線的字 `text-label-sm`（13）。分隔線的字靠右對齊在 x = 300、基線在虛線上方 5 單位（y = 83），落在 10–15 那一列的高度範圍（長條 y 64–82，筆數基線 78.5）；筆數畫在長條尾端後 6 單位。10–15 是最多的一組時筆數從 x = 244 開始，「15 分鐘」約 43 單位寬（換算值：Barlow 數字約 0.55 em、中文 1 em），佔 x 約 257–300，兩段字重疊。正式站 16111 去程結束的六組是 7、51、75、47、27、8（2026-10-24 從正式站的 SVG 讀到），截圖與 headless Chrome 的渲染都看得到重疊。SVG 在桌機畫成 340px、390px 寬的手機上 316px（2026-10-24 在正式站量）。
- `max-w-[46em]` 出現在 9 個元件、14 處（2026-10-24 grep）：路線頁 13 處，首頁 hero 1 處。最早出現在 commit `ead9744`（第一個路線頁），spec、design 與決定紀錄都沒有寫理由。17px 的內文 46 em 是 782px；桌機卡片內容約 1006px（`01-route-page-visual-refresh`「頁面最寬 1152px，首頁、路線頁與 footer 同一組寬度」的換算），滿版時一行約 59 個中文字。
- 整個 app 沒有 `select-none`。2026-10-24 用 headless Chrome 在正式站 16111 試過：在區塊導覽的 pill 上連點兩下、三下選不到字；全選時導覽的字會被選進去，加了 `user-select: none` 就不會；手機版切換按鈕（`<button>`）全選時也會被選進去。Safari 沒有測。Tailwind v4 的 `select-none` 同時輸出 `-webkit-user-select: none` 與 `user-select: none`（看過 `node_modules/tailwindcss` 的 dist）。
- `SiteBarComponent` 只有一個 logo 連結回 `/`。390×844 的手機上名稱列高 83px，logo 佔 x 16–156，右邊同一行約 218px 是空的；16111 最低的重點數字底部在 712px，`02-route-page-mobile-first`「手機的第一個畫面放得下四個重點數字」要求在 844px 以內（都是 2026-10-24 在正式站量的）。
- 介紹文章 https://kaochenlong.com/bus-turn-around 標題「公車司機的 10 分鐘」，2026-10-24 發佈，內容是為什麼選折返點、資料只有「現在」、n-gear、收下來之後、SDD 開發、從中山幹線看到什麼、可以怎麼做、誰會用、做不到的事。

## Goals / Non-Goals

**Goals:**

- 分佈圖分隔線的字，不管哪一組最多、筆數幾位數，都不會跟筆數或長條重疊。
- 說明文字跟所在的卡片或欄位一樣寬，14 處一起，不留一區例外。
- 控制項的字不會被選取，也不會在全選、複製頁面內容時被帶上；內容的字照舊可以選。
- 每一頁的名稱列都能連到介紹文章。
- 詞彙表「路線頁」的定義跟現況一致。

**Non-Goals:**

- 指標、資料、衍生表、區塊順序。
- 名稱列放時間、做選單、加其他連結。
- 說明文字以外的寬度（卡片、表格、圖）。
- 拿掉或換掉「15 分鐘」的樣式；用顏色標分佈圖的任何一邊。
- 內容元素的選取行為（重點數字卡、路線清單卡、表格、日期連結、樣本少標籤、`<summary>` 收合列、footer）。
- 介紹文章本身的內容。

## Decisions

### 分隔線那裡多留一段空白，字接在虛線之後、跟虛線同高

在 15 分鐘那裡（`DIVIDER_MINUTES` 的那一組之前）多留 `DIVIDER_GAP = 14` 個 viewBox 單位：從那一組開始的每一列往下移 14，圖高加 14。虛線畫在 10–15 長條底部與 15–30 長條頂部的正中間（y = 95），從 x = 0 畫到底軌末端（`bar_x + BAR_MAX`，x = 238）為止；「15 分鐘」從 x = 244（底軌末端後 6，跟筆數離長條的距離一樣）開始，`text-anchor="start"`、`dominant-baseline="central"`，跟虛線同高。字所在的那段高度沒有任何長條或筆數，所以筆數幾位數都不會撞；多出來的空白本身也把「不到 15 分鐘」與「15 分鐘以上」分成兩組，這是 `route-page` 的 Layover chart 需求要分隔線做的事。

14 這個值：2026-10-24 把它套在正式站 16111 的 SVG 上（只改瀏覽器裡的 DOM），在 340px 與 316px 寬各截圖看過，「75」與「15 分鐘」分得開。換算的間距：10–15 的筆數字底在 y 78.5，字的上緣約 95 − 6.5 = 88.5，相隔約 10 單位，大約是一般列距空白的一半。

這不推翻 `01-route-page-visual-refresh`「分佈圖改成一張 300 寬的 SVG，手機與桌機共用」：它列的五個常數與分隔線的字級都不變，只多一個常數，列距在分隔線那裡不再一樣。`spec/system/route_page_layout_spec.rb` 量的「分佈圖的組別標籤實際顯示不小於 14px」是字級 × 實際寬 ÷ viewBox 寬，`WIDTH` 不變，不受影響。

替代方案：

- 拿掉「15 分鐘」，只留虛線（虛線本來就夾在「10–15」與「15–30」之間，規格也沒要求字；否決：頁首重點數字是「停車端不到 15 分鐘」，虛線旁直接寫出來，第一次看的人不用自己對組別）。
- 字移到虛線下方（否決：換成跟 15–30 的筆數撞；正式站 16111 返程結束最多的就是 15–30）。
- 長條縮短、右邊留一欄給字（`BAR_MAX` 約降到 170，換算值；否決：每張圖的長條都變短，筆數到四位數又會撞回來）。
- 加寬 viewBox（否決：手機上組別標籤會小於 14px，`route_page_layout_spec.rb` 的檢查會失敗）。

### 說明文字的行寬保留 46em，併成一個有名字的寬度

**已被取代**：2026-10-24 使用者改成滿版，見下一條「說明文字拿掉 46em 的行寬上限，14 處一起」。以下是原本的決定，留著當紀錄，不要照做。

`app/frontend/stylesheets/application.css` 的 `@theme` 加 `--container-measure: 46em;`，Tailwind v4 的 `max-w-*` 會讀 `--container-*`（看過 `node_modules/tailwindcss` 的 dist：`max-w` 讀 `--max-width`、`--spacing`、`--container`），產生 `max-w-measure`。旁邊的註解寫理由：一行最多約 46 個中文字；桌機卡片內容約 1006px，滿版時一行約 59 字，換行時不容易找到下一行開頭。14 處 `max-w-[46em]` 全部換成 `max-w-measure`。宣告仍是 `max-width: 46em`，em 照各元素自己的字級算，所以每一處的寬度都不變（17px 的說明 782px，15px 的表下註記 690px）。

照 `01-route-page-visual-refresh`「頁面最寬 1152px，首頁、路線頁與 footer 同一組寬度」做 `.page-column` 的理由：同一串 class 散在幾個檔案裡沒有東西綁在一起，下次改寬度漏改一處就對不齊。這裡是 14 處同樣的情況。

名字用 measure（排版上「行長」的說法），不用 note（會跟 `--text-note` 字級混在一起），也不用 prose（容易跟 Tailwind 內建的 `max-w-prose` 搞混）。

替代方案：滿版（一行約 59 字，否決）；改成 52em 之類的中間值（右緣一樣對不到任何東西，否決）；14 處照舊（理由沒寫下來，改值時會漏，否決）。

### 說明文字拿掉 46em 的行寬上限，14 處一起

**Supersedes**: ui-touchups / 說明文字的行寬保留 46em，併成一個有名字的寬度

9 個元件裡 14 處 `max-w-[46em]` 全部拿掉，只拿掉這個 class，其他 class 不動。說明、粗體摘要、表下註記跟所在的卡片或欄位一樣寬：路線頁卡片內容在桌機最寬約 1006px，17px 的內文一行約 59 個中文字（換算值）；首頁 hero 的摘要跟下面的動畫圖一樣寬；折返點設施每一端的說明在左右兩欄裡，填滿自己那一欄。手機上卡片內容約 318px（換算值，`01-route-page-visual-refresh` 的數字），本來就碰不到 46em（17px 時 782px），看起來不變。拿掉上限之後沒有共用的寬度要命名，所以不新增 `--container-measure`，也不動 `application.css`。

2026-10-24 使用者看了畫面，問為什麼還是沒有滿版；聽完上一條的理由（一行太長，換行時不容易找到下一行開頭）之後，選了滿版、14 處一起。說明右邊那塊空白，在表格滿版的卡片裡像沒排完；行長變長是接受的代價。

`buffer-trade-cost-curve` 還沒開始（暫存、0/15），換休息試算那一塊的 3 處跟其他 11 處一起拿掉，不等它；它之後重做這一塊時，新的說明照滿版。它的 1.1 與 design 風險那條寫的「ui-touchups 的行寬排在這個 change 之後」因此過時，要不要更新那個 change 由使用者決定。

替代方案：保留 46em（使用者否決）；只拿掉來回一趟與週期這一區（各區說明會不一樣寬，否決）；換休息試算那 3 處等它改完再拿（中間會有一段時間一區例外，而它還沒開始，現在改不會撞到，否決）。

### 控制項的字不能選取，內容的字照舊

判準是「這段字是不是控制項的標籤」，不看它是 `<a>` 還是 `<button>`。控制項的標籤加 `select-none`；內容的字照舊可以選，也照舊會在複製時被帶上。

加的地方：

- 路線頁：區塊導覽的連結（`nav[data-section-nav] a`）；頁首範圍切換的連結（`nav[data-range] a`）；來回一趟與週期的切換（`[data-measure-switch] button`）、行駛時間的方向切換與載客剖面的時段、方向切換（`[data-direction-switch] button`、`[data-band-switch] button`）；換休息試算那一塊的控制項（現在只有沒有 JS 時才出現的送出按鈕 `[data-section=buffer-trade] button[type=submit]`）。`buffer-trade-cost-curve` 要重做這一塊：它的 3.1 到 3.4 加拉桿、篩選、曲線與一張沒有 JavaScript 時會送出的表單，4.1 讓拉桿在瀏覽器裡移動、有 JavaScript 時隱藏重算按鈕。所以這一塊等這五條完成再照同一個判準找控制項：按鈕與選項的文字加，拉桿本身、數字、`<summary>` 不加。
- 首頁：起點區塊連到路線頁的連結（`OriginStoryComponent` 的 `ROUTE_LINKS`）；hero 動畫的暫停按鈕（`[data-hero-pause]`）。
- 名稱列新增的「關於這個網站」，見下一條決定。

不加的地方：重點數字卡（整張卡是連結，但裡面的數字是會被引用、複製的內容）、首頁路線清單卡（路線名與最新資料日）、表格、日期連結、樣本少標籤、`<summary>` 收合列（站序、逐站表、公廁清單；字是那一塊的標題與說明）、footer、起點區塊出處裡的文章連結。

每個元素各自加 utility，照專案每個元素自己寫 class 的習慣；不在 base layer 對 `button` 寫全域規則，因為截圖裡的導覽 pill 是 `<a>`，全域的 `button` 規則剛好漏掉它。

替代方案：只加區塊導覽（否決：同一頁的範圍切換、切換按鈕是同一種東西，判準一樣）；只加路線頁（使用者 2026-10-24 選了首頁一起加）。

### 網站名稱列由 layout 輸出，每頁一條，放回首頁的連結與「關於這個網站」

**Supersedes**: 02-route-page-mobile-first / 網站名稱列由 layout 輸出，每頁一條，只放回首頁的連結

`SiteBarComponent` 仍由 layout 在 `<body>` 的第一個位置輸出 `<header data-site-bar>`，不帶 `data-section`，首頁的 body 裡站名仍只出現一次。名稱列放兩個連結：左邊是原本的 logo 連結回 `/`，右邊是「關於這個網站」，連到 `SiteBarComponent::ABOUT_URL`（https://kaochenlong.com/bus-turn-around）。內層 `div` 加 `flex items-center justify-between`，手機上兩個連結在同一行。

連結的樣子照範圍切換沒被選到的連結：`text-table font-medium text-slate-600 hover:text-slate-900`；點擊高度照專案手機上的下限 `inline-flex min-h-11 items-center`；focus 照 logo 連結的 `rounded-sm focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700`；加 `select-none`（照上一條的判準）。不用 pill：名稱列正下方就是區塊導覽那排 pill，再放一個會被看成那排的一部分。在原分頁開、不加圖示，跟起點區塊連到《未來城市》的連結一致（整個 app 沒有 `target`）。

文字用「關於這個網站」：文章交代的是整個網站為什麼做、怎麼做、看到什麼、做不到什麼，讀者想知道「這是誰做的、為什麼做」時會往右上角找這幾個字。「設計理念」只對得上其中幾段（不用模擬資料、n-gear 跟網站分開、寫末站不寫終點），讀者會期待介面怎麼設計的說明；「緣起」只涵蓋前半；文章標題「公車司機的 10 分鐘」放在名稱列看不出點了會到哪裡；只寫「關於」容易被讀成「關於作者」。

被取代的決定只加回首頁那一個連結，理由是「現在有回首頁的需要，所以只加這一個連結」。`02-route-page-mobile-first` 的非目標「網站名稱列上的選單：只放一個回首頁的連結……車牌查詢、回報表單、月報等有了再說」與 `home-page` 的非目標「共用的頁首導覽：各自等有東西再開 change，不留空殼」都是範圍上的限制，不是否決；現在有了文章，所以只加這一個連結，仍然不做選單。被取代的決定裡其餘內容（layout 輸出、`data-site-bar`、不帶 `data-section`、首頁 hero 拿掉站名）照舊，已經寫在這一條。

手機空間：logo 右邊約 218px（量到的），「關於這個網站」6 個中文字在 16px 約 96px（換算值），名稱列不會變高。實作後在 390px 與 1280px 寬都量到 77px（原本 83px）：內層 `div` 改成 flex 之後，logo 不再是一行字裡的 inline 元素，它底下原本約 6px 的行高空間不見了，logo 離上下緣各 14px（原本上 14px、下約 20px）。2026-10-24 使用者選了保留 77px，不補內距。

替代方案：只放在首頁起點區塊（否決：駕駛直接開路線頁，看不到）；放 footer（否決：不顯眼，而且那裡是授權條款要求逐字照抄的顯名聲明）；開新分頁並加 ↗（否決：全站第一個這樣的連結，等於另訂一條規則）。

### 詞彙表「路線頁」的定義改成人工載入、某一天與最近 7 天

`docs/spectra/LANGUAGE.md`「路線頁」的定義現在是「網站上每條路線一頁、每天更新的畫面，給司機與站長看昨天和最近一個月的樣子」。「每天更新」跟「衍生表」那條的「目前是手動執行，還沒有每晚排程」衝突，`home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」也明說不寫「每天更新」；「最近一個月」跟頁首範圍切換的「當天」「最近 7 天」不符。改成：

> 網站上每條路線一頁的畫面，給司機與站長看某一天與最近 7 天的樣子（頁首範圍切換的「當天」「最近 7 天」）。資料由人工載入：`bin/rails derived:load` 在筆電上算好，再用 `bin/push-derived` 推上正式站，所以至少晚一天，也不是每天自動更新。它不是定稿，所以不是健檢卡。

其他三行（在資料或程式碼裡、邊界、不要用）不動。

### 文案

tw 與 zh-TW 用同一份（照既有的 `<<: *tw`），en 另寫。

- 新增 `app/components/site_bar_component.yml`：`about` 在 tw 是「關於這個網站」，en 是「About this site」。站名仍讀 `t("site.name")`。
- 分佈圖分隔線的字不變：`divider: "%{minutes} 分鐘"`（en `"%{minutes} min"`）。en 的「15 min」比「15 分鐘」短，從 x = 244 開始也放得下。

## Implementation Contract

**行為（使用者看到的）**

- 路線頁每個方向的分佈圖：15 分鐘那裡比其他列之間多一段空白，虛線在空白正中間、畫到淺色底軌的右緣為止，「15 分鐘」接在虛線之後、跟虛線同高；不管哪一組最多，「15 分鐘」都不會跟任何筆數或長條重疊。
- 路線頁各區的說明、粗體摘要、表下註記，以及首頁 hero 的摘要，跟所在的卡片或欄位一樣寬，桌機上不再停在約 782px；手機上看起來不變。
- 路線頁與首頁的控制項（上面列的那些）的字不能用滑鼠選取；全選時不會反白、複製時不會帶上。重點數字、表格、路線清單照舊可以選。
- 每一頁（首頁、路線頁；不含 `public/404.html`）的名稱列右邊有「關於這個網站」，點了在原分頁開 https://kaochenlong.com/bus-turn-around。

**介面與資料形狀**

- `LayoverChartComponent::DIVIDER_GAP = 14`；`#row_y(index)` 對 `index` 大於等於 `bounds.index(DIVIDER_MINUTES)` 的列加 `DIVIDER_GAP`；`#height` 加 `DIVIDER_GAP`；`#divider_y` 是分隔線之前那一列的長條底部與之後那一列的長條頂部的中點；底軌末端是 `bar_x + BAR_MAX`。`<line data-divider="15">` 的 `x2` 是底軌末端；分隔線的字是 `<text data-divider-label>`，`x` 是底軌末端加 6，`y` 是 `divider_y`，`text-anchor="start"`、`dominant-baseline="central"`，class 照舊 `fill-slate-500 text-label-sm`。
- 元件模板裡沒有 `max-w-[46em]`，也不新增寬度 token。
- `SiteBarComponent::ABOUT_URL = "https://kaochenlong.com/bus-turn-around"`；`site_bar_component.yml` 的 `about`。

**失敗的樣子**

- 漏拿一處時，那一區的說明會比其他區窄，而且不會有任何測試紅；所以驗收用 grep 確認一處都不剩。
- 文章網址日後如果改了，連結會壞；網址只在 `ABOUT_URL` 一處。

**驗收**

- 測試範圍：專案 `.spectra.yaml` 開了 `tdd: true`，照它的測試範圍規則，寫死的 class、文字、版面不寫斷言（沒有分支選它、沒有輸入填它、沒有計算產生它，斷言只會在有人改那個字時紅），改在瀏覽器驗收；算出來的位置與分支照常先寫會失敗的測試。下面各條照這個分。
- 分佈圖：`spec/components/layover_chart_component_spec.rb` 新增的例子斷言分隔線的字整個（中心上下各 6.5 單位，`text-label-sm` 是 13 單位高）落在 10–15 長條底部與 15–30 長條頂部之間，在實作前紅、實作後綠；分隔線之後的列往下移是算出來的，所以寫測試。虛線畫到底軌末端、字的 x、`text-anchor` 與 `dominant-baseline` 是寫死的版面，不寫斷言，用 `bin/dev` 在 1280 寬（SVG 340px）與手機 390 寬（CDP 模擬）截圖，並量實際渲染的外框確認字與每一個筆數都不重疊（2026-10-24 量過：字在 x 244–286、y 87–103，兩個方向都沒有重疊）。既有的「15 分鐘處有一條分隔線」與 `bundle exec rspec spec/system/route_page_layout_spec.rb` 照舊綠。
- 行寬：拿掉 `max-w-[46em]` 是寫死的 class，不寫斷言。`grep -rn "max-w-\[46em\]" app` 沒有結果；`bin/dev` 在 1280 寬量來回一趟與週期的說明（`[data-section=cycles] [data-stops]`）`getComputedStyle(...).maxWidth` 是 `none`、寬度等於卡片內容寬，再看路線頁每一區與首頁 hero 的說明都跟卡片或欄位一樣寬；手機 390 寬看起來跟改之前一樣。
- 選取：`select-none` 是寫死的 class，不寫斷言。在 `bin/dev` 驗收：手機 390 寬（CDP 模擬）用 `getComputedStyle(...).userSelect` 量上面列的控制項都是 `none`，重點數字卡（`[data-section=summary] a`）、首頁 hero 的標題與說明、路線清單卡都不是 `none`；1280 寬全選時，控制項的字不在選取範圍裡（在控制項的字後面接一個記號字串，看 `window.getSelection().toString()` 有沒有它）。
- 名稱列：Site name bar on every page 兩個情境裡原本就有的部分（恰好一條名稱列、在 `main` 前面、第一個連結回 `/` 且文字是站名、列與裡面沒有 `data-section`）由 `spec/requests/site_layout_spec.rb` 既有的例子守住；新連結的文字、網址、沒有 `target`、恰好兩個連結是寫死的內容，不寫斷言，在 `bin/dev` 的首頁與路線頁量（2026-10-24 量過：兩個連結、文字「關於這個網站」、`href` 是文章網址、`target` 是空的）；`spec/system/rest_command_spec.rb` 原本的 `find("[data-site-bar] a")` 在名稱列有兩個連結後會選到兩個（實測報 `Capybara::Ambiguous`），改選 `[data-site-bar] a[href='/']` 後照舊綠；`spec/requests/pages_spec.rb` 照舊綠；`spec/system/route_page_mobile_spec.rb` 的第一個畫面放得下重點數字照舊綠；手機 390 寬量 `[data-site-bar]` 高度是 77px（見名稱列那條決定）。
- 全部：對新增或修改的 `.rb` 跑 `bin/rubocop`；`bin/rails parallel:spec` 全綠。

**範圍**

- 範圍內：上面列的元件、`site_bar_component.yml`、列出的測試、`site-layout` 的 delta spec、`docs/spectra/LANGUAGE.md`「路線頁」的定義。
- 範圍外：指標與衍生表、`app/models/`、`analysis/`、路由與控制器、`public/404.html`、其他元件的選取行為、介紹文章本身。
- 順序（這個 change 裡）：說明文字行寬那一項（任務 3.1）動到的模板，跟分佈圖、選取兩項有重疊（`layover_chart_component.html.erb`、`cycle_table_component.html.erb`、`run_time_table_component.html.erb`、`load_chart_component.html.erb`、`home_hero_component.html.erb`），排在 1.1、2.1、2.2 之後；換休息試算那一塊的 `select-none`（任務 2.3）也改 `buffer_trade_component.html.erb`，排在 3.1 之後。
- 順序（跨 change）：建立這個 change 之後，`spectra list` 陸續出現三個 change（2026-10-24 看到，三個都已有任務、暫存中），重疊的檔與處理方式如下。
  - `buffer-trade-cost-curve`（15 個任務）：它的 3.1 到 3.4 重做 `app/components/buffer_trade_component.html.erb`，4.1 讓拉桿在瀏覽器裡移動、有 JavaScript 時隱藏重算按鈕。換休息試算那一塊的 `select-none`（任務 2.3）等這五條完成或它 archive 再做。說明文字行寬（任務 3.1）原本也排在它之後；2026-10-24 改成滿版時它還沒開始，改成先做（見「說明文字拿掉 46em 的行寬上限，14 處一起」），它的 1.1 與 design 風險那條因此過時。
  - `01-pass-through-wording`（8 個任務）：proposal 的影響清單列了 `spec/components/layover_chart_component_spec.rb`，但它的 tasks.md 只拿這個檔跑驗收、不改它（2026-10-24 apply 時看過），所以分佈圖那一項（任務 1.1）不用等。它也改 `docs/spectra/LANGUAGE.md`，改的是兩端性質的用詞，跟詞彙表那一項（任務 5.1）改的「路線頁」條目不同。
  - `02-end-nature-survey`（15 個任務）：它的 proposal 與 tasks 沒有提到這個 change 剩下要改的檔（2026-10-24 用檔名比對過）。
  - 名稱列那一項（任務 4.1）、首頁與路線頁其他控制項的 `select-none`（任務 2.1、2.2）不碰這些檔，不用等。

## Risks / Trade-offs

- [分佈圖變高 14 單位，列距不再全部一樣] → 這是刻意的分組；由瀏覽器檢查確認看起來是一個分隔，不是排版跑掉。
- [10–15 最多時，「15 分鐘」就在筆數正下方約 10 單位（換算值）] → 2026-10-24 在正式站的 DOM 上於 340px 與 316px 寬看過分得開；實作後在 `bin/dev` 再看一次，若覺得太近，只調 `DIVIDER_GAP`。
- [`select-none` 讓劃字翻譯、劃字朗讀這類工具讀不到那幾個字] → 只用在控制項的標籤上，內容不受影響；螢幕報讀不受 `user-select` 影響。
- [Safari 沒有測：`select-none` 與分隔線的字的垂直位置] → Tailwind 已輸出 `-webkit-user-select`，上線後在 Safari 實際試一次全選。`dominant-baseline="central"` 在 Safari 的 `<text>` 上過去表現不一致；若字沒有對齊虛線，改成不用 `dominant-baseline`、`y` 寫 `divider_y + 4.5`（13px 字的基線位移，換算值），元件測試的斷言不受影響。
- [滿版後桌機一行約 59 個中文字（換算值），比原本長] → 使用者 2026-10-24 聽過這個理由後選了滿版；首頁 hero 的摘要會變成一行多一點，實作後在 1280 寬看一次。
- [文章內容跟網站對不上（文中寫三條路線，正式站四條）] → 文章是使用者的，要不要改由使用者決定，不在這個 change。
