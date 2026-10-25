## Context

路線頁與首頁現在的樣子（2026-10-25 看的）：

- layout `app/views/layouts/application.html.erb` 的 `<title>`、`og:title`、`twitter:title` 讀 `content_for(:title) || t("site.name")`；`meta name="description"`、`og:description`、`twitter:description` 一律讀 `t("site.description")`；`og:url` 是 `request.original_url`，`og:image` 是通用的分享圖。路線頁 `app/views/routes/show.html.erb` 只設 `content_for :head` 與 `:body_class`，沒有設 title，所以正式站 `/routes/15373` 與 `/routes/16111` 的 title 與分享文字跟首頁一字不差。
- 路線頁的摘要（`RouteSummaryComponent`）已經有停車端的兩個重點數字：中位數與不到 15 分鐘的比例，取自 `RoutePage::LayoverStats` 的列，格式用 `ApplicationComponent#minutes` 與 `#share`，每一行標那一端的末站與「共 N 次折返」；兩端都直接折返時寫「兩端都是直接折返，沒有停車的一端」；停車端沒有折返停留時是「—」。`02-route-page-mobile-first` 的決定「重點數字取自表格用的同一批物件與同一個格式」。
- 首頁的路線清單（`HomePage::RouteList` 與 `RouteListComponent`）一個查詢取每條路線最新的 `route_days` 列，卡上是路線名、起迄、路線 Id、最新一天與日型別，沒有任何數字；`home-page` 的決定「首頁不放指標、只放涵蓋，日期全從 route_days 讀」。
- `RoutePage::Coverage` 沒有 `day` 參數時取最新一天、`range` 預設 `day`，所以首頁卡連到的 `/routes/<Id>` 預設顯示的就是最新一天。
- 開發資料庫 2026-10-25 的實際數字（四條路線最新一天 2026-10-22 當天）：中山幹線停車端職能發展學院二 36 筆、中位數 14.7、52.8% 不到 15 分鐘；251 福安居一 30 筆、44.4、3.3%；251區 福安居一 38 筆、19.7、36.8%；307 兩端都停車，莊敬里 215 筆、13.3、61.9%，臺北客運板橋前站(藝文) 225 筆、14.4、52.4%。
- 元件的 `.yml` 翻譯只在元件渲染時查得到（ViewComponent 的 sidecar 翻譯不進全域 `I18n`，`application_component_spec.rb` 有註明），所以一個元件拿不到另一個元件 `.yml` 裡的字串；全域的 `config/locales/tw.yml`、`en.yml` 則兩邊都讀得到。
- 同時進行的 change：`small-sample-grey`（done、未歸檔、未 commit）改的是行駛時間表與來回一趟表，跟這裡沒有共用的檔；工作區另有別的 session 2026-10-25 開的 `timetable-draft`（只有 proposal），它的 Impact 寫到之後可能改 `app/views/layouts/application.html.erb`、`spec/requests/site_layout_spec.rb`、`spec/requests/routes_spec.rb`，apply 時用 `spectra task done --file` 列出改到的檔。

## Goals / Non-Goals

**Goals:**

- 轉貼一條路線頁的網址，預覽就看得出是哪條路線、涵蓋哪幾天、停車端量到什麼，而且數字跟頁面上的重點數字一字不差。
- 首頁每張有資料的路線卡看得到一個量到的結果，跟點進去第一屏的重點數字相同，旁邊有筆數與「休息的上限」。
- 數字的定義只有一份：分享文字與首頁都讀 `RoutePage::LayoverStats` 定的那一套（同一個分鐘算法、同一個 15 分鐘門檻、同一個格式），用測試鎖住。

**Non-Goals:**

