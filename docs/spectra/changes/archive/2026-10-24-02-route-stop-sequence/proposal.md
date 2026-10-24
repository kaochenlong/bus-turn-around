## Why

這個 change 服務三樣交付物的第一樣：路線健檢卡在網站上的路線頁，以及列出路線頁的首頁。它不需要新的資料：站序與站名已經在衍生表 `route_day_stops`（每個路線日一份，取自那一天公運處靜態 feed 的 `GetStop.gz` 快照），兩端的折返方式已經寫在 `config/route_page.yml`。這個 change 不新增 DuckDB 階段、不讀原始檔、不動資料表。

2026-10-24 討論「折返點」時，查到讀者會在三個地方卡住：

- 路線頁沒有地方讓人看懂這條路線怎麼跑。每一站其實都在載客剖面那張卡最下面、預設收起的逐站表裡（251區 有 91 列，量到的），但那張表的標題是「逐站數字：載客剖面表」，想找站的人不會點開它。習慣把一個來回想成「開一圈回到出發點」的讀者，也看不出折返點在哪兩個地方、哪一端車會停。
- 折返停留那張卡的標題「車在終點能停幾分鐘？」用了「終點」。這個詞在 `docs/spectra/LANGUAGE.md`「起站、末站、折返點、調度站」那條列為不要用。用「一圈」來想的讀者，會把終點讀成最遠那一頭，那正好是車不停的那一端（251區 的捷運公館站端，折返停留中位數 2.8 分鐘，2026-10-22 量到的）。
- 路線頁標題與首頁路線卡在名稱後面直接接著路線 Id，例如「251區 11764」，沒有任何標示。讀者認得的是「251區」，分不出後面那串數字是什麼。

為什麼是現在：Demo 審核 2026-10-24 下午截止。標題與路線 Id 是審核的人第一眼就會看到的，交件前先改；站序區塊會動到三個路線頁的版面，交件後再做。

## What Changes

- 折返停留那張卡的標題「車在終點能停幾分鐘？」改成「車在折返點能停幾分鐘？」，跟首頁標題「折返點實際能休幾分鐘？」用同一個詞。英文 “How long does a bus stay at the end of the line?” 改成 “How long does a bus stay at the turnaround?”，跟首頁英文標題的 turnaround 一致。
- 路線 Id 只出現一次，而且加上標示。路線頁標題只放路線名稱，路線 Id 移到起迄那一行後面，寫成「路線 Id 11764」，小字灰色。首頁路線卡同樣處理。還沒有資料的路線卡沒有名稱可放（名稱來自 `route_days`），照舊只顯示 Id，但一樣加上「路線 Id」。網址 `/routes/<Id>` 不變。
- 路線頁新增「站序」區塊，自己一張卡，放在區塊導覽之後、折返停留之前，三個路線頁共用：
  - 標題用問句「這條路線停哪些站、在哪裡折返？」。標題底下是一個預設收起的 details，摘要寫兩個方向各幾站。
  - 展開後依方向列出涵蓋日子裡最新那一天的站序：去程、返程各自從起站列到末站，第一站標「起站」、最後一站標「末站」，不印站序號碼。
  - 每個方向的末站後面多一列寫那一端的折返方式，用跟折返停留表同一個標籤（停車或開過去就走），並寫出下一趟從哪一站出發，也就是另一個方向的起站。
  - 區塊最後一句寫站序取自哪一天。
- 詞彙表 `docs/spectra/LANGUAGE.md` 補「站序」一條。這個詞在詞彙表裡到處在用，卻沒有自己的定義；「停靠站」列為不要用。「路線」那條的邊界補一句：畫面上要給路線 Id 時寫成「路線 Id 11764」，放在起迄之後，不接在名稱後面。

資料限制與假設：

