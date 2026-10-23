## 1. 首頁區塊順序的測試（先失敗）

- [x] 1.1 `spec/requests/pages_spec.rb` 改成「Home page content and order」新的兩個情境：區塊順序的例子期待 `%w[hero origin routes limitations sources]`（照設計「起點區塊放在 hero 與路線清單之間」）；不跑 script 的例子多數一個選擇器，起點區塊裡連到 `OriginStoryComponent::ARTICLE_URL` 的連結恰好一個，例子的說明字串跟著改。兩個例子都維持 `RSpec/ExampleLength` 的 5 行以內。驗證：`bundle exec rspec spec/requests/pages_spec.rb` 這兩個例子失敗（首頁還沒有起點區塊，常數也還不存在），其餘例子照舊通過。

## 2. 起點區塊元件的測試（先失敗）

- [x] 2.1 新增 `spec/components/origin_story_component_spec.rb`，涵蓋「Origin story block」的五個情境，只測元素與屬性、不斷言固定文案：清單每列依序是 `time[datetime]` 06:50、09:50、`li[data-interval]`（裡面沒有 `time`）、10:00；恰好一個連到 `OriginStoryComponent::ARTICLE_URL` 的連結，以及一個 `time[datetime="2026-07-31"]`；`RoutePage.route_ids` stub 成 `[ 15373, 9001 ]` 時有 `href` 為 `/routes/15373#layovers` 與 `/routes/15373#buffer` 的兩個連結；stub 成 `[ 9001 ]` 時沒有任何 `href` 以 `/routes/15373` 開頭的連結，清單與原文連結還在；render 時訂閱 `sql.active_record`，去掉 SCHEMA 之後的查詢數是 0（照設計「報導引用的時刻、日期與間隔不算首頁的指標」：區塊不讀網站的任何資料）。驗證：`bundle exec rspec spec/components/origin_story_component_spec.rb` 因為 `OriginStoryComponent` 還不存在而失敗。

## 3. 起點區塊元件

- [x] 3.1 新增 `app/components/origin_story_component.yml`，`tw`（anchor）、`zh-TW`、`en` 三組，照設計「文案規則：用自己的話、只引用兩句、不寫成合作、不把推論寫成他說的」與「只講報導本身，不放後續、政見與公運處的回應」，以設計稿 `Story.dc.html` 的文字為底稿：小標、引篇名的標題、一段內文、卡片標題（寫出 06:30 到站與 20:30 下班）、「發車」與「回站」、「10 分鐘」、引句、兩個按鈕、出處的前綴與篇名。`en` 是我們的翻譯，出處裡的篇名保留中文原文。驗證：內容審閱，逐條對照文案規則：只有兩句直接引用；沒有「後續」一節的內容；沒有「合作」「與」「一起」這類字；我們自己的句子沒有「趟」；「回站」沒有補站名；全篇用「駕駛」。
- [x] 3.2 新增 `OriginStoryComponent`（`app/components/origin_story_component.rb` 與 `.html.erb`），照設計「元件 OriginStoryComponent：文案放 yml，原文網址與路線 Id 放 Ruby 常數」：常數 `ARTICLE_URL`、`ROUTE_ID = 15373`，方法 `route_links?` 與 `route_section_path(anchor)`；輸出 `section[data-section="origin"]`，時刻卡照設計「時刻卡只列 06:50、09:50、10:00 與中間的 10 分鐘，06:30 與 20:30 寫進卡片標題」，兩個按鈕照設計「兩個路線頁連結只在路線清單設定有 15373 時出現」；class 照設計文件 Design Source 表。驗證：2.1 的五個例子全部通過；版面在 7.1 對照設計稿檢查。[after: 2.1, 3.1]

## 4. 放進首頁

- [x] 4.1 `app/views/pages/home.html.erb` 在 `HomeHeroComponent` 與 `RouteListComponent` 之間 render `OriginStoryComponent.new`，讓 `GET /` 的區塊順序符合「Home page content and order」（照設計「起點區塊放在 hero 與路線清單之間」）。驗證：1.1 的兩個例子通過，`bundle exec rspec spec/requests/pages_spec.rb` 全部通過。[after: 1.1, 3.2]

## 5. 詞彙表

- [x] 5.1 照設計「LANGUAGE.md 的「首頁」與「趟次與班次」兩條跟著改」更新 `docs/spectra/LANGUAGE.md`：改之前重讀整份檔案（2026-10-23 剛整份改寫過句子）；「首頁」的定義加上交代網站從哪篇報導開始，邊界補上報導引用的時刻、日期與間隔不算指標、只出現在起點區塊；「趟次與班次」的邊界補上「一趟」是一個來回、等於兩個趟次的例子。兩條都維持每條四行的格式。驗證：內容審閱，`git diff docs/spectra/LANGUAGE.md` 只動到這兩條。

## 6. 自動檢查

- [x] 6.1 對這次新增或修改的 Ruby 檔跑 `bin/rubocop app/components/origin_story_component.rb spec/components/origin_story_component_spec.rb spec/requests/pages_spec.rb`，沒有 offense；再跑 `bin/ci`。驗證：兩個指令都成功結束，`bin/ci` 的平行 RSpec 全部通過。[after: 4.1]

## 7. 人工確認

- [x] 7.1 用 `bin/dev` 開首頁，在 390px 與 1280px 寬對照設計稿畫布的 `Phone.dc.html` 與 `Main.dc.html`（快取在 `.spectra/design-cache/home-origin-story/`）：起點區塊在 hero 與路線清單之間；1280px 是兩欄、時刻卡在右，390px 依序是內文、時刻卡、按鈕、出處；09:50 與 10:00 是 teal、間隔列有底色；按鈕至少 44px 高；記下兩種寬度下區塊的實際高度，跟設計文件 Goals 的估計值比較。驗證：使用者看過畫面，確認跟設計稿一致。[after: 4.1]
- [x] 7.2 使用者用瀏覽器打開 `https://futurecity.cw.com.tw/article/4090`，照設計「文案規則：用自己的話、只引用兩句、不寫成合作、不把推論寫成他說的」逐項核對：篇名、「我也開始搶黃燈了！」、「幾乎只能跑步去上廁所」、06:30、06:50、09:50、10:00、20:30、2025 年暑假、光華巴士、中山幹線、陽明交大碩士生。對不上的改 `app/components/origin_story_component.yml`，結構不動。驗證：使用者回報每一項的核對結果；改過文案的話，`bundle exec rspec spec/components/origin_story_component_spec.rb` 仍然通過。[after: 3.2]