- 逐路線產 `og:image`；改 `og:site_name` 與站名；title 加顏文字、切走分頁換 title（`site-easter-eggs` 的決定照舊）。
- 首頁放第二個數字（p50、趟次、捷運重疊、換休息試算）、排序、篩選、搜尋、排行榜。
- 用顏色或門檻標示數字的好壞（`route-page-charts`、`01-route-page-visual-refresh`、`02-route-page-mobile-first`、`run-time-vs-cycle` 的非目標照舊）。
- 改 `RoutePage::LayoverStats` 的 SQL 定義、`analysis/`、衍生表、`bin/health-card`。
- 投票呼籲、黑客松標章、候選人或政見的任何元素（`home-origin-story`、`site-easter-eggs` 的決定照舊）。
- 404 頁與 400 回應的 title 與分享文字；全路網、其他路線、排程與部署。

## Decisions

### 路線頁的 title 是「路線名｜站名」，只在涵蓋到資料時設

涵蓋到資料時（`@coverage.data?`），路線頁用 `content_for :title` 設成最新涵蓋那一天的路線名、全形直線「｜」、站名，例如「中山幹線｜折返點 TurnAround」、「307｜折返點 TurnAround」。路線名取 `route_days.route_name`，有成員路線的頁只用頁面路線的名字，不列成員。選的那一天沒有資料、路線還沒有任何資料時不設，layout 退回站名，`site-layout` 既有的情境「9001 沒有資料時 title 是站名」不變。`og:title` 與 `twitter:title` 不另外設，沿用 layout 讀 `content_for(:title)` 的做法，跟 `<title>` 相同。

理由：分頁、書籤、搜尋結果與分享預覽的標題都要先看到路線；站名留在後面，`site-layout` 的「title 帶站名」照舊成立。只用路線名不加起迄，是因為起迄已經在分享文字的開頭，title 太長在分頁與預覽上會被截掉路線名以外的部分。

替代方案：

- title 帶起迄「中山幹線 天母－青年公園｜折返點 TurnAround」：否決，預覽與分頁會截斷，起迄放進說明文字。
- 沒有資料時也設「路線名｜站名」：否決，那一頁沒有路線名可讀（`route-page` 的「Selected day not stored」情境連標題都不顯示），而且 `site-layout` 既有情境要改。

### 分享文字由 RoutePage::SharePreview 組，數字取自摘要用的同一個 LayoverStats 列

新增查詢物件 `RoutePage::SharePreview`，建構時收 `coverage`（`RoutePage::Coverage`）、`route_days`（涵蓋的 route days）、`layover_stats`（頁面已經建好的 `RoutePage::LayoverStats`）、`ends`（`RoutePage::Ends`），提供 `title` 與 `description` 兩個字串。`show.html.erb` 在建好 `layover_stats` 之後建它，用 `content_for :title` 與 `content_for :description` 交給 layout；layout 在 view 之後才渲染，所以在模板中段設沒有問題。

`description` 的組法（tw；en 見「文案」）：

1. 起迄：`%{departure}－%{destination}`，取最新涵蓋那一天。
2. 涵蓋：`range` 是 `day` 時「%{day}%{day_type}」，例如「2026-10-22（四）平日」；是 `7d` 時「到 %{day}為止的最近 7 天，%{day_type} %{count} 天」，`count` 是涵蓋的 route days 數，例如「到 2026-10-22（四）為止的最近 7 天，平日 4 天」。
3. 停車端：每一個停車端（`ends.stopping_go_backs`）各一句，取 `layover_stats.rows` 裡那個方向的列。有折返停留時「停車端%{stop}：量到 %{count} 次折返停留，中位數 %{p50} 分鐘，%{share} 不到 15 分鐘」；筆數 0 時「停車端%{stop}：折返停留 0 次」。兩端都停車時兩句用「；」接。沒有停車端時這一段是「兩端都是直接折返，沒有停車的一端」。
4. 句尾：「折返停留是駕駛休息的上限，不是工時。」

整句是「%{起迄}，%{涵蓋}：%{停車端}。%{句尾}」。中山幹線 2026-10-22 當天：「天母－青年公園，2026-10-22（四）平日：停車端職能發展學院二：量到 36 次折返停留，中位數 14.7 分鐘，52.8% 不到 15 分鐘。折返停留是駕駛休息的上限，不是工時。」307 當天兩端各一句，用「；」接。數字的格式用「分鐘、比例與日期的格式搬到 RoutePage::Format」那一套，所以 p50 是一位小數、比例是一位小數的百分比，跟摘要與折返停留表相同。字串放 `config/locales/tw.yml` 與 `en.yml` 的 `share_preview` 底下。