- 站序是靜態快照，不是量到的。每個路線日一份，涵蓋好幾天時只列最新那一天的；如果這幾天裡改過站序，區塊上只看得到最新的版本，所以區塊要寫出取自哪一天。
- 這個區塊不用車上人數，也不用任何事件，所以「車不等於人」、刷卡率、漏站、跨小時重複都跟它無關。
- 折返方式是逐路線人工查證後寫進設定的事實（`turnaround-ends`），不是從資料算的。業者改了折返的方式，設定就會過期，區塊也跟著過期；這一條已經寫在路線頁的資料限制裡。
- 「下一趟從哪一站出發」取另一個方向的起站，不逐筆去查下一趟是哪個方向，跟 route-page-charts 的決定「圖的標題寫「末站 → 下一趟起站」，起站取另一個方向的起站」同一個取法。

## Non-Goals

- 標出 251區 跟 251 共用哪些站，或讓兩頁互相連結。這樣做會推翻 route-251-pages 的決定「251區 當成獨立的路線，不跟 251 配對」，那條的理由是 251區 跟 251 的關係還沒定義。
- 把站牌或路線形狀畫上地圖。turnaround-map 的非目標寫了「沿線的事在載客那張卡」，那張圖只回答折返點附近的問題；這裡的站序是文字清單，不碰地圖。
- 在站序上標出靠近捷運的站：載客剖面圖的底色與捷運重疊那一段已經有了。
- 區塊導覽加「站序」的連結：區塊就在導覽正下方，連結沒有用處。
- 改逐站表：它照舊印站序號碼，照舊收在載客剖面那張卡裡。
- 修 `RoutePage::LayoverStats`、`RoutePage::LayoverDistribution`、`RoutePage::LoadProfile`、`RoutePage::MrtOverlap` 在 7 天範圍取「最新一天」時取到最早那天的已知問題：另開 change。這個 change 的新查詢不沿用它們的寫法。
- 307 把兩個路線 Id 合成一頁之後，Id 那一行怎麼寫兩個 Id：由 307 的 change 決定。
- 網址改用路線名稱或其他代號。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `route-page`：新增站序區塊（Stop sequence block）與路線名稱和 Id 的顯示方式（Route name and Id in the header）；Page content 的區塊順序加上站序區塊。
- `home-page`：Route list 的路線卡，名稱後面不再接 Id，Id 加上「路線 Id」標示、放在起迄之後；沒有資料的卡顯示帶標示的 Id。

## Impact

- 修改 app/components/layover_chart_component.yml（標題，tw 與 en）。
- 修改 app/components/route_coverage_component.html.erb 與 app/components/route_coverage_component.yml（標題只放名稱，起迄那一行加上路線 Id）。
- 修改 app/components/route_list_component.html.erb 與 app/components/route_list_component.yml（路線卡同上，包含沒有資料的卡）。
- 新增 app/models/route_page/stop_sequence.rb（查詢物件）、app/components/stop_sequence_component.rb 與同層的 app/components/stop_sequence_component.html.erb、app/components/stop_sequence_component.yml。
- 修改 app/views/routes/show.html.erb（在區塊導覽之後 render 站序那張卡）。
- 修改 docs/spectra/LANGUAGE.md（「站序」一條，「路線」那條補一句）。
- 測試：新增 spec/models/route_page/stop_sequence_spec.rb 與 spec/components/stop_sequence_component_spec.rb；修改 spec/components/route_coverage_component_spec.rb、spec/components/route_list_component_spec.rb、spec/requests/pages_spec.rb、spec/requests/routes_spec.rb（區塊順序）。
- 跟進行中的 change 的關係：turnaround-facilities 與 turnaround-map 也都改 route-page 的 Page content。這個 change 的 Page content 以 turnaround-facilities 的版本為底，所以站序區塊的任務要等 turnaround-facilities archive 之後才開始，而且這個 change 要在它之後 archive。turnaround-map 若先 archive，Page content 要先以新的版本為底重寫，再 archive 這個 change。標題與路線 Id 兩個任務不碰 Page content，交件前可以先做。
- 不新增相依套件，不動資料表、衍生表與 DuckDB 階段。
