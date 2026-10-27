## Context

- 名稱列由 layout 在 `<body>` 的第一個位置輸出（`SiteBarComponent`，`<header data-site-bar>`），每頁一條。現在的排法來自 `01-day-dispatch-model`：標誌、班表、當天調度、關於這個網站排成一串，接在標誌旁邊靠左；640px 以下「關於這個網站」只顯示「關於」，「這個網站」是 `max-sm:sr-only`，連結文字照舊是完整的。
- 名稱列的連結共用模板裡的 `text_link`：`relative inline-flex min-h-11 items-center rounded-sm text-table font-medium text-slate-600 select-none hover:text-slate-900 aria-[current=page]:text-slate-900`，focus 是 `focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700`。
- 現有尺寸（`01-day-dispatch-model` 的 Design Source）：名稱列白底、下框 1px `#e2e8f0`；內距上下 14px、左右 16px（640px 以下）與 32px；標誌高 48px、寬 140px；標誌與選單間距 16px（640px 以下）與 28px；連結間距 20px（640px 以下）與 28px；連結最小高度 44px、16px、500、`#475569`，目前這一頁 `#0f172a`。
- 手機上的空間（`01-day-dispatch-model` 量到的）：390 寬時標誌右邊剩約 202px；360 寬時三個連結後面只剩約 4px。
- repo https://github.com/kaochenlong/bus-turn-around 是公開的（2026-10-27 用 `gh repo view` 查到 PUBLIC），裡面有網站與算指標的 SQL（`analysis/`）；n-gear 是另一個 repo。
- 專案現有的圖示：班表頁每列的刪除鈕是 inline SVG（`TimetableSheetComponent`，`size-5`，線條畫的 `fill-none stroke-current`），按鈕樣式是 `ICON_BUTTON_CLASSES`（36px 見方，hover 時有 `bg-slate-100` 淺底色）。名稱列裡的標誌連結是 `aria-hidden` 的圖片加 `sr-only` 的站名。
- 2026-10-27 使用者提出三件事，見 proposal。

當天調度頁（同一天併進來的兩件）：

- 當天調度頁（`/routes/<Id>/dispatch`）由 `app/frontend/timetable/day_view.js` 的 `render()` 畫：讀一次 `now()`（`day_page.js` 的頁面時鐘）換成當天的分鐘數，畫時間軸（`day_timeline_view.js` 的 `draw`，裡面的 `drawNow` 放現在的標記與線）、發車表（`departureRows`，狀態與現在分隔線）、停在末站的車（`renderStanding`），以及頁首數字、選取的那一趟、記下回到時刻的表單與修改清單。`render()` 只在顯示當天（`show`）與調度員的每個操作時跑，頁面上沒有計時器。
- 系統測試用 `spec/system/timetable_day_spec.rb` 的 `set_clock` 換掉 Alpine 元件的 `now`，再按一下目前那一端的按鈕逼它重畫。
- 發車表每一列有派車選單與發車時刻欄；改動之後 `commit` 把焦點放回同一列的同一格，時間軸有 `focusTrip`。改不成時那一列下面多一行說明（`this.rejection`），下一次 `render()` 清掉。
- 時間軸一趟的樣子（`02-day-dispatch-timeline` 的 Design Source）：48px 的條距上緣 10px、高 24px，28px 的條距上緣 4px、高 20px；圓角 3px、左內距 3px；方向 0 `#334155` 白字、方向 1 `#cbd5e1` 底 `#0f172a` 字；段寬不到 26px 不寫發車時刻（`day_timeline_view.js` 的 `DEPARTURE_LABEL_PX`）；按鈕 `overflow-hidden`。換過車的框比段大一圈 3px、圓角 5px；選取的框大一圈 6px、圓角 7px。

## Design Source

- 來源：Claude Design 畫布「當天調度工具版面」最下面的「名稱列分兩組」，2026-10-27 畫（task 1.1），同一天使用者選了方案 A。照的畫板是 `SiteBarHomeA.dc.html`、`SiteBarRouteA.dc.html`、`SiteBarPhoneRoute.dc.html`、`SiteBarPhoneHome.dc.html`；方案 B（`SiteBarHomeB.dc.html`、`SiteBarRouteB.dc.html`，間距 12px）沒選。
- 快取：`.spectra/design-cache/site-bar-github-about/` 的 `site-bar-home-a.dc.html`、`site-bar-route-a.dc.html`、`site-bar-phone-route.dc.html`、`site-bar-phone-home.dc.html`。

| 部位 | 數值 |
| --- | --- |
| 名稱列 | 照舊：白底、下框 1px `#e2e8f0`；內距上下 14px、左右 16px（640px 以下）與 32px；內容最寬 1152px |
| 標誌 | 照舊：高 48px、寬 140px |
| 左組 | 照舊：標誌接班表、當天調度（只在路線頁、班表頁、當天調度頁）；標誌與班表間距 16px（640px 以下）與 28px，班表與當天調度 20px 與 28px |
| 右組 | GitHub、關於，推到名稱列右端；首頁就是標誌在左、右組在右 |
| GitHub 圖示 | 20×20px，`@primer/octicons@19.42.0` 的 `mark-github-24`，填色 `#475569`，hover `#0f172a`；640px 以下不顯示 |
| GitHub 與「關於」 | 圖示右緣到「關於」的字 28px，跟其他連結之間一樣（方案 A） |
| 連結的字 | 照舊：16px、500、`#475569`，最小高度 44px；路線頁上班表、當天調度都不是目前這一頁 |
| 390 寬 | 沒有 GitHub 圖示；路線頁「當天調度」與「關於」之間約 54px（換算值：358 − 140 − 16 − 32 − 20 − 64 − 32，中文字一個 16px）；首頁標誌在左、「關於」在右 |

畫板上的元素：