理由：分享文字是頁面以外第一個會被看到的數字，要跟頁面上的重點數字出自同一個物件，不能在模板裡另外算；寫成查詢物件可以用 RSpec 直接測每一種組合。數字前面先寫路線與涵蓋，是因為預覽會截斷，讀的人至少要知道這是哪條線、哪幾天。筆數跟比例一定一起出現，一天的樣本少，讀的人看得到分母。

替代方案：

- 在 `show.html.erb` 用 ERB 拼字串：否決，分支多（一端、兩端、沒有停車端、筆數 0、兩種範圍），模板裡測不到。
- 做成 ViewComponent 再 `render_to_string`：否決，輸出的是 head 用的純字串，不是 HTML。
- 只放一端、不放中位數：否決，摘要的兩個重點數字就是這兩個，分享文字少一個會變成另一種摘要。

### layout 的三個 description 標籤讀 content_for(:description)，沒設時退回站的描述

`meta name="description"`、`og:description`、`twitter:description` 的 `content` 都改成 `content_for(:description) || t("site.description")`，三個永遠相同。首頁與沒有資料的路線頁不設，所以照舊是站的描述。`og:url`、`og:image`、`og:site_name`、`twitter:card` 不動。

理由：跟 `content_for(:title)` 同一個做法，頁面只決定自己的字，標籤由 layout 統一輸出；三個描述相同，LINE、Facebook、Threads 與搜尋結果看到的是同一句。

替代方案：`og:description` 跟 `meta name="description"` 分開給不同的字：否決，沒有理由讓分享與搜尋看到不同的話。

### 首頁每張路線卡放每個停車端最新一天的不到 15 分鐘比例與筆數

**Supersedes**: home-page / 首頁不放指標、只放涵蓋，日期全從 route_days 讀

舊決定裡「不放指標」那一半推翻，其餘照舊：日期仍全從 `route_days` 讀、首頁不暗示更新頻率、不放其他數字。每張有資料的卡在「最新資料 %{day}%{day_type}」那一行之後，加一個標題「停車端停不到 15 分鐘的比例」，底下每個停車端一行：比例（`share` 的格式，沒有折返停留時是「—」）接「%{stop}・共 %{count} 次折返」。兩端都停車的 307 有兩行，各標那一端的末站。沒有停車端的路線那一塊只有一句「兩端都是直接折返，沒有停車的一端」。沒有資料的卡不變。數字取那條路線最新一天，也就是卡連到的 `/routes/<Id>` 預設顯示的那一天，所以卡上的比例、筆數、末站跟點進去之後摘要「停車端停不到 15 分鐘的比例」那張卡一字不差。清單下方的說明多一句，寫這個數字是什麼、折返停留是休息的上限。

理由：舊決定的理由是「數字只住在路線頁，旁邊才有定義與資料限制」。這裡放的數字帶末站與筆數，首頁本來就有資料限制那一塊寫「折返停留也只是駕駛休息時間的上限」，清單的說明再寫一次；點進去的第一屏就是同一個數字與它的連結，定義在一步之內。首頁是投票的人唯一一定會看到的頁，現在整頁沒有一個網站自己量到的結果。只放這一個數字，是因為它是三樣交付物裡「折返點實際能休幾分鐘」最直接的答案，p50 與趟次留在頁面上。

`home-page` 的兩條「首頁放任何指標」非目標由下一條決定標成已推翻；「不會出現第二套定義」仍然成立，見「首頁的數字用 HomePage::StopEndFigures 一次查詢」那一條。`day-types`、`home-origin-story`、`02-route-page-mobile-first`、`ui-touchups` 引用舊決定的非目標各自的範圍不變，它們不做的事這裡也沒有做。

替代方案：

