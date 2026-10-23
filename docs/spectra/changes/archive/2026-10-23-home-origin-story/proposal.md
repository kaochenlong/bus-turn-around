## Why

這個 change 服務第一樣交付物「路線健檢卡」在網站上的入口，也就是首頁，並把人帶到中山幹線路線頁上的折返停留與第二樣交付物「換休息」試算。它不需要新的資料：內容取自《未來城市》2026-07-31 的報導〈「我也開始搶黃燈了！」陽明交大碩士生開公車60天，把駕駛掙扎寫進論文推動排班改革〉，整理在 `docs/background.md`「機制：班表是怎麼把人逼快的」一節；兩個連結要不要出現，看 `config/route_page.yml` 的路線清單。不讀衍生表，不讀原始檔。

首頁現在說得出這個網站量什麼，卻沒說為什麼要量。整個專案是從這篇報導開始的：鄭義穎 2025 年暑假在光華巴士開中山幹線，9:50 回站、10:00 又要發車，幾週後自己也開始搶黃燈。報導裡的路線與業者，就是網站第一條有路線頁的 15373 中山幹線（光華巴士，`docs/spectra/changes/archive/2026-10-22-zhongshan-turnaround-ends/design.md` 的 Context）；首頁標題「折返點實際能休幾分鐘？」問的就是他那 10 分鐘。把這段放在標題下面，第一次來的人才知道這個問題從哪來。

## What Changes

- 首頁在 hero 與路線清單之間加一個區塊（`data-section="origin"`），只講報導本身：
  - 一行小標「這個網站從一篇報導開始」，區塊標題是篇名那句「我也開始搶黃燈了！」。
  - 一段話：他是誰、開哪條線、原本主張慢慢開、幾週後也開始搶黃燈；班表給的時間比實際要跑的少，差額只能由駕駛用開快或少休息來補；這個網站量的，就是每台車到了末站、再開出去之前實際停了多久。
  - 一張時刻卡：標題寫出 06:30 到站、20:30 下班，下面列 06:50 發車、09:50 回站、10:00 發車，09:50 與 10:00 之間標「10 分鐘」與引句「幾乎只能跑步去上廁所」。
  - 兩個連結：中山幹線路線頁的折返停留（`/routes/15373#layovers`）與換休息試算（`/routes/15373#buffer`）。路線清單設定裡沒有 15373 時，不出這兩個連結。
  - 出處：媒體、篇名、發表日期 2026-07-31，篇名連到原文 `https://futurecity.cw.com.tw/article/4090`。
- 區塊是伺服器輸出的 HTML 與 CSS，不讀資料庫，不加任何 JS。桌機兩欄，文字在左、時刻卡在右；手機照故事的順序排成一欄。
- `home-page` 規格的「Home page content and order」改三處：區塊順序多一塊；「不放任何指標」與「日期全從 route_days 讀」兩條，對標了出處的報導引用開例外，範圍是報導的時刻、日期，以及直接由報導的兩個時刻算出的間隔。網站自己算的數字仍然一個都不上首頁。
- `docs/spectra/LANGUAGE.md`：「首頁」的定義加上這一塊，邊界補上引用的例外；「趟次與班次」的邊界補一條：報導與駕駛口中的「一趟」是一個來回，等於兩個趟次。

## Non-Goals

- 報導之後的發展：論文進度、公運處的四大藥方與 2026-09-21 的回應、沈伯洋的政見與 2026-09-22 的會面（`docs/background.md`「後續」一節）。這些是某一天的狀態，會過期，首頁上沒有人會回來改日期；候選人的名字在 2026-11-28 選舉前出現在首頁，網站會被讀成某一邊的，而公運處與選後的新市府都是這個網站要說服的對象。
- 網站自己算的任何數字，例如中山幹線青年公園端 1.9 分鐘的折返停留中位數、量到的行駛時間。`home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」對網站的數字照舊成立；`docs/background.md` 也寫明他估的 3 小時 20 分與量到的行駛時間不能互相驗證。
- 比例尺的時間軸與完整的一天班表：報導沒寫第三趟幾點回站，畫成比例就得自己編那段長度；區塊也照設計稿收在原本一半的高度。
- 報導的照片、兩句以外的直接引用，以及任何讀起來像跟報導或受訪者合作的文字。
- 路線頁的任何區塊、layout、`DataSourcesComponent` 的三個資料集連結、`DataLimitationsComponent`。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `home-page`: 新增需求「Origin story block」，描述講網站起點的區塊；修改「Home page content and order」的區塊順序，以及不放指標、日期來源兩條規則對報導引用的例外。

## Impact

- 新增：app/components/origin_story_component.rb、app/components/origin_story_component.html.erb、app/components/origin_story_component.yml、spec/components/origin_story_component_spec.rb
- 修改：app/views/pages/home.html.erb、spec/requests/pages_spec.rb、docs/spectra/LANGUAGE.md
- 設計稿：https://claude.ai/artifact/KfP7q1hFCHn5boQXmif9L7 （桌機、區塊本身、手機三張畫板），區塊那張的原始檔存在 .spectra/design-cache/home-origin-story/Story.dc.html
- 不碰：路線頁、layout、衍生表、`analysis/`、`DataLimitationsComponent`、`DataSourcesComponent`、插圖與它的動畫
- 資料限制與假設：這個 change 不改任何指標定義。區塊裡描述折返停留的那句說的是車，不是駕駛，同一頁的資料限制已經寫明折返停留是駕駛休息的上限。報導的文字與時刻程式核對不了：開發時抓不到原文（futurecity.cw.com.tw 擋自動抓取），內容取自 `docs/background.md` 的整理，上線前要有人用瀏覽器對過原文。