- 標誌、班表、當天調度：照現況畫，這次不改。
- 「關於」推到右端、每種寬度只顯示兩個字：這次做（task 2.1）。
- GitHub 圖示：這次做（task 2.2）。
- 名稱列下面的頁首（路線頁的「251區」與「深坑－公館」、首頁的標題與摘要）：只是讓畫板看得出是哪一頁，這次不動；路線頁真的頁首還有路線 Id、範圍切換與涵蓋的日子，畫板省略。

畫布與這次實作不同的地方：

- 畫板上的 GitHub 連結就是 20px 寬的圖示；程式裡連結左右各留 2px（`px-0.5`，寬 24px，理由見「GitHub 圖示連到 repo，640px 以下不顯示」的點擊範圍），所以右組的間距寫 26px（`gap-6.5`），畫面上圖示到字照樣是 28px。右組在 640px 以下只有「關於」，這個間距只在 640px 以上用得到。
- 畫板上的 GitHub 連結用 `aria-label`；程式照決定用 `sr-only` 的 span。
- 畫板上兩組是名稱列那一排裡相鄰的兩塊，640px 以下中間最少只有 16px；程式裡兩組之間最少 20px（640px 以下）與 28px，照「名稱列分兩組：路線的連結接在標誌旁邊，GitHub 與「關於」靠右」。390 寬時中間本來就有約 54px，看起來一樣。
- 畫板是靜態的，沒有畫 focus 的外框；程式照 `text_link` 的 focus 樣式。

時間軸的公車（2026-10-27 併進來）：

- 來源：Claude Design 畫布「當天調度時間軸：鳥瞰公車」，2026-10-27 畫，同一天使用者選了方案 A，問過朝向之後照車頭朝右。照的畫板是 `BusA.dc.html`（1280）與 `BusAPhone.dc.html`（390）；現況（`Main.dc.html`、`CurrentPhone.dc.html`）與方案 B（`BusB.dc.html`、`BusBPhone.dc.html`）沒選。畫板上的一天由網站的鋪排程式與 `day.js` 算出：251區 平日 10-19 到 10-22、p85、休息 15 分，11 台車、109 趟，現在 17:30。為了讓換車框、晚回與改過的時刻出現在畫板上，套了三個修改：7 號車 16:44 到福安居記成 16:53、17:40 那一班從 8 號車給 2 號車、3 號車 18:00 改成 18:04。
- 快取：`.spectra/design-cache/site-bar-github-about/` 的 `timeline-bus-a.dc.html`、`timeline-bus-a-phone.dc.html`。

| 部位 | 數值 |
| --- | --- |
| 車身 | 位置與大小照舊（48px 的條距上緣 10px、高 24px；28px 的條距上緣 4px、高 20px）；圓角車尾 4px、車頭 8px（`4px 8px 8px 4px`）；陰影 `0 1px 1px rgba(15, 23, 42, 0.3)`；方向 0 `#334155`、方向 1 `#cbd5e1` |
| 擋風玻璃 | 車頭那一端：離右緣 2px、上下各留 3px、寬 5px、圓角 `2px 4px 4px 2px`；方向 0 `#94a3b8`、方向 1 `#64748b` |
| 後窗 | 車尾那一端：離左緣 2px、上下各留 6px、寬 2px、圓角 1px；方向 0 `#64748b`、方向 1 `#94a3b8` |
| 後照鏡 | 上下各一個，離右緣 8px、寬 3px、高 2px，伸出車身 2px；方向 0 `#334155`、方向 1 `#94a3b8` |
| 發車時刻 | 從左緣 6px 開始；11px、500、Barlow Semi Condensed、行高等於車身高；方向 0 白字、方向 1 `#0f172a`；段寬不到 36px 不寫（原本 26px）；改過的時刻加底線照舊 |
| 換過車、拖拉時會換走的班 | 框 2px `#0f766e`（會換走的是虛線），比車身大一圈 3px，圓角 `6px 10px 10px 6px` |
| 選取的那一趟 | 框 2px `#0f172a`，比車身大一圈 6px，圓角 `10px 14px 14px 10px`（畫布上沒畫，照車身圓角各加 6px 推的） |
| 圖例兩個方向的色塊 | 22×12px 的小公車：圓角 `2px 4px 4px 2px`；擋風玻璃離右緣 1px、上下各留 2px、寬 3px、圓角 `1px 2px 2px 1px`；後窗離左緣 1px、上下各留 3px、寬 1px；顏色照兩個方向 |

畫板上的元素：

- 每一趟的公車、換過車的框、圖例兩個方向的色塊：這次做（task 5.1）。
- 停留的數字、「停 N 分」、記下的晚回（斜線與「晚 N 分」）、改過時刻的底線、現在的標記與線、刻度與小時格線、車號與換車的註記、四小時休息、圖例其他項目、上方的說明：照現有的，這次不改。
- 畫板上的三個修改（7 號車晚回、17:40 給 2 號車、3 號車改成 18:04）：只是讓那些記號出現在畫板上，不是這次要做的事。
- 手機畫板打開時捲到的位置（現在在看得到的時間軸 40% 處）：照現有的 `NOW_AT`，不改。

畫布與這次實作不同的地方：

