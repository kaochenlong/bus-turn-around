## Context

首頁 `app/views/pages/home.html.erb` 在 `main.page-column py-8 font-route text-body text-slate-800 [font-variant-numeric:tabular-nums]` 裡依序 render `HomeHeroComponent`、`RouteListComponent`、`DataLimitationsComponent.new(scope: :home)`、`DataSourcesComponent`，hero 之後的區塊各自帶 `mt-12`。`spec/requests/pages_spec.rb` 收集整頁的 `[data-section]`，斷言順序是 `%w[hero routes limitations sources]`；同一份檔案也斷言不跑 script 時 HTML 已經有哪些元素。

元件慣例：ViewComponent 的 `.rb`、`.html.erb`、`.yml` 放同一層，`.yml` 用 `tw` 當 anchor，再給 `zh-TW` 與 `en`。`HomeHeroComponent` 是沒有方法的空類別；`DataSourcesComponent::DATASETS` 把外部網址放在 Ruby 常數、顯示名稱放 `.yml`；`RouteListComponent#route_page_path` 用 `helpers.route_path` 組路線頁網址。development 與 test 開了 `raise_on_missing_translations`。固定文案不寫文字斷言，測的是元素在不在（`home-page` 設計「顯名聲明放 layout footer」那條的說法）；`RSpec/ExampleLength` 上限 5 行。

路線頁 `app/views/routes/show.html.erb` 用 `CardComponent.new(id: "layovers")` 與 `CardComponent.new(id: "buffer")` 包折返停留與換休息試算，所以 `/routes/15373#layovers`、`/routes/15373#buffer` 會捲到那兩張卡；試算預設每次折返留 15 分鐘（`RoutePage::BufferTrade::DEFAULT_MINUTES`）。哪些路線有頁面看 `RoutePage.route_ids`（`config/route_page.yml`），test 環境只有 9001，設定裡沒有的路線，路線頁回 404。

報導內容的來源是 `docs/background.md`「機制：班表是怎麼把人逼快的」一節。原文頁 futurecity.cw.com.tw 前面有 Cloudflare 驗證，WebFetch 與 curl 都是 403，Wayback 的存檔也是失敗頁；篇名從 Wayback 索引的網址解出來，跟 `docs/background.md` 寫的「我也開始搶黃燈了！」一致。這一節的時刻有兩個來源：06:30、06:50、10:00、12:45、13:15、17:15、20:00、20:30 是他的班表，09:50 是他照時速 40 開完第一趟、實際回站的時間（「第一趟開三小時就 9:50 才回站」）。

## Design Source

- 來源：Claude Design 畫布 https://claude.ai/artifact/KfP7q1hFCHn5boQXmif9L7 ，版本 1792744105-ea3a（2026-10-23，使用者要求高度砍半之後的版本）。區塊本身是 `Story.dc.html`；`Main.dc.html`（桌機 1280）與 `Phone.dc.html`（手機 390）把它放進首頁的上下文。
- 快取：`.spectra/design-cache/home-origin-story/Story.dc.html`，同目錄另有 `Main.dc.html` 與 `Phone.dc.html`（gitignored，不 commit）。
- 設計稿用 inline style 與 hex 寫，實作換成專案的 Tailwind class 與 `application.css` 的 `@theme` 字級：