- 放中位數而不是比例：否決，比例帶門檻 15 分鐘，一眼就對得上法規那個數字，而且報導講的就是停不到 15 分鐘。
- 放最近 7 天的數字：否決，卡連到的頁預設是最新一天，卡上的數字要跟點進去看到的相同；7 天的樣本比較多，但要換掉卡的連結或預設範圍，超出範圍。
- 維持不放：是使用者在 `/spectra-discuss` 選的 A 方案裡接受推翻的那一項。

### 首頁「不放任何指標」的非目標改成只放這一個數字

**Supersedes**: home-page / 首頁放任何指標：趟次、p10、達成率都不放。數字只住在路線頁，旁邊才有定義與資料限制；`route-page-charts` 的決策「不會出現第二套定義」在這裡一樣成立。

`home-page` 的 proposal 與 design 各有一條「首頁放任何指標」的非目標（design 那條只有一句「首頁放任何指標。」），講的是同一件事，都由上一條決定推翻：首頁放且只放每張卡的這一個數字，趟次、p10、達成率、捷運重疊照舊不放。這一條另立出來，是讓 `spectra decisions` 能把 proposal 那條非目標標成已推翻；design 那條字串太短，分析器對不到，這裡記下它一併失效。

### 首頁的數字用 HomePage::StopEndFigures 一次查詢，共用 LayoverStats 的分鐘算法與門檻，一致性用測試鎖住

新增 `HomePage::StopEndFigures`，建構時收最新一天的 route day 清單（`HomePage::RouteList` 已經查到的那些列），一次 SQL 算出每個 route day 每個方向的末站、筆數與不到 15 分鐘的比例：末站是 `route_day_stops` 裡 `route_day_id` 在清單內、`route_id` 等於那個 route day 的 `route_id` 的列，每個方向 `seq` 最大的一筆（跟 `LayoverStats` 的 `last_stops` 同一個取法，成員路線的站序不算）；分鐘與比例用 `RoutePage::LayoverStats` 抽出來的同一段 SQL 與同一個 `SHORT_MINUTES`。查詢不碰 `route_days`（route day 與路線 Id 的對應用參數帶進去），所以 `home-page` 的「只對 route_days 發一次 SELECT」照舊成立。`HomePage::RouteList::Entry` 多一個 `figures`：那條路線停車端（`RoutePage.ends(route_id).stopping_go_backs`）的列，依方向排序；沒有資料的路線是空的。

一致性測試：同一個 route day 的停車端，`StopEndFigures` 給的末站、筆數、比例要等於 `RoutePage::LayoverStats.new(RouteDay.where(id:)).rows` 對應的列；再加一個請求層級的測試，首頁卡上那一行的文字等於路線頁摘要 `[data-key-number=short-share]` 對應那一行的數字與文字。

理由：`LayoverStats` 一次只算一頁（把涵蓋的日子合在一起），首頁要的是每條路線各自最新一天，逐路線建 `LayoverStats` 就是逐路線查詢，路線多了就是 N 次。把分鐘算法與門檻抽成常數共用，加上一致性測試，定義仍然只有一份。

替代方案：

- 逐路線呼叫 `LayoverStats`：否決，四條路線四次查詢，全路網時變成幾百次。
- 把 `LayoverStats` 改成可以 `GROUP BY route_day_id`：否決，頁面那邊是把多天合起來算，兩種分組塞進同一個物件會讓兩邊都難讀。

### 卡仍是一個連到路線頁的連結，數字的定義在點進去的第一屏

卡維持一個 `<a href="/routes/<Id>">`，新加的數字在連結裡面，不另外連到 `#layovers`。`/spectra-discuss` 的結論寫「連到路線頁折返停留那一區」，這裡改成連到路線頁：HTML 不能在連結裡再放連結，而摘要的重點數字就在頁面第一屏、本身連到 `#layovers`，定義距離卡一步。

替代方案：整張卡改連 `/routes/<Id>#layovers`：否決，跳過頁首的涵蓋範圍與日型別切換，讀的人不知道自己在看哪幾天。

### 文案