- 畫布沒有畫 28px 的條（12 台以上）：車窗與後照鏡照上下距離畫，擋風玻璃因此高 14px、後窗 8px；28px 的條上「停 N 分」與「晚 N 分」照舊是段那一行的小標籤。
- 畫布沒有畫選取的那一趟與拖拉中的樣子：選取的框圓角照上表；拖著的那一段整台公車一起浮起來、原位的那一段變淡，照舊。
- 畫板上一趟是一個 button 裡放幾個 span，顏色寫在每個 span 上；實作在 `DayTimelineComponent` 的趟次 template 裡照方向（`data-go-back`）上色。
- 畫板 A 的圖例裡「換過車」的色塊也跟著公車改了圓角（`3px 6px 6px 3px`）；這份 design 的「畫板上的元素」把它算在「圖例其他項目照現有的」，實作照 design 留著原本的 3px 圓角。要跟畫板一樣的話再改。
- 畫板上車窗與後照鏡是寫在 button 裡的 span；實作把它們的 class 放在 `DayTimelineComponent::BUS_PARTS`，用 `bus_parts`（`safe_join`）接在一起、中間不留空白，發車時刻寫在 button 裡的 `[data-slot=label]`：時間軸照 `textContent` 讀趟次的字，template 縮排的空白會混進去。

## Goals / Non-Goals

**Goals:**

- 名稱列分成兩組：這條路線的工具接在標誌旁邊，跟網站本身有關的（GitHub、關於）在右端。
- 640px 以上的每一頁都有連到 repo 的 GitHub 圖示。
- 文章連結看得到的是「關於」，讀螢幕軟體聽到的是「關於這個網站」。
- 名稱列的 GitHub 與「關於」另開新分頁，讀螢幕軟體聽得到。
- 調度員不用動手，當天調度跟著時鐘走：每到整分鐘，跟現在有關的部分照新的時刻畫。
- 時間軸的每一趟看起來是一台從上面看的公車。

**Non-Goals:**

- 名稱列做選單、加其他連結；加看得到的 ↗。
- 名稱列以外對外的連結（起點區塊連到《未來城市》、頁尾的出處）改成另開新分頁。
- 640px 以下顯示 GitHub 連結（見「GitHub 圖示連到 repo，640px 以下不顯示」）。
- 改名稱列的高度、標誌的大小、區塊導覽。
- 秒級的更新與倒數；今天的計畫跟時鐘走。
- 公車畫車號或輪子；用車頭朝向分去程與返程。

## Decisions

### 先在畫布畫名稱列，選定再寫程式

名稱列換了排法，右邊多一組。照使用者的規則，版面改動先在 Claude Design 畫布上畫給使用者選，選定才寫程式；`02-day-dispatch-timeline` 與 `03-day-dispatch-record` 也是第一個 task 先畫布。

- 畫板：1280 寬的首頁（標誌、GitHub、關於）與路線頁（標誌、班表、當天調度、GitHub、關於）；390 寬的路線頁與首頁（沒有 GitHub）。用網站的標誌圖 `turnaround-logo.webp`，其他數值照 Context 列的現有尺寸。
- 方案只差 GitHub 圖示與「關於」的間距：A 跟其他連結一樣（640px 以上 28px）；B 是 12px，兩個看起來是一組。圖示都是 20px。
- 選定之後畫板快取到 `.spectra/design-cache/site-bar-github-about/`，用 `/spectra-ingest site-bar-github-about` 把選定的數值寫進這份 design 的 Design Source。

2026-10-27 使用者選了方案 A，數值寫在 Design Source，畫板快取在 `.spectra/design-cache/site-bar-github-about/`。

替代方案：不畫，照現有的連結間距直接寫。不採：使用者的規則是版面改動先畫；`01-day-dispatch-model` 改名稱列時也在畫布比過三種。

### 名稱列分兩組：路線的連結接在標誌旁邊，GitHub 與「關於」靠右

**Supersedes**: 01-day-dispatch-model / 名稱列加「當天調度」入口，選單接在標誌旁邊靠左

2026-10-27 使用者要「關於」放到名稱列右側。被取代的決定把選單接在標誌旁邊靠左、每一頁都一樣，記下的理由只有一個：使用者在畫布 C 選了那個樣子，沒有其他限制。分成兩組之後，「關於」不再排在班表、當天調度後面被看成第三個工具；它跟 GitHub 都是離開網站、講網站本身的連結。

- 左組是標誌，路線頁、班表頁與當天調度頁再接班表、當天調度。右組是 GitHub、關於，推到名稱列右端。首頁只有標誌與右組。
- 兩組之間至少保留現在的連結間距（640px 以下 20px、以上 28px），手機上的空間跟現在一樣。
- 640px 以下：路線頁 360 寬時連結後面只剩約 4px（量到的），右組只剩「關於」，推到右端看起來跟現在幾乎一樣；390 寬時多出來的約 34px（換算值）落在當天調度與關於之間。
- 被取代的決定裡其餘內容照舊，寫在這一條：班表後面是當天調度，連到 `/routes/<Id>/dispatch`，三頁都是普通連結；目前這一頁由伺服器標（`SiteBarComponent` 收 `current:`，layout 傳 `@site_bar_current`），班表頁標班表、當天調度頁標當天調度，字色跟著 `aria-current`。手機上換到第二列照舊否決（每一頁的名稱列從 76px 變 124px）；手機上藏起文章連結照舊否決（規格要每一頁都有文章連結）。被取代的決定裡「640px 以下只顯示『關於』」改由下一條決定的「每種寬度」取代。

替代方案：整串連結都推到右邊。不採：使用者只說「關於」；班表與當天調度是這條路線的工具，接在標誌旁邊的理由（使用者選的畫布 C）對它們照舊成立。

### 文章連結每種寬度都只顯示「關於」，讀螢幕軟體照舊念「關於這個網站」

**Supersedes**: ui-touchups / 網站名稱列由 layout 輸出，每頁一條，放回首頁的連結與「關於這個網站」

2026-10-27 使用者要「關於這個網站」改成「關於」。被取代的決定不用「關於」的理由是「只寫『關於』容易被讀成『關於作者』」；討論時把這個理由交給使用者，使用者照樣要改。放到右上角之後，位置本身就在說這是網站的介紹；旁邊的 GitHub 圖示連到作者帳號底下的 repo，也可能讓人更覺得在講作者。兩邊都說得通，是使用者的判斷。