| 元素 | 設計稿的值 | 實作用的 class |
| --- | --- | --- |
| 區塊外距 | 上方 48px，左右沿用 page-column（16px，640px 以上 32px），最寬 1152px | `mt-12`；左右與最寬由首頁的 `main.page-column` 提供 |
| 版面 | 兩欄等寬，欄距 56px、列距 24px；時刻卡跨兩列、靠上；容器 888px 以上才分兩欄 | `grid gap-y-6 lg:grid-cols-2 lg:gap-x-14`；時刻卡 `self-start lg:row-span-2` |
| 小標「這個網站從一篇報導開始」 | 15px、500、字距 0.02em、#0f766e | `text-note font-medium tracking-[0.02em] text-teal-700` |
| 區塊標題 | 23px／640px 以上 26px、700、行高 1.35、字距 0.01em、#0f172a，上方 8px | `mt-2 text-section-sm leading-snug font-bold tracking-[0.01em] text-slate-900 sm:text-section` |
| 內文 | 17px、行高 1.65、#1e293b，上方 12px | 承接 `main` 的 `text-body text-slate-800`，`mt-3` |
| 時刻卡 | 白底、1px #e2e8f0、圓角 16px、內距 20px | `rounded-2xl border border-slate-200 bg-white p-5` |
| 卡片標題 | 17px、700、行高 1.5、#0f172a，左右 4px | `px-1 leading-normal font-bold text-slate-900` |
| 清單 | 上方 12px，不帶項目符號 | `mt-3` |
| 時刻列 | 上下 9px、左右 4px、間距 16px，基線對齊；06:50 那列下緣 1px #f1f5f9，09:50 與 10:00 兩列沒有分隔線 | `flex items-baseline gap-4 px-1 py-2.25`；06:50 加 `border-b border-slate-100` |
| 時刻 | Barlow Semi Condensed 600、20px、行高 1.2、寬 56px；06:50 是 #0f172a，09:50 與 10:00 是 #0f766e | `w-14 shrink-0 font-route-figure text-subsection leading-[1.2] font-semibold`，加 `text-slate-900` 或 `text-teal-700` |
| 事件文字 | 06:50「發車」#334155；09:50「回站」與 10:00「發車」500、#0f172a | `text-slate-700`；`font-medium text-slate-900` |
| 間隔列 | 底色 #f0fdfa、圓角 10px、內距 12px 14px、上下外距 2px，可換行，欄距 12px、列距 2px | `my-0.5 flex flex-wrap items-baseline gap-x-3 gap-y-0.5 rounded-[10px] bg-teal-50 px-3.5 py-3` |
| 間隔的「10 分鐘」 | Barlow Semi Condensed 600、26px、行高 1.15、#0f766e | `font-route-figure text-figure-card leading-[1.15] font-semibold text-teal-700` |
| 間隔的引句 | 15px、行高 1.5、#115e59 | `text-note leading-normal text-teal-800` |
| 連結按鈕 | 至少 44px 高、左右 16px、1px #e2e8f0、全圓角、白底、16px、500、#0f766e，按鈕間距 8px，可換行 | 外層 `flex flex-wrap gap-2`；按鈕 `inline-flex min-h-11 items-center gap-1.5 rounded-full border border-slate-200 bg-white px-4 text-table leading-snug font-medium text-teal-700` |
| 按鈕 hover | 設計稿沒有畫 | 沿用路線清單卡片的 `hover:border-teal-600 hover:bg-teal-50/40` |
| 箭頭圖示 | 16×16 inline SVG，stroke 2、圓頭圓角，兩條 path：`M5 12h14`、`m13 6 6 6-6 6` | 同樣的 SVG，`stroke="currentColor"`，`aria-hidden="true"` |
| 出處 | 14px、行高 1.6、#64748b，上方 12px；篇名連結 #0f766e、底線、offset 2px | `mt-3 text-label leading-relaxed text-slate-500`；連結 `text-teal-700 underline underline-offset-2 hover:text-teal-900` |

設計稿用 CSS grid 的 auto-fit 在容器 888px（視窗約 952px）時分欄；實作用 `lg:`（1024px），差別只在 952 到 1023px 之間仍是一欄。

## Goals / Non-Goals

**Goals:**

- 第一次打開首頁的人，在標題下面讀到這個網站從哪篇報導開始、報導裡那條線就是中山幹線，並點得進中山幹線路線頁的折返停留與換休息試算。
- 只講報導本身。報導的時刻、日期跟出處放在一起；網站自己算的數字不上首頁。
- 區塊的高度大約是設計稿第一版的一半：桌機上的內容約 340px，手機上約 730px（照字數與行高估的，以設計稿畫布與 7.1 的實機檢查為準）。
- 伺服器輸出就完整：不加 JS，不讀資料庫。

