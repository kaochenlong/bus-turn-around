## Context

路線頁把每一條路線的兩端標成兩種性質之一：`stop`（車停在這裡等下一趟）或 `pass_through`。`pass_through` 的中文標籤是「開過去就走」，由 `zhongshan-turnaround-ends` 的決定「頁面上每一端標出性質：文案用「停車」與「開過去就走」，程式用 stop 與 pass_through」定下，理由是「讀頁面的司機與站長一看就懂」。

2026-10-24 使用者說這個詞他一直搞不清楚。查下來，誤會有兩個來源：

- 標籤本身聽起來像過站不停。實際上這一端的車會在末站停靠讓乘客下車，只是不停下來等發車時間，直接開到下一趟的起站。
- 說明句把誤會寫成了事實。中文寫「車到了末站不停」、「不會停下來」、「車在這一端不停」，英文寫 “do not stop at the last stop”、“without stopping”，詞彙表的定義也寫「車到末站不停」。

這個詞目前出現在這些地方（2026-10-24 用 grep 數的）：7 個元件 `.yml` 的 tw 區塊共 10 處（zh-TW 透過 `<<: *tw` 沿用）；13 個測試檔共 32 處，大多是 `it` 的描述，少數是對畫面文字的斷言；`docs/spectra/LANGUAGE.md` 9 處；`docs/background.md` 2 處；`docs/decisions.md`、`README.md`、`analysis/README.md` 各 1 處。規格（`docs/spectra/specs/`）是英文，沒有用這個中文詞，但 `turnaround-ends` 把 `pass_through` 定義成 “drive on … without stopping”，跟中文說明是同一個誤會。

同一天另外有兩個 change 也改到這裡會碰的檔（2026-10-24 看的）：`ui-touchups`（暫存中）改 `spec/components/layover_chart_component_spec.rb` 與詞彙表的「路線頁」條目，它的 proposal 已經寫明分佈圖那一項要等這個 change 改完；`buffer-trade-cost-curve`（提案中）改 `app/components/buffer_trade_component.yml`、`app/components/data_limitations_component.yml`、`spec/models/route_page/buffer_trade_spec.rb`、`spec/components/buffer_trade_component_spec.rb`、`spec/requests/routes_spec.rb` 與詞彙表。

## Goals / Non-Goals

**Goals:**

- 路線頁上的標籤改成「停車」與「直接折返」，讀的人不會再讀成過站不停。
- 每一句說明都寫對：這一端的車會讓乘客下車，只是不停下來等。
- 詞彙表、規格、還在用的文件與測試描述用同一個詞，`grep` 找不到舊詞（詞彙表「不要用」那一行除外）。

**Non-Goals:**

- 改程式識別字、設定值、`data-end-nature` 的值、指標定義、資料表。
- 改英文標籤 “Drives on” 與 “buses drive straight on”。
- 改標籤的樣子（`01-route-page-visual-refresh` 的決定「折返方式改成標籤，兩種同一個樣式」照舊）。
- 改已歸檔的 change、`docs/cards/` 裡已產生的健檢卡。
- 「停車」這個詞。

## Decisions

### 性質的標籤改成「停車」與「直接折返」

**Supersedes**: zhongshan-turnaround-ends / 頁面上每一端標出性質：文案用「停車」與「開過去就走」，程式用 stop 與 pass_through

`pass_through` 的中文標籤從「開過去就走」改成「直接折返」，「停車」不變。舊決定裡其他的部分照舊：每一端都標出性質；折返停留表每一列與分佈圖每個方向的標題都帶 `data-end-nature`；試算那一塊另外報這一端的筆數；文案放在各元件同層的 `.yml`；程式用 `stop` 與 `pass_through`；不用顏色、不標合不合規。

理由：舊決定的理由是「一看就懂」，使用者說看不懂，這個理由已經不成立。「直接折返」講的是折返的方式：到了末站不等，直接回頭開下一趟。它跟「停車」放在一起，讀的人會把兩個詞理解成「停下來等」與「不等」，正是兩者的差別。

替代方案：

- 「不停車」：跟「停車」成對最簡單，但「停車」也能指公車靠站，「不停車」一樣會被讀成過站不停，否決。
- 只改說明句、標籤照舊：標籤是讀者第一眼看到的字，誤會從標籤開始，否決。

### 說明句寫「不停下來等」，不寫「不停」