- 看得到的字每種寬度都是「關於」（en：About）；「這個網站」（en：" this site"）每種寬度都是 `sr-only`，連結文字照舊是「關於這個網站」。做法跟現在 640px 以下一樣，從 `max-sm:sr-only` 改成 `sr-only`；`.yml` 的 `about_lead`、`about_rest` 不變，`text_link` 的 `relative` 照舊（sr-only 是絕對定位，以連結為準）。
- 讀螢幕軟體照舊念完整的字：看得到畫面的人有位置可以判斷，用讀螢幕軟體逐一跳連結的人聽不到位置，「關於作者」的顧慮對他們原封不動。
- 名稱列的高度不變：圖示 20px、連結最小 44px，都比標誌的 48px 矮。
- 被取代的決定裡其餘內容照舊，寫在這一條：layout 在 `<body>` 的第一個位置輸出 `<header data-site-bar>`，每頁一條，不帶 `data-section`，首頁的 body 裡站名只出現一次；標誌連結回 `/`；文章連結連到 `SiteBarComponent::ABOUT_URL`（https://kaochenlong.com/bus-turn-around）；連結的樣子是 `text-table font-medium text-slate-600 hover:text-slate-900`、`inline-flex min-h-11 items-center`、跟標誌連結一樣的 focus 樣式、`select-none`；不用 pill，因為名稱列正下方就是區塊導覽那排 pill；不加 ↗。原本的「在原分頁開」改成另開新分頁，見「GitHub 與「關於」另開新分頁，讀螢幕軟體聽得到」。當時否決的「只放在首頁起點區塊」「放 footer」與「設計理念」「緣起」「公車司機的 10 分鐘」照舊否決；「開新分頁並加 ↗」這次只採用開新分頁的那一半。被取代的決定裡「右邊是『關於這個網站』、內層 `div` 加 `justify-between`」的排法，改由「名稱列分兩組：路線的連結接在標誌旁邊，GitHub 與「關於」靠右」管。

替代方案：連讀螢幕軟體也只念「關於」，`.yml` 收回成一個 `about`，拿掉那個 span。不採：程式比較單純，但「關於作者」的顧慮對讀螢幕軟體的使用者沒有處理；兩段的寫法現在手機上已經在用，不用多寫東西。

### GitHub 圖示連到 repo，640px 以下不顯示

- 網址：`SiteBarComponent::REPOSITORY_URL`（https://github.com/kaochenlong/bus-turn-around），跟 `ABOUT_URL` 放在一起。叫 REPOSITORY 不叫 SOURCE：這個專案說「來源」指的是資料來源（`docs/data-sources.md`）。
- 圖示：GitHub 官方的 mark，取自 `@primer/octicons@19.42.0` 的 `build/svg/mark-github-24.svg`（MIT 授權；2026-10-27 從 https://unpkg.com/@primer/octicons@19.42.0/build/svg/mark-github-24.svg 取得，`viewBox="0 0 24 24"`、一個 path），path 原樣照抄，不改形狀。寫成 inline SVG，`aria-hidden="true"`、`size-5`（20px，跟刪除鈕一樣）、`fill-current`：刪除鈕是線條，這個是填色的形狀。
- 樣子：用名稱列的 `text_link`，字色、hover、focus 跟其他連結一樣（`#475569`，hover `#0f172a`，focus 是 teal-700 的外框線）。不用 `ICON_BUTTON_CLASSES`：它 hover 時有 `bg-slate-100` 淺底色，名稱列不用 pill（理由見上一條）。
- 點擊範圍：高跟其他連結一樣 44px（`min-h-11`），寬至少 24px（圖示 20px，左右各留 2px），因為 640px 以上的平板會用手指點，24px 是 WCAG 2.5.8 的下限。左右各 2px（`px-0.5`）算在跟「關於」的間距裡：右組的間距寫 26px（`gap-6.5`），畫面上圖示到字是畫布選定的 28px（見 Design Source）。
- 讀螢幕軟體念的字：跟標誌連結一樣，圖示 `aria-hidden`，連結裡放 `<span class="sr-only">`，字從 `.yml` 的 `repository` 讀，tw 與 en 都是「GitHub」。不用 `aria-label`：同一個元件的標誌連結就是 sr-only 的寫法，`spec/requests/site_layout_spec.rb` 的 `bar_links` 讀的也是連結文字，用 span 才讀得到「GitHub」。
- 另開新分頁，見「GitHub 與「關於」另開新分頁，讀螢幕軟體聽得到」。GitHub 圖示是這個連結本身，不是 ↗ 那種外部連結的記號。
- 名稱列「不加其他連結」的幾條非目標都是範圍上的限制，不是否決：`ui-touchups`「名稱列不做選單；車牌查詢、回報表單、月報等連結有了再說。」、`02-route-page-mobile-first`「網站名稱列上的其他連結。」、`timetable-draft`「首頁的名稱列加連結、名稱列做選單。」。`ui-touchups` 加文章連結時也是這樣處理的；repo 是公開的，條件成立。
- 640px 以下不顯示（`max-sm:hidden`），每一頁都一樣。390 寬時標誌右邊剩約 202px（量到的），三個連結約用掉 168px（從 360 寬量到的剩約 4px 換回來），剩約 34px；圖示 20px 加上跟「關於」的間距（方案 A 20px、方案 B 12px）要 32 到 40px，390 寬勉強放得下或超出約 6px，360 寬超出 28 到 36px（都是換算值）。不管畫布選哪個方案，360 寬都放不下。要確認換算，可以在 360 寬的路線頁把圖示放進去量名稱列的寬度；超出的量是剩下 4px 的好幾倍，這個決定不靠這幾個 px 的精確值。手機上用這個網站的主要是駕駛與調度員，不是來看原始碼的人。當時否決「手機上藏起文章連結」，是因為規格要每一頁都有文章連結；repo 的連結沒有這條要求。