**Non-Goals:**

- 報導之後的發展：論文進度、公運處的回應、候選人的政見與會面。
- 網站自己算的任何數字，包括中山幹線的折返停留中位數與行駛時間。
- 完整一天的班表與比例尺的時間軸。
- 報導的照片、兩句以外的直接引用。
- 路線頁、layout、插圖、`DataLimitationsComponent`、`DataSourcesComponent` 的任何改動。

## Decisions

### 只講報導本身，不放後續、政見與公運處的回應

區塊的內容只取 `docs/background.md`「機制」一節：他是誰、他的一天、搶黃燈、班表為什麼把人逼快。「後續」一節（論文進度、公運處的四大藥方與 2026-09-21 的回應、沈伯洋的政見與 2026-09-22 的會面）不上首頁。

理由：那些是某一天的狀態，「到這一天為止，沒有任何一項變成制度」總有一天不成立，而首頁沒有人會回來改日期，這正是 `home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」要擋的：頁面只說它真的知道的事。候選人的名字在 2026-11-28 選舉前一個月出現在首頁，網站會被讀成某一邊的；README「誰受益」第 2 項的公運處、`docs/use-cases.md` 第 9 項的新市府都是這個網站要說服的人。後續裡的數字也不能用：1.9 分鐘是網站自己算的一天的指標，3 小時 20 分與量到的行駛時間，`docs/background.md` 自己寫了不能互相驗證。

替代方案：文章加上他後來提的折返點休息站（否決：網站還量不到折返點設施，`home-page` 的決定「標題用網站今天答得出來的問題」的理由在這裡一樣成立，寫了就像承諾）；文章加上完整後續（否決，理由如上）。使用者在 2026-10-23 的討論中選了只講文章本身。

### 起點區塊放在 hero 與路線清單之間

順序變成 hero、起點、路線清單、資料限制、資料來源。標題提出問題，起點區塊說問題從哪來，路線清單是去看答案的地方。

理由：`docs/use-cases.md` 第 11 項的駕駛是直接打開自己那條線的路線頁，首頁主要是第一次來的人在看，對他們來說起點比清單先讀到有用。代價是路線清單在桌機上往下移約 340px，這是使用者要求高度砍半之後的大小。

替代方案：放在路線清單之後（否決：故事變成附註，標題的問題要讀完清單才有答案）；另開一頁、首頁只放連結（否決：使用者要的是在首頁說故事，而且要多一條導覽，`home-page` 把共用的頁首導覽列為非目標）。

### 時刻卡只列 06:50、09:50、10:00 與中間的 10 分鐘，06:30 與 20:30 寫進卡片標題

清單四列：06:50 發車、09:50 回站、10 分鐘（帶引句「幾乎只能跑步去上廁所」）、10:00 發車。卡片標題是「他的一天：06:30 到站，20:30 下班」。12:45、13:15、17:15、20:00 不列。

理由：故事的重點是 9:50 回站到 10:00 發車那 10 分鐘，四列就說得完，區塊也才收得進原本一半的高度；06:30 與 20:30 放進標題，一天有多長還看得出來。卡片標題寫「他的一天」，不寫「班表」，因為 09:50 不在班表裡，是他照時速 40 開完第一趟實際回站的時間。清單寫「發車」不寫「第一趟」：報導的「一趟」是一個來回，跟 `docs/spectra/LANGUAGE.md` 的趟次（單一方向）不是同一件事。

替代方案：完整列出九個時刻（否決：第一版設計稿就是這樣，使用者嫌太大）；比例尺的時間軸（否決：報導沒寫第三趟幾點回站，畫成比例就得自己編那段長度）。

### 報導引用的時刻、日期與間隔不算首頁的指標

`home-page` 的「Home page content and order」加一句：起點區塊引用的報導時刻、日期，以及直接由報導的兩個時刻算出的間隔（「10 分鐘」）不算指標，只能出現在起點區塊、跟出處放在一起；「日期全部從 route_days 讀」對報導引用的日期與發表日期開例外。

理由：`home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」的理由是數字要跟定義和資料限制放在一起、頁面不承諾做不到的更新頻率。報導的時刻是 2025 年某一個人的經驗，標了出處、日期固定，不會過期，也不是網站對任何路線的量測；那個決定對網站自己的數字照舊成立，所以這裡收窄它的適用範圍，不取代它。