卡上的三個字串跟摘要的相同，各放在自己元件的 `.yml`（sidecar 翻譯跨不了元件），用測試鎖住兩份相同：

- `route_list_component.yml` 新增 `short_share: "停車端停不到 %{minutes} 分鐘的比例"`、`short_count: "%{stop}・共 %{count} 次折返"`、`no_stopping_end: "兩端都是直接折返，沒有停車的一端"`，tw 與 en 的值逐字等於 `route_summary_component.yml` 同名的鍵（zh-TW 沿用 `<<: *tw`）。
- `route_list_component.yml` 的 `note`，tw 改成「每條路線都要先用它自己的資料確認過趟次、折返停留這些算法沒問題，才會有頁面。卡上的比例是最新那一天停車端量到的折返停留裡不到 15 分鐘的比例，折返停留是駕駛休息的上限，不是工時。」，en 改成 "A route gets a page only after its definitions have been checked on its own data. The share on each card is the share of the measured layovers at the stopping end that were under 15 minutes on the latest day; a layover is an upper bound on the driver's rest, not working time."
- `config/locales/tw.yml` 新增 `share_preview`：`title: "%{route_name}｜%{site_name}"`、`coverage_day: "%{day}%{day_type}"`、`coverage_7d: "到 %{day}為止的最近 7 天，%{day_type} %{count} 天"`、`stopping_end: "停車端%{stop}：量到 %{count} 次折返停留，中位數 %{p50} 分鐘，%{share} 不到 %{minutes} 分鐘"`、`stopping_end_without_layovers: "停車端%{stop}：折返停留 0 次"`、`no_stopping_end: "兩端都是直接折返，沒有停車的一端"`、`ends_separator: "；"`、`description: "%{span}，%{coverage}：%{ends}。%{bound}"`、`bound: "折返停留是駕駛休息的上限，不是工時。"`、`span: "%{departure}－%{destination}"`。
- `config/locales/en.yml` 同一組鍵：`title: "%{route_name} | %{site_name}"`、`coverage_day: "%{day}, %{day_type}"`、`coverage_7d: "the last 7 days up to %{day}, %{count} %{day_type} days"`、`stopping_end: "stopping end %{stop}: %{count} layovers measured, median %{p50} min, %{share} under %{minutes} min"`、`stopping_end_without_layovers: "stopping end %{stop}: 0 layovers"`、`no_stopping_end: "Buses drive straight on at both ends; neither end is a stopping end"`、`ends_separator: "; "`、`description: "%{span}, %{coverage}: %{ends}. %{bound}"`、`bound: "A layover is an upper bound on the driver's rest, not working time."`、`span: "%{departure}–%{destination}"`。

理由：卡與摘要說同一件事就用同一句話；兩份 `.yml` 各自維護是 ViewComponent 的限制，測試補上「不能漂」。`no_stopping_end` 在摘要與分享文字裡是同一句，所以分享文字那一份也逐字相同。

### 分鐘、比例與日期的格式搬到 RoutePage::Format

`ApplicationComponent#minutes`、`#share`、`#day_label` 的實作搬到新的模組 `RoutePage::Format`（`module_function`，三個方法的名字與行為不變），`ApplicationComponent` 的三個方法改成委派給它，`RoutePage::SharePreview` 直接呼叫模組。`ApplicationComponent::NONE` 與 `::WEEKDAYS` 兩個常數留在類別上、值取自模組，因為 `load_chart_component.html.erb` 直接寫 `NONE`，靠元件類別的常數查找（2026-10-25 grep 過，其他用到 `NONE`、`WEEKDAYS` 的檔各有自己的定義）。`application_component_spec.rb` 既有的四個格式例子不改，照舊通過。

理由：分享文字不是元件，拿不到元件的 helper；複製三個格式字串就是第二份格式，之後改一邊漏一邊。

替代方案：`SharePreview` 自己寫 `format("%.1f%%")`：否決，理由同上。

### 詞彙表：首頁條目改寫，新增「分享預覽」