替代方案：

- 手機上縮小標誌與間距硬塞。不採：標誌 48px 高與名稱列的高度是量過、使用者選過的；360 寬不縮標誌還是放不下。
- 只在首頁的手機畫面顯示（首頁沒有班表與當天調度，放得下）。不採：規則變成要看哪一頁，每一頁的名稱列不再一樣。
- 手機上換到第二列。不採：`01-day-dispatch-model` 否決過，每一頁的名稱列從 76px 變 124px。
- 用 `aria-label` 給圖示連結名字。不採，理由在上面。

### 測試：連結清單寫在 request spec，手機上不顯示寫在系統測試，排法由使用者看

- `spec/requests/site_layout_spec.rb`：首頁、路線頁、班表頁、當天調度頁四個例子都用 `eq` 比對名稱列完整的連結清單，改成三個與五個連結；GitHub 連結的文字是 sr-only 的「GitHub」，文章連結的文字照舊是 `about_lead` 加 `about_rest`。對應規格 Scenario「Bar on the home page」「Bar on a route page」「Bar on a timetable page」「Bar on a day dispatch page」。
- `spec/system/route_page_mobile_spec.rb`：加一個例子，用這個檔案現有的 `on_phone`、`on_wide_screen` 與 `displayed_count`，GitHub 連結在 390 寬看得到的有 0 個，在 1400 寬有 1 個。對應 Scenario「Repository link on a phone」。不讀 computed `display` 的值：連結是 flex 容器裡的項目，`inline-flex` 會被算成 `flex`（2.2 實作時跑出來的），規格要的只是顯示與否。顯示與否是 CSS 決定的，request spec 看不到；這個檔案本來就是量「CSS 決定顯示什麼」的地方。
- 不寫斷言：右組在右端、文章連結看得到的只有「關於」、圖示的大小與顏色、兩組與兩個連結之間的間距。看得到的只有「關於」量不出來：request spec 讀的連結文字包含 sr-only 的字；Tailwind 4.3.3 的 `sr-only` 是 `position: absolute`、1px、`clip-path: inset(50%)`，不改 `display`，系統測試用 `display` 也分不出來。這跟 `01-day-dispatch-model` 處理「選單靠左、640px 以下只顯示『關於』」一樣，是畫面上的排法，由使用者自己在畫面上確認，tasks 不排截圖。
- 另開新分頁的 `target`、`rel`、`aria-describedby` 與「另開新分頁」的字是寫死的屬性與文案，不寫斷言（之前的「沒有 `target`」也沒寫）；`spec/requests/site_layout_spec.rb` 比對的網址、連結文字與順序不變，照樣要綠。
- 不用改、照樣要綠的：`spec/requests/site_layout_spec.rb` 裡「body 第一個元素是唯一一條網站名稱列」那個例子（只看第一個連結）；`spec/requests/pages_spec.rb`（站名在 body 裡只出現一次、名稱列裡有站名）；用 `[data-site-bar] a[href='/']`、`[data-timetable-link]`、`[data-day-dispatch-link]` 找連結的系統測試（`buffer_trade_spec`、`rest_command_spec`、`timetable_edit_spec`、`timetable_day_spec`）；列印時整條名稱列不顯示的 `timetable_print_spec` 與 `timetable_day_record_spec`。

### 當天調度每到整分鐘照現在重畫，只重畫跟現在有關的三塊

2026-10-27 使用者回報：19:37 時標記還寫「現在 19:28」，拖過一趟才更新。原因是 `render()` 每次重畫讀一次 `now()`，但只在顯示當天與調度員操作時跑，頁面上沒有計時器；系統測試的 `set_clock` 也是換了時鐘之後按一下目前那一端，逼它重畫。跟現在有關的三塊因此都停在上一次操作的時刻：時間軸的標記與線、發車表的狀態與現在分隔線、停在末站的車與站了幾分鐘。`01-day-dispatch-model`「「現在」用瀏覽器的台北時間，跨午夜算成營運日的分鐘」照舊成立，這條只補上什麼時候照它重畫。

- 什麼時候畫：每到瀏覽器時鐘的整分鐘，因為畫面上的時刻只寫到分鐘。`app/frontend/timetable/minute_clock.js` 照 `now()` 算到下一個整分鐘，排一次 `setTimeout`，到了再照 `now()` 重排，所以不會越跑越偏，系統測試換掉的時鐘也照用。分頁切回來（`visibilitychange` 變成看得到）時馬上畫一次並重排，因為背景分頁的計時器會被瀏覽器放慢。只在顯示當天時跑；顯示今天的計畫時、離開頁面（Alpine 的 `destroy()`）時停掉。
- 畫哪些：
  - 時間軸只移動現在的標記與線、改圖例的「現在 HH:MM」（`timelineView` 新增 `moveNow(minutes)`），不重畫條與趟次，所以拖拉中、選取或焦點在某一趟都不受影響。
  - 停在末站的車照新的現在畫：只有文字，沒有可以操作的東西。
  - 發車表：狀態只在「現在」走過某一班的發車時刻時才會改變（已發車看發車早於現在，下一班看第一個不早於現在的，車還沒回來不看時間），分隔線的位置也一樣。所以每分鐘只改分隔線上的「現在 HH:MM」；新的現在走過了這一端某一班的發車時刻，才照新的現在重畫列與分隔線，保留捲動位置。
  - 跟上次畫的是同一分鐘就什麼都不動：`render()` 也記下它畫的是哪一分鐘，所以系統測試用 `set_clock` 固定時鐘時，計時器到了也不動。
