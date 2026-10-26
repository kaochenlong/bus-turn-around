## Why

這個 change 服務第二樣交付物「換休息試算」往調度員桌上推的那一步：班表頁 `/routes/:route_id/timetable` 上一車一張的單子（班本）。不新增任何資料，也不碰伺服器與衍生表：頁面嵌的 JSON（`RoutePage::Timetable`）、鋪排演算法與四小時休息都不變，改的只有瀏覽器裡打時刻、刪列的操作，以及螢幕上顯示哪些欄。不牽涉指標定義。

2026-10-26 使用者看了班表頁的單子，提出三件事。討論後的結論：

- **發車時間那格**：使用者問有沒有像 flatpickr 那樣只有時間、容易用的選擇器。結論是不裝。班表的時刻是營運日的寫法，時要能到 29（規格「Manual edits recomputed in the browser」與例子「Typed times」的 24:45），瀏覽器內建的 `<input type="time">` 只到 23:59，flatpickr 的純時間模式也只到 23，而且 npm 上的最新版 4.6.13 是 2022-04-14 發的，之後沒有新版。這格真正難用的是三件事，都是讀程式碼推的：
  - 四個時刻格都是 `inputmode="numeric"`。WebKit bug 200226 裡 WebKit 工程師說，iOS 13 起這個設定叫出只有 0 到 9 的數字鍵盤，而 `parseClock` 一定要有冒號，所以 iPhone 上可能打不出合格的時刻。沒有拿實機測過。
  - 打錯時程式會加 `data-invalid`，但 `app/` 裡沒有任何樣式：列上的格子默默跳回原值，「加一列」「加一台車」按了沒反應。
  - 每改一格，`render()` 用 `replaceChildren` 把所有單子重畫，沒有把焦點放回去，所以按 Enter 或 Tab 之後游標可能不見，要再點一次。沒在瀏覽器驗過。

  使用者選了：冒號在送出時補上；打錯時紅色描邊，並說明怎麼打；改完游標留在原處。
- **「刪這一列」**：它在第 14 欄，表格比畫面寬，要刪就得先捲到最右邊；四個字的按鈕（約 82px，估的）比時刻格（72px，`w-18`）還寬。改成每列最前面的垃圾桶圖示。
- **螢幕上的六個手填欄**：職號、姓名、兩個調度員、兩個里程，在螢幕上永遠是空的、不能打字，卻每欄至少 80px（表頭的 `min-w-20`），加上內距約 600px（估的）。表格能用的寬度約 1024px（照 class 算的：`page-column` 的 `max-w-6xl` 扣掉頁面與單子的內距），整張表約 1500px（估的），所以桌機也要橫向捲動。改成只在印的時候出現。

## What Changes

- 四個時刻格（每列的兩個發車格、每張單的「加一列」、頁底的「加一台車」）收不打冒號的寫法：`0530`、`530`、`5:30`、`05:30` 都是 05:30，`2445` 是 24:45；前後的空白不算。時 00 到 29、分 00 到 59 的範圍不變，`23:70`、`30:00` 照樣不收。送出後格子顯示 `05:30` 這種寫法。四個輸入框拿掉 `pattern` 屬性與 `TimetableSheetComponent::TIME_PATTERN`，格式只由 `parseClock` 決定。
- 打的時刻跟原本一樣時（例如原本 07:30，打 `0730`），不算改過：格子只換成 07:30 的寫法，頁首的改過數不變。
- 改一格發車只更新那張單的格子與頁首的數字，不整區重畫：按 Enter 游標留在那一格，按 Tab 照常跳到下一個控制項，改完直接點別的格子也點得到。加一列之後，游標回到那張單的「加一列」輸入框；加一台車之後，游標在「加一台車」的輸入框。
- 打錯時：那一格紅色描邊（這是網站第一次用紅色，只用在這裡），那張單（或「加一台車」那一塊）出現一行紅字，寫出打了什麼、時刻可以怎麼打。列上的格子照樣回到原本的時刻。下一次被接受的修改會把描邊和那行字清掉。
- 「刪這一列」移到每列最前面，改成沒有描邊的垃圾桶圖示按鈕（36px 正方形，滑過去出淺底色）；「刪這一列」這幾個字放進 `title` 與 `aria-label`。印出來照樣不印。
- 螢幕上不顯示六個手填欄，印的時候照紙本 13 欄、欄寬不變；拿掉手填欄表頭的 `min-w-20`。
- 規格 `timetable` 改四條需求與例子「Typed times」；`docs/spectra/LANGUAGE.md` 的「班本」「班表」兩條跟著改。
- 測試：照專案 `.spectra.yaml` 的 `tdd: true`，先寫會失敗的測試再改。`parseClock` 的 Vitest 表照新的例子；系統測試鎖住不打冒號、相同時刻不算改過、Enter／Tab／點擊之後的焦點、打錯時的標示與說明、手填欄在螢幕上看不到而印的時候在。紅色、圖示、描邊這些寫死的 class 不寫斷言，在瀏覽器截圖給使用者看。

## Non-Goals

- 不裝時間選擇器，包括 flatpickr、瀏覽器內建的 `<input type="time">`、自己做的彈出選單：時要能到 29，現成的都只到 23；自己做的要點兩三下加捲動，對知道要幾點的調度員比打四個數字慢。
- ↑／↓ 加減分鐘：使用者 2026-10-26 選了不做。
- 打錯時保留打錯的字：照樣回到原本的時刻（規格的「Malformed time」與 `spec/system/timetable_edit_spec.rb` 的「打 25:70」）。
- 刪除不能復原、刪列之後焦點落在哪裡：照舊。
- 鋪排演算法、計畫行駛時間、四小時休息、超時表、伺服器回應的 JSON、網址參數，一律不動。
- 列印的版面（欄序、欄寬、抬頭、至少 14 列）不動。
- 紅色只用在打錯的時刻格與它的說明；網站其他地方不加。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `timetable`: 「One sheet per vehicle with round-trip rows」螢幕上不顯示手填欄、每列最前面是刪除鈕；「Manual edits recomputed in the browser」打的時刻收不打冒號的寫法、相同時刻不算改過、改完游標留著、打錯時看得到；「Adding a vehicle」同樣的寫法與打錯時的標示；「Printing the timetable」手填欄只在印的時候出現。

## Impact

- Affected specs: timetable
- Affected code:
  - Modified: app/frontend/timetable/format.js, app/frontend/timetable/format.test.js, app/frontend/timetable/component.js, app/components/timetable_sheet_component.rb, app/components/timetable_sheet_component.html.erb, app/components/timetable_sheet_component.yml, app/views/timetables/show.html.erb, spec/components/timetable_sheet_component_spec.rb, spec/system/timetable_edit_spec.rb, spec/system/timetable_print_spec.rb, docs/spectra/LANGUAGE.md
  - New: (none)
  - Removed: (none)
- 依賴：不加 npm 套件。
- 排程：2026-10-26 `spectra list` 沒有進行中或暫存的 change，沒有別的 change 在改這些檔。