`docs/spectra/LANGUAGE.md`「首頁」的定義加上「與那一天每個停車端不到 15 分鐘的比例」，邊界那句「首頁只列出涵蓋到哪一天，不放任何指標數字」改成「首頁放且只放一個數字：每張有資料的卡上，每個停車端最新一天折返停留裡不到 15 分鐘的比例與筆數，跟路線頁摘要的重點數字相同；p50、趟次、捷運重疊這些不放」。「顯名聲明」之後新增一條「分享預覽」：定義是轉貼網址時 LINE、Facebook、Threads 顯示的標題、說明與圖，以及瀏覽器分頁與搜尋結果用的 title；在程式碼裡是 layout 的 `<title>`、`meta name="description"`、`og:*`、`twitter:*`，路線頁的字由 `RoutePage::SharePreview` 組，首頁與沒有資料的路線頁用 `site.name` 與 `site.description`；邊界是只有涵蓋到資料的路線頁有自己的標題與說明、圖一律是通用的分享圖、說明裡的數字跟摘要的重點數字相同並帶筆數與「休息的上限」；不要用：OG 卡、社群卡、meta 標籤（單獨出現時分不出是哪一個）。

`home-page` 規格的 Purpose 寫「shows no metric」，delta 規格改不到 Purpose，apply 時直接把 `docs/spectra/specs/home-page/spec.md` Purpose 那一句改成「shows one figure per route and no other metric」。

## Implementation Contract

**行為**：

- `GET /routes/<Id>`，選的那一天有資料：`<title>`、`og:title`、`twitter:title` 是「<最新涵蓋那一天的路線名>｜折返點 TurnAround」；`meta name="description"`、`og:description`、`twitter:description` 是「分享文字由 RoutePage::SharePreview 組」那一節定義的那一句，三個相同。帶 `range=7d` 時涵蓋那一段用 7 天的寫法。
- `GET /routes/<Id>`，選的那一天沒有資料或路線沒有任何資料：六個標籤跟首頁相同，是站名與 `site.description`。
- `GET /`：六個標籤不變。每張有資料的路線卡多一塊：標題「停車端停不到 15 分鐘的比例」，每個停車端一行，比例接「末站・共 N 次折返」；沒有停車端時一句「兩端都是直接折返，沒有停車的一端」。卡仍然只有一個連結，連到 `/routes/<Id>`。清單下方的說明是「文案」那一句。

**介面與資料形狀**：

- `RoutePage::Format.minutes(value)`、`.share(value)`、`.day_label(day)`：跟 `ApplicationComponent` 既有的三個方法同名同行為。
- `RoutePage::SharePreview.new(coverage:, route_days:, layover_stats:, ends:)`，`#title` 與 `#description` 回傳 `String`；只在 `coverage.data?` 為真時建立。
- `HomePage::StopEndFigures.new(route_days)`（最新一天的 route day 列），`#rows` 回傳 `Row = Data.define(:route_day_id, :go_back, :stop_name, :n_layovers, :short_share)`，依 `route_day_id`、`go_back` 排序，每個 route day 每個有站序的方向一列，沒有折返停留時 `n_layovers` 是 0、`short_share` 是 `nil`；整個物件只發一次 SQL，SQL 不讀 `route_days`。
- `HomePage::RouteList::Entry` 加 `figures`：`StopEndFigures::Row` 的陣列，只含那條路線的停車端，依 `go_back` 排序；沒有資料的路線是 `[]`。
- `RouteListComponent` 卡上的新區塊：`[data-figure="short-share"]`，每行 `[data-end="<go_back>"]`，比例在 `[data-number]`；沒有停車端時 `[data-no-stopping-end]`。
- layout：三個 description 標籤的 `content` 是 `content_for(:description) || t("site.description")`。

**失敗模式**：

- 停車端那天沒有折返停留：分享文字寫「折返停留 0 次」，卡上比例「—」、「共 0 次折返」；不丟錯。
- 最新一天沒有站序（`route_day_stops` 空）：那個方向沒有列，卡上與分享文字都略過那一端（跟摘要相同：沒有列就沒有那一行）。
- 路線名含 HTML 特殊字元：`content_for` 與 ERB 屬性輸出照舊跳脫。
- 格式與日型別的錯誤處理不變（`day_type_label` 缺日型別仍丟 `ArgumentError`）。