- 不打斷：發車表的每一列有派車選單與發車時刻欄，重畫會把正在選的選單收起來、把打到一半的時刻清掉。所以焦點在發車表的捲動框裡時，整張發車表（連分隔線上的字）先不動，焦點離開捲動框時補畫；發車表下面正顯示改不成的說明時也不畫，免得說明被清掉。這時時間軸的標記照樣走，調度員看得到時間。
- 頁首的四個數字、修改清單、記下回到時刻的表單、選取的那一趟的動作不看現在，時鐘不碰。

替代方案：

- 每分鐘叫一次整個 `render()`。不採：會重畫時間軸的條與發車表，拖拉中的那一趟、打到一半的時刻、打開的選單都會被打斷，改不成的說明也會被清掉。
- `setInterval` 每 60 秒。不採：不落在整分鐘上，標記最多晚將近一分鐘才換。
- 只在頁面拿回焦點時更新。不採：調度員看著畫面不動手，正是這次回報的情況。

### 時間軸的每一趟畫成鳥瞰的公車，車頭朝右

2026-10-27 使用者要時間軸「看起來更像是調度車輛的樣子」。先在畫布比了三列：現況的方塊、A（擋風玻璃、後窗、兩側後照鏡、一點陰影）、B（只留圓車頭與一條擋風玻璃）。使用者選 A，問了車頭朝右還是朝左。

- 每一趟都車頭朝右：橫軸是時間不是道路，左端是發車、右端是到達，公車從發車開往到達，車頭停在到達的時刻。發車時刻寫在車尾那一端，貼著發車點，不被擋風玻璃擋到。往右拖是改晚發，跟公車往前開同方向。
- 去程、返程照舊用深淺分（`#334155` 與 `#cbd5e1`），車窗與後照鏡照方向配色，不新增顏色。
- 代價：車窗吃掉段裡的空間，所以段寬不到 36px 就不寫發車時刻（原本 26px）。畫布上 251區 的 109 趟，現況在 1280 與 390 都寫得出 109 趟，A 在兩種寬度都是 103 趟（數過的）。不寫的那幾趟，按鈕的 `aria-label` 照舊有時刻，發車表也照舊列。
- 後照鏡伸出車身上下各 2px：趟次的按鈕原本 `overflow-hidden`（把放不下的字切掉），字只在放得下時才寫，拿掉它不會讓字跑出來。
- 換過車、拖拉時會換走的班、選取的那一趟的框跟著車身的圓角，數值在 Design Source。
- 圖例兩個方向的色塊換成小公車。

替代方案：

- 車頭朝左。不採：看起來像往過去開；擋風玻璃落在發車那一端，時刻得往右讓開。
- 去程朝右、返程朝左。不採：等於把橫軸當成地圖，返程的車頭會朝著過去；方向已經用深淺分、圖例有寫，再用朝向分一次反而跟時間軸打架。
- B（只留車頭）。使用者選了 A：B 看起來比較像圓角的長條，不太像公車。
- 放不下時刻的短趟次退回方塊。提過，使用者沒有要。

### 測試：時鐘的排程寫 Vitest，時鐘走、切回分頁、焦點在發車表寫系統測試；公車的樣子不寫斷言

- `app/frontend/timetable/minute_clock.test.js`（Vitest 的假計時器）：第一次在下一個整分鐘、之後每分鐘、`stop()` 之後不再叫、每次都照 `now()` 重算。
- `spec/system/timetable_day_spec.rb`：
  - 規格 Scenario「A minute passes」：頁面的時鐘換成從某個整分鐘前半秒起、照真實時間走的時鐘，送一次 `visibilitychange` 讓時鐘照它重排，然後不按任何東西，等標記換到下一分鐘，看發車表與停在末站的車也照它畫。
  - 「Page shown again」：換到別的時刻後送 `visibilitychange`，標記馬上換。
  - 「Focus in the departures」：焦點在一班的派車選單時時鐘走過一班，標記換了、發車表沒換、焦點還在；焦點離開後，發車表照新的現在畫。
  - 時刻照 9001 的測試資料挑；現有的 `set_clock`（換時鐘後按一下目前那一端）照舊可用。
  - 開當天的共用 helper（這份檔的 `click_start`、`open_day`，`spec/system/timetable_day_timeline_spec.rb` 的 `start_day`、`continue_day`）先用 `hold_clock` 把頁面的時鐘停在當下的時刻：例子照舊是照開始時的現在寫的，計時器到點時讀到同一分鐘、什麼都不重畫；要特定時刻的例子照舊用 `set_clock` 蓋過去。
- 公車的樣子（車窗、後照鏡、圓角、顏色、圖例）是寫死的版面，不寫斷言，跟 `02-day-dispatch-timeline`「測試：換算與落點寫 Vitest，拖拉與鍵盤寫系統測試，不截圖」同一個判準，由使用者在畫面上確認。`DEPARTURE_LABEL_PX` 是寫死的門檻；`fitsLabel` 本身的 Vitest 照舊。

### GitHub 與「關於」另開新分頁，讀螢幕軟體聽得到

**Supersedes**: ui-touchups / 文章連結不開新分頁、不加外部連結圖示：跟起點區塊連到《未來城市》的連結一致，整個 app 沒有開新分頁的連結。

2026-10-27 使用者看過做好的名稱列之後要求：「github link & about 做另開視窗」。被取代的非目標，理由是跟起點區塊連到《未來城市》的連結一致、整個 app 沒有開新分頁的連結；`ui-touchups` 當時也否決「開新分頁並加 ↗」，因為那等於另訂一條規則。這次使用者明確要另開，名稱列這兩個就是全站第一批開新分頁的連結（2026-10-27 查過，`app/views` 與 `app/components` 裡沒有任何 `target`）。