凡是說這一端的車「不停」的句子，都改成「不停下來等」；說明折返停留為什麼不算休息的那兩句（折返停留表下的說明、試算那一塊），另外寫出車在末站讓乘客下車。英文同樣把 “do not stop” 與 “without stopping” 改成 “do not wait” 與 “without waiting”。逐字內容見「文案」。

理由：車在末站其實有停靠，寫「不停」就是錯的；需要講清楚的是車沒有停下來等。

### 站序區塊那一句拿掉開頭的「折返」

站序區塊每個方向最後那一句原本是「折返 %{nature}，下一趟從 %{next_first_stop} 出發」，換了新標籤會變成「折返 直接折返」，同一個詞連著出現兩次。中文改成「這一端 %{nature}，下一趟從 %{next_first_stop} 出發」，只有性質、沒有下一趟起站時是「這一端 %{nature}」。英文 “Turnaround %{nature}…” 不變。

這兩個字串原本是 `02-route-stop-sequence` 的決定「文案」定的。這裡只改這兩個中文字串，那條決定的其他內容照舊，所以不標 Supersedes。

理由：「這一端」接在末站那一列之後，指的就是末站這一端；去掉重複的詞，句子讀起來是「這一端停車」與「這一端直接折返」。

### 英文標籤不變，只改說它不停的句子

英文的 “Drives on”、“buses drive straight on” 不變。

理由：英文的 drive on 沒有「過站不停」那種讀法；英文錯的是那幾句 “do not stop”。

### 規格只把 pass_through 的定義寫準

`turnaround-ends` 的「Verified end nature per route」把 `pass_through` 從 “drive on to the first stop of the next trip without stopping” 改成 “let passengers off at the last stop and drive on to the first stop of the next trip without waiting there”。這條需求的其他文字與六個情境不變，程式行為也不變。

理由：規格是 apply 與之後的 change 引用的定義，把錯的讀法留在規格裡，下一個寫文案的人會再寫錯一次。

### 詞彙表把舊詞列進不要用

`docs/spectra/LANGUAGE.md`「起站、末站、折返點、調度站」那一條：

- 定義裡的性質寫成「停車（車停在這裡，等下一趟出發）或直接折返（車在末站讓乘客下車後不停下來等，直接開到下一趟的起站）」。
- 在資料或程式碼裡那一行：`pass_through`（直接折返）。
- 邊界與其他條目（「來回一趟」、「換休息試算」）裡的「開過去就走」都換成「直接折返」。「來回一趟」邊界裡「開過去就走的那一端是一兩分鐘的過站」改成「直接折返的那一端只有讓乘客下車、開到下一趟起站的一兩分鐘」，因為「過站」一樣會讀成過站不停。
- 「不要用」那一行的最後加上「開過去就走（舊的說法，聽起來像過站不停；車其實會在末站讓乘客下車）」。

理由：詞彙表是每次 discuss 先讀的檔（它開頭那段的規則），舊詞要留在「不要用」，之後的文件才不會又寫回去。

### 文案

tw 一處改完，zh-TW 透過 `<<: *tw` 跟著變。表裡沒列的字串不動，包括 `stop_sequence_component.yml` 的 `member_note`（那裡的「不停」講的是成員路線不經過某些站，意思正確）。