替代方案：故事裡不放任何時刻與日期（否決：拿掉 9:50 與 10:00，故事就沒有核心）；整條決定作廢（否決：網站的數字仍然只該住在路線頁）。

### 兩個路線頁連結只在路線清單設定有 15373 時出現

`OriginStoryComponent` 在 `RoutePage.route_ids` 包含 15373 時才輸出連到 `/routes/15373#layovers` 與 `/routes/15373#buffer` 的兩個按鈕；沒有時兩個都不出，其他內容照舊。

理由：設定裡沒有的路線，路線頁回 404。`route-251-pages` 的決定「每條路線各自驗收，沒過就單獨拿掉」說明路線會從設定裡被拿掉，到時候首頁不該留一個連到 404 的按鈕。測試照 `route-251-pages` 的決定「首頁的路線清單測試在例子裡指定路線清單，不跟著正式設定」，在例子裡 stub `RoutePage.route_ids`。

替代方案：永遠輸出連結（否決：會連到 404）；沒有 15373 時整個區塊都不出（否決：故事本身不靠路線頁成立）。

### 元件 OriginStoryComponent：文案放 yml，原文網址與路線 Id 放 Ruby 常數

新元件 `OriginStoryComponent`（`app/components/origin_story_component.rb`、`.html.erb`、`.yml`），沒有建構參數。常數 `ARTICLE_URL = "https://futurecity.cw.com.tw/article/4090"` 與 `ROUTE_ID = 15373`，照 `DataSourcesComponent::DATASETS` 的寫法；方法 `route_links?` 回傳 `RoutePage.route_ids.include?(ROUTE_ID)`，`route_section_path(anchor)` 回傳 `helpers.route_path(ROUTE_ID, anchor:)`。所有中文字放 `.yml`：小標、標題、內文、卡片標題、三個事件名稱、「10 分鐘」、引句、兩個按鈕、出處的前綴與篇名。時刻與發表日期在 `.html.erb` 裡寫成 `time` 元素，`datetime` 與顯示的字相同（`06:50`、`09:50`、`10:00`、`2026-07-31`）；間隔那一列標 `data-interval`。`en` 的文案是我們的翻譯，引句與標題照意思翻；出處裡的篇名保留中文原文。

理由：跟既有元件同一套寫法，翻譯檔是文案唯一的來源；常數讓測試與實作指向同一個網址與路線。

替代方案：時刻放 `.yml` 用陣列 render（否決：四列的樣式各不相同，間隔列也不是時刻，陣列只是把版面藏進資料）；網址寫在 `.yml`（否決：網址不是文案，也不翻譯）。

### 文案規則：用自己的話、只引用兩句、不寫成合作、不把推論寫成他說的

- 直接引用只有篇名那句「我也開始搶黃燈了！」與「幾乎只能跑步去上廁所」，其他都是轉述。
- `docs/background.md` 的「缺的輸入正是真實的分時行駛時間分佈」是本專案的推論（放在「跟本專案的關係」），不寫進區塊。
- 他列在 `docs/background.md` 的「可能的對話對象」，目前沒有任何合作；文案不寫「與」「合作」「一起」這類字。
- 我們自己的句子不用「趟」；「回站」照報導的說法，不替它補是哪一站（`GetProvider.gz` 沒有營業站的座標）。用「駕駛」，跟首頁其他文案一致。
- 上線前由使用者用瀏覽器對過原文：篇名、兩句引用、五個時刻、2025 年暑假、光華巴士、陽明交大碩士生。對不上的就改 `.yml`，不改結構。

理由：引用要在合理範圍內並標明出處；原文在開發時讀不到，只能靠人核對。

替代方案：照 `docs/background.md` 的整理直接上線（否決：那份整理沒有對照原文的紀錄，引號裡的字錯了就是替人說話）。