- 名稱列的 GitHub 連結與文章連結都帶 `target="_blank"` 與 `rel="noopener"`。`noopener` 讓新分頁拿不到這一頁的 `window.opener`；不加 `noreferrer`，作者的 repo 與文章照樣看得到是從這裡連過去的。
- 讀螢幕軟體聽得到會開新分頁：名稱列裡放一個 `hidden` 的 `<span id="site-bar-new-tab">`，字從 `.yml` 的 `new_tab` 讀（tw「另開新分頁」，en「opens in a new tab」），兩個連結用 `aria-describedby` 指向它。用描述而不是連結文字：連結的名字照舊是「GitHub」與「關於這個網站」，規格情境與 `spec/requests/site_layout_spec.rb` 比對的連結文字都不變。
- 畫面上不加 ↗：使用者只要求另開，名稱列的樣子照已選定的畫布。
- 名稱列以外對外的連結（起點區塊連到《未來城市》、頁尾的出處）照舊在原分頁開，這次不動。

替代方案：

- 加看得到的 ↗。不採：使用者沒有要，名稱列的樣子照已選定的畫布。
- 把「另開新分頁」寫進連結文字（例如 sr-only 的「（另開新分頁）」）。不採：連結的名字會變長，規格與測試比對的連結文字都要跟著改；用描述就念得到。
- 全站對外的連結都改成另開。不採：使用者只說這兩個。

## Implementation Contract

**看得到的行為**

- 每一頁的名稱列：左邊是標誌，路線頁、班表頁與當天調度頁再接班表、當天調度；右端是 GitHub 圖示與「關於」，GitHub 在「關於」左邊。
- 640px 以上：GitHub 圖示 20px，跟其他連結同色（`#475569`，hover `#0f172a`），點了另開新分頁到 https://github.com/kaochenlong/bus-turn-around。
- 640px 以下：沒有 GitHub 圖示，「關於」在名稱列右端。
- 每種寬度：文章連結看得到「關於」（en：About），讀螢幕軟體念「關於這個網站」（en：About this site），點了另開新分頁到 https://kaochenlong.com/bus-turn-around。
- 讀螢幕軟體與 Tab 的順序：站名、（班表、當天調度）、GitHub、關於這個網站。
- 名稱列的高度不變。
- GitHub 連結與文章連結都另開新分頁；讀螢幕軟體在連結名字後面多念一句「另開新分頁」（en：opens in a new tab）。

**介面**

- `SiteBarComponent::REPOSITORY_URL = "https://github.com/kaochenlong/bus-turn-around"`；`ABOUT_URL` 不變。
- `app/components/site_bar_component.yml` 新增 `repository`：tw 與 en 都是「GitHub」，zh-TW 照舊 `<<: *tw`；`about_lead`、`about_rest`、`timetable`、`day_dispatch` 不變。
- `SiteBarComponent.new(timetable_route_id:, current:)` 的參數不變，layout 與兩個 controller 不用改。
- 兩組之間至少保留現在的連結間距（640px 以下 20px、以上 28px）。GitHub 連結左右各 2px（`px-0.5`，寬 24px），右組的間距 26px（`gap-6.5`），畫面上圖示到「關於」的字 28px（方案 A）。
- 元件裡描述排法的註解跟著改：`.rb` 的 class 註解（連結接在站名旁邊、手機上文章連結只顯示前一段）、`.html.erb` 的「選單接在標誌旁邊靠左」與「手機上（640px 以下）只顯示『關於』」、`.yml` 的「手機上只顯示前一段」。
- 另開新分頁：GitHub 連結與文章連結 `target: "_blank"`、`rel: "noopener"`、`aria: { describedby: "site-bar-new-tab" }`；名稱列裡一個 `hidden` 的 `<span id="site-bar-new-tab">`，字從 `.yml` 新增的 `new_tab` 讀（tw「另開新分頁」，en「opens in a new tab」）；`ABOUT_URL` 與 `REPOSITORY_URL` 寫著在原分頁開的註解改成另開新分頁。

**沒有失敗的情況要處理**：名稱列都是伺服器輸出的寫死連結，不讀資料、不送請求；路線沒有資料時（例如 9001）名稱列照樣有五個連結。

**驗收**

- 改過的 `spec/requests/site_layout_spec.rb` 四個例子與 `spec/system/route_page_mobile_spec.rb` 新加的例子，先看它們在實作前失敗，實作後 `bundle exec rspec spec/requests/site_layout_spec.rb spec/requests/pages_spec.rb spec/system/route_page_mobile_spec.rb` 全綠。
- 用名稱列找連結與列印的系統測試照樣綠：`bundle exec rspec spec/system/buffer_trade_spec.rb spec/system/rest_command_spec.rb spec/system/timetable_edit_spec.rb spec/system/timetable_day_spec.rb spec/system/timetable_print_spec.rb spec/system/timetable_day_record_spec.rb`。
- `bin/rubocop` 對改過的 `.rb` 沒有警告；最後 `bin/ci` 全綠。
- 畫面上的排法（右端、只顯示「關於」、間距、圖示的大小與顏色）由使用者自己確認。

**範圍**

- 這次做：畫布；`SiteBarComponent` 的 `.rb`、`.html.erb`、`.yml`；`spec/requests/site_layout_spec.rb` 與 `spec/system/route_page_mobile_spec.rb`。
- 不做：名稱列的高度、標誌、區塊導覽、404 頁、n-gear 的 repo、選單、看得到的 ↗、名稱列以外對外連結的開法。

**當天調度跟著時鐘走**

- 看得到的行為：
  - 顯示當天時，調度員什麼都不按，每到瀏覽器時鐘的整分鐘：時間軸的「現在 HH:MM」標記與線移到新的時刻，圖例的「現在 HH:MM」跟著換；發車表的狀態（已發車、下一班、照計畫、車還沒回來）與現在分隔線照新的現在畫，捲動位置不變；停在末站的車、站了幾分鐘、接下來要回來的車照新的現在畫。
  - 分頁切回來時馬上照現在畫一次。
  - 焦點在發車表的捲動框裡時，發車表停在原樣、焦點留在原地，焦點離開捲動框時照現在補畫；發車表下面顯示改不成的說明時，發車表也停在原樣。時間軸的標記與停在末站的車照常更新。
  - 時鐘不重畫時間軸的條與趟次：拖拉中的那一趟、選取的框、焦點在某一趟都不受影響。
  - 今天的計畫（還沒開始當天）不跟時鐘走；離開頁面時時鐘停掉。