**驗收**：

- 新增 `spec/models/route_page/share_preview_spec.rb`（一端、兩端、沒有停車端、筆數 0、`7d`、en 的字串）、`spec/models/home_page/stop_end_figures_spec.rb`（列的形狀、只發一次 SQL、不讀 `route_days`、跟 `LayoverStats` 一致）。
- `spec/requests/routes_spec.rb` 新增 title 與六個標籤的例子（有資料、沒有資料、`7d`）；`spec/requests/site_layout_spec.rb` 新增首頁六個標籤是站名與站的描述；`spec/requests/pages_spec.rb` 與 `spec/components/route_list_component_spec.rb` 新增卡上數字、兩端、沒有停車端、沒有折返停留、沒有資料的卡不變，以及首頁那一行跟路線頁摘要相同的例子；`spec/models/home_page/route_list_spec.rb` 新增 `figures` 與「仍只對 route_days 發一次 SELECT」。
- 既有測試全綠：`application_component_spec.rb` 的格式例子、`site_layout_spec.rb` 的「9001 沒有資料時 title 是站名」、`route_summary_component_spec.rb`。
- `bin/rails parallel:spec` 全綠；對這次改到的檔跑 `bin/rubocop`。
- 畫面：`bin/dev` 開 `/`，1280 與 390 寬各截一張給使用者看卡的新區塊（兩端都停車的 307、一端的中山幹線）；主觀的「好不好看」由使用者判斷。

**範圍**：

- 在範圍內：layout 的三個 description 標籤；`show.html.erb` 的兩個 `content_for`；`RoutePage::SharePreview`、`RoutePage::Format`、`HomePage::StopEndFigures`；`HomePage::RouteList::Entry#figures`；`RouteListComponent` 的新區塊與文案；兩個全域翻譯檔的 `share_preview`；`PagesController` 的註解；詞彙表與 `home-page` 規格的 Purpose 一句；上面列的測試。
- 不在範圍內：Non-Goals 列的每一項；`RouteSummaryComponent` 與 `LayoverTableComponent` 的輸出；`RoutePage::LayoverStats` 的 SQL 結果。

## Risks / Trade-offs

- [LINE、Facebook 會快取分享預覽，deploy 之後舊的預覽可能留一陣子] → Facebook 的分享偵錯工具可以重新抓；LINE 沒有公開工具，等它過期。這是平台的行為，不是程式的問題。
- [分享文字超過預覽的顯示長度被截斷] → 路線與涵蓋寫在最前面，數字在中段，句尾才是限定詞；307 兩端各一句最長，2026-10-22 當天那句數出來是 144 個字（量到的）；LINE 的預覽大約顯示前 100 個字是估計值，沒有實測，實測方法是 deploy 之後把網址貼進 LINE 看截在哪裡。就算截在 100 個字，第一端的筆數與比例已經在前 70 個字裡。
- [一天的筆數少，比例跳動大] → 筆數永遠跟比例一起出現；清單說明寫明取最新一天。
- [全路網之後首頁卡變多，`StopEndFigures` 的查詢要掃更多 `layovers`] → 一次查詢、`route_day_id IN (...)` 走既有索引；全路網那個 change 再量。
- [`timetable-draft` 之後可能也改 layout 與兩個請求測試檔] → 這裡的改動都是加標籤與加例子，apply 時用 `--file` 記下改到的檔，commit 前對一次 `git diff`。

## Migration Plan

- 只要 deploy，不用重跑 `derived:load`、不用 `bin/push-derived`。
- deploy 之後用 `curl -s https://bus.5xcamp.us/routes/15373 | grep -E "<title>|og:title|og:description"` 看正式站的標籤；Facebook 的分享偵錯工具重新抓一次。
- 退回：還原這個 change 的 commit 即可，沒有資料或 schema 的變動。

## Open Questions

（無）