| 元件 `.yml` | 鍵 | 改成 |
| --- | --- | --- |
| `layover_table_component` | tw `natures.pass_through` | 直接折返 |
| `layover_table_component` | tw `pass_through_note` | 標「直接折返」的那一端，車在末站讓乘客下車後不停下來等，直接開到下一趟的起站，所以那裡的折返停留不算休息。 |
| `layover_table_component` | en `pass_through_note` | At an end marked “Drives on”, buses let passengers off at the last stop and drive straight on to the first stop of the next trip without waiting, so the layovers there are not rest opportunities. |
| `layover_chart_component` | tw `natures.pass_through` | 直接折返 |
| `stop_sequence_component` | tw `natures.pass_through` | 直接折返 |
| `stop_sequence_component` | tw `turnaround_html` | 這一端 %{nature}，下一趟從 %{next_first_stop} 出發 |
| `stop_sequence_component` | tw `turnaround_only_html` | 這一端 %{nature} |
| `buffer_trade_component` | tw `pass_through_html` | 直接折返那一端的 %{layovers} 次折返沒有算進來：車在那裡讓乘客下車後不停下來等，直接開下一趟。 |
| `buffer_trade_component` | en `pass_through_html` | The %{layovers} turnarounds at the end where buses drive on are left out: buses let passengers off there and go straight on to the next trip without waiting. |
| `route_summary_component` | tw `no_stopping_end` | 兩端都是直接折返，沒有停車的一端 |
| `turnaround_facilities_component` | tw `note` | 停車那一端的位置，是那一天車停著等的時候，GPS 顯示最常停的地方；直接折返的那一端車不停下來等，就用末站的位置。公廁資料來自環境部的全國公廁建檔資料，同一個地址的廁所算一處，距離取最近那一間的直線距離。 |
| `turnaround_facilities_component` | tw `natures.pass_through` | 直接折返 |
| `turnaround_facilities_component` | tw `end_stop` | 車在這一端不停下來等，位置就用末站。 |
| `turnaround_facilities_component` | en `note` | 只把 “they do not stop and the location is the last stop” 改成 “they do not wait and the location is the last stop”，其餘不變 |
| `turnaround_facilities_component` | en `end_stop` | Buses do not wait at this end; the location is the last stop. |
| `data_limitations_component` | tw `items` 裡「哪一端會停車」那一項 | 只把「開過去就走那一端的折返停留不算休息」改成「直接折返那一端的折返停留不算休息」，其餘不變 |
| `data_limitations_component` | tw `items` 裡位置那一項 | 直接折返的那一端車不停下來等，位置就用末站。 |
| `data_limitations_component` | en `items` 裡位置那一項 | At an end where buses drive on, they do not wait, so the location is the last stop. |

## Implementation Contract

**行為**：`bin/dev` 開 `/routes/15373`（去程結束那一端是 `pass_through`）：

- 折返停留表去程那一列的標籤是「直接折返」，表下的說明是「文案」那一句。
- 分佈圖去程標題的標籤是「直接折返」。
- 站序區塊去程最後那一句是「這一端 直接折返，下一趟從 … 出發」，返程是「這一端 停車，…」。
- 試算那一塊報直接折返那一端筆數的那一句是「文案」那一句。
- 折返點設施卡去程那一欄寫「車在這一端不停下來等，位置就用末站。」。
- 資料限制裡兩項用新詞。

英文頁面的標籤仍是 “Drives on”，說明句不再出現 “do not stop” 與 “without stopping”。`data-end-nature` 的值、版面、樣式、數字都跟改之前相同。

**介面與資料**：只改 `.yml` 的值與文件、測試的文字。沒有新的鍵，也沒有拿掉任何鍵；元件的 Ruby 與 ERB 不動。

**驗收**：

- `grep -rn "開過去就走" app spec config docs/spectra/LANGUAGE.md docs/background.md docs/decisions.md README.md analysis/README.md` 只剩詞彙表「不要用」那一行。
- `grep -rn -E "do not stop|without stopping" app/components config/route_page.yml` 沒有結果。
- 13 個測試檔裡斷言畫面文字的例子，先把預期改成「直接折返」，看到它們在改 `.yml` 之前失敗，改完之後通過。
- `bin/rails parallel:spec` 全綠。
- `spectra validate 01-pass-through-wording` 通過。

**範圍**：只動 Impact 列的檔。不動 `app/components/*.rb`、`*.html.erb`、`app/models/`、`analysis/*.sql`、資料表、`config/route_page.yml` 的設定值（只改開頭的英文註解）。

## Risks / Trade-offs

- [`ui-touchups` 與 `buffer-trade-cost-curve` 也改同一批 `.yml`、測試檔或詞彙表] → apply 前先看 `spectra list` 與 `git status`，有重疊就先跟使用者確認順序。後 apply 的那一個要以對方改完的檔為底：如果 `buffer-trade-cost-curve` 先改了 `pass_through_html` 或資料限制那兩項，這裡只把其中的舊詞與「不停」換掉，不覆蓋它的新句子。標任務完成時用 `spectra task done … --file` 列出這條任務改的檔。
- [Demo 影片或已分享的截圖還是舊詞] → 改不了，也不需要改；網站上的字以這次為準。
- [「直接折返」也被誤讀] → 標籤旁邊沒有空間解釋，所以說明句一定要寫出「讓乘客下車後不停下來等」；之後有人反映，再走一次同樣的流程。