- 介面：
  - `app/frontend/timetable/minute_clock.js` 的 `startMinuteClock({ now, onMinute })`：照 `now()` 算到下一個整分鐘排一次 `setTimeout`，到了叫 `onMinute()` 再照 `now()` 重排；回傳 `stop()`。
  - `timelineView(...).moveNow(minutes)`：只更新現在的分鐘數、現在的標記與線、圖例的「現在 HH:MM」。
  - `dayView(...).refreshNow()`：照 `now()` 算現在，跟上次畫的同一分鐘就不動（`render()` 也記下它畫的分鐘）；時間軸 `moveNow`；`renderStanding`；發車表交給 `refreshDepartures()`。
  - `dayView(...).refreshDepartures({ focusLeft })`：自己算 `currentDay`；焦點在捲動框裡（`focusLeft` 不是 true 時看 `document.activeElement`）、或有改不成的說明時，發車表整張不動；否則沒有走過這一端任何一班的發車時刻時只改分隔線上的字，走過了才重畫列與分隔線，保留捲動位置。捲動框的 `focusout` 移到框外時以 `focusLeft: true` 呼叫，補畫先前沒畫的那一次。
  - `dayDispatch()`（`day_page.js`）：`show` 時開始時鐘（先停掉舊的），`showPlan` 時停掉；`visibilitychange` 變成看得到時 `refreshNow()` 並重排；`destroy()` 停掉時鐘並拿掉監聽。系統測試換掉的 `now` 照用。
- 失敗的情況：時鐘只讀 `now()`，不送請求、不改存的當天；沒有顯示當天時，`refreshNow()` 什麼都不做。
- 驗收：`yarn test:js`（`minute_clock.test.js`）與 `bundle exec rspec spec/system/timetable_day_spec.rb spec/system/timetable_day_timeline_spec.rb` 全綠，新的例子先看它們在實作前失敗。
- 範圍：做時鐘、`refreshNow`、`moveNow` 與三個情境的測試；不做秒、倒數、今天的計畫、列印、頁首數字。

**時間軸的公車**

- 看得到的行為：時間軸的每一趟是一台車頭朝右的鳥瞰公車，數值照 Design Source；段寬不到 36px 不寫發車時刻；換過車、會換走的班、選取的框跟著車身圓角；圖例兩個方向的色塊是小公車。拖拉、選取、鍵盤操作、讀螢幕軟體念的字都不變。
- 介面：`DayTimelineComponent` 的趟次 template（車窗與後照鏡是 `aria-hidden` 的 span，照 `data-go-back` 上色，拿掉 `overflow-hidden`）、換過車與選取與會換走的框的 template、圖例兩個方向的色塊；`day_timeline_view.js` 的 `DEPARTURE_LABEL_PX` 改成 36。
- 驗收：`bundle exec rspec spec/system/timetable_day_timeline_spec.rb spec/components/day_timeline_component_spec.rb spec/system/timetable_day_spec.rb` 全綠；公車的樣子由使用者在畫面上確認。
- 範圍：做時間軸的趟次、框與圖例；不做車號、輪子、用朝向分去返、窄趟次退回方塊、列印。

## Risks / Trade-offs

- [GitHub 的 mark 之後改版，網站上的還是舊的] → path 釘在 `@primer/octicons@19.42.0`，要換時從同一個來源換。
- [手機上找不到 repo] → 手機上的「關於」連到介紹文章，文章那一頁有作者的 GitHub 帳號首頁（不是 repo 本身，要多點一下）。
- [看得到的「關於」被讀成「關於作者」] → 使用者接受這個代價；讀螢幕軟體照舊念完整的字。
- [repo 改成不公開，連結會變 404] → repo 公不公開由使用者管，網站不檢查。
- [將來名稱列再多連結，手機上又放不下] → 360 寬只剩約 4px，再加連結要先回畫布比方案。
- [焦點一直停在發車表裡，發車表就一直停在那一刻] → 時間軸的標記照樣走，調度員看得到時間；焦點一離開發車表就補畫。
- [背景分頁的計時器被瀏覽器放慢或暫停] → 分頁切回來時馬上畫一次並重排。
- [短的趟次看不到發車時刻（畫布上 251區 109 趟有 6 趟）] → 按鈕的 `aria-label` 與發車表照舊有時刻；要的話之後再加「放不下就退回方塊」。
- [12 台以上的 28px 條沒在畫布上看過] → 車窗照上下距離畫；使用者在畫面上確認，不對再回畫布。
- [計時器在現有的系統測試跑到一半時到點] → 用 `set_clock` 固定時鐘的例子，`render()` 記下的分鐘跟時鐘讀到的相同，計時器到了不動。用真實時鐘的例子，由開當天的共用 helper 先 `hold_clock` 把時鐘停在當下（見測試那一條決定），不一個個加 `set_clock`：一處改動涵蓋全部例子，很多例子加一行也會超過 5 行的上限。

## Migration Plan

沒有資料、沒有 migration。照平常的方式部署；要退回就部署上一版。

## Open Questions

- 沒有。GitHub 圖示與「關於」的間距，2026-10-27 使用者在 task 1.1 的畫布上選了方案 A（見 Design Source）。
- 沒有。時間軸公車的朝向，2026-10-27 使用者問過之後照車頭朝右（見「時間軸的每一趟畫成鳥瞰的公車，車頭朝右」）。