### LANGUAGE.md 的「首頁」與「趟次與班次」兩條跟著改

- 「首頁」的定義加上「交代這個網站從哪篇報導開始」，邊界補一句：報導引用的時刻、日期與直接由時刻算出的間隔不算指標，只出現在起點區塊、跟出處放在一起。
- 「趟次與班次」的邊界補一句：報導與駕駛口中的「一趟」通常是一個來回，例如 2025 年報導裡中山幹線 06:50 發車、09:50 回站的那一趟，在這裡是去程與返程兩個趟次。

理由：`docs/spectra/LANGUAGE.md` 開頭說文件或對話出現這裡沒有的常用概念就是詞彙漂移，要回來改。這兩處在討論時已經出現。

## Implementation Contract

- 行為：`GET /` 的區塊順序是 hero、origin、routes、limitations、sources。起點區塊（`section[data-section="origin"]`）在伺服器輸出裡就完整，含小標、引篇名的標題、一段內文、時刻卡（標題寫 06:30 與 20:30，清單依序是 06:50、09:50、間隔、10:00）、出處；路線清單設定有 15373 時另有兩個按鈕。
- 介面：`OriginStoryComponent.new`，沒有參數；`OriginStoryComponent::ARTICLE_URL`、`OriginStoryComponent::ROUTE_ID`；清單是 `ol`，每列一個 `li`，時刻是 `time[datetime]`，間隔列是 `li[data-interval]`、裡面沒有 `time`；出處的發表日期是 `time[datetime="2026-07-31"]`；按鈕的 `href` 是 `/routes/15373#layovers` 與 `/routes/15373#buffer`。
- 失敗模式：缺翻譯在 development 與 test 直接拋錯（`raise_on_missing_translations`）。設定裡沒有 15373 時兩個按鈕不出、不報錯，這是刻意的。元件不查資料庫，所以衍生表是空的也照常顯示。
- 驗收：
  - `spec/components/origin_story_component_spec.rb` 涵蓋 `home-page` 的「Origin story block」五個情境：清單順序與間隔列、出處連結與發表日期、有 15373 時的兩個按鈕、沒有 15373 時沒有按鈕但清單與出處還在、render 時沒有任何 SQL。
  - `spec/requests/pages_spec.rb` 的區塊順序例子改成 `%w[hero origin routes limitations sources]`，不跑 script 的例子多數起點區塊裡連到原文的那一個連結。
  - 對這次新增或修改的 Ruby 檔跑 `bin/rubocop`，最後跑 `bin/ci`。
  - 用 `bin/dev` 開首頁，在 390px 與 1280px 寬對照設計稿畫布的 `Phone.dc.html` 與 `Main.dc.html`。
  - 使用者對過原文（文案規則那條列的項目）。
- 範圍：做的是新元件、首頁 view、首頁 request spec、`docs/spectra/LANGUAGE.md` 兩條。不做的是路線頁、layout、插圖與動畫、`DataLimitationsComponent`、`DataSourcesComponent`、`docs/background.md`。

## Risks / Trade-offs

- [引用的字跟原文不同] → 7.2 由使用者用瀏覽器核對，對不上就改 `.yml`；核對完成前不 archive。
- [15373 之後從設定拿掉] → 兩個按鈕自動消失，故事照舊；不會留下連到 404 的按鈕。
- [起點區塊那句「每台車…實際停了多久」被讀成駕駛的休息時間] → 句子主詞是車；同一頁的資料限制第一條就寫明折返停留是駕駛休息的上限。
- [分欄斷點跟設計稿不同] → 設計稿約 952px 分欄，實作用 1024px 的 `lg:`；952 到 1023px 之間是一欄，內容與順序不變。
- [原文網址失效] → 出處仍留著媒體、篇名與日期，讀者查得到；Wayback 沒有可用的存檔，這個風險只能接受。
- [首頁變長] → 桌機多約 340px（估計值），是第一版設計稿的一半；7.1 的實機檢查會看到實際高度。
