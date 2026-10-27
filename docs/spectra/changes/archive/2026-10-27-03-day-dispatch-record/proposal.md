## Why

這個 change 服務第二樣交付物「換休息試算」，接在 `01-day-dispatch-model` 之後：把當天調度留成業者可以保存、備查的紀錄。不需要新的資料：用的是 01 存在瀏覽器裡的當天調度（開始當天的快照、依序的修改），以及從它算出來的每台車最後的單；伺服器與衍生表都不動。

使用者 2026-10-26 要的是「做個工具給調度員手動拉動、調整，而且還能留下來記錄、備查」。01 只把當天調度存在那台電腦的瀏覽器裡：清掉網站資料、換一台電腦、用無痕視窗，紀錄就沒了；業者要留著，得有一份帶得走的東西。這個 change 讓調度員可以把當天的紀錄印出來，也可以匯出成檔案。

## What Changes

- 當天調度多一個「印出當天紀錄」，用瀏覽器印：
  - 第一頁是頁首（路線、日期、計畫依據，以及紀錄是調度員記下的、不是量到的）、四個數字、每台車四小時裡最緊的休息（附計畫的數字）、整份修改清單（已復原的也印，標成已復原）。版面 2026-10-27 在畫布選定。
  - 接著一車一頁，照行車憑單的欄位印當天最後的單，跟班表頁印的單子同一套版面。換過車的、記下回到時刻的、改過發車的，在格子裡印符號，單子下面印註記（原排同一台車的換車合成一條），不靠顏色。
  - 最後是當天紀錄自己的資料限制與顯名聲明；班表頁那一份講的是排班，不適用。
- 「匯出修改清單」與「匯出最後的單」兩個按鈕，各下載一個 CSV。瀏覽器擋一次點擊連下兩個檔案，所以分開放。
  - 修改清單：一筆一列，依記下的順序。
  - 最後的單：一趟一列，照車號與單子上的順序。
  - 檔案是 UTF-8、開頭帶 BOM，Excel 打開中文才不會變成亂碼。檔名帶路線 Id 與日期。
- 檔案在瀏覽器裡產生，伺服器什麼都不收。
- 班表頁從單子 template 做出一張單的程式抽出來，給班表頁與當天紀錄共用；班表頁印出來與編輯的樣子不變。
- 文件：`docs/spectra/LANGUAGE.md`「當天調度」那條補上印出與匯出；README.md 班表頁那段補一句。

## 非目標

- 把匯出的檔案再匯入、接著做：timetable-draft 延後的「儲存班表、帳號、檔案下載再上傳、分享改過的班表」裡的「再上傳」，這次不做。
- 伺服器端產 PDF：要 PDF 用瀏覽器的另存 PDF，跟班表頁一樣。
- Excel 格式（.xlsx）、其他格式：先用 CSV。
- 把紀錄存到網站、分享、帳號：照 01 的非目標。
- 排班時的列印：照舊，不動。

## 資料限制與假設

- 紀錄裡的回到時刻、換車、改過的發車，是調度員打進來的，不是量到的；沒記下的趟次照計畫印。
- 車不等於人：一張單是一台車，四小時休息標「若一人開完這張單」。
- 計畫行駛時間是涵蓋日子量到的百分位數（只算完整趟次，漏站的不算），不是保證。
- 時刻：印出來的單子照班表頁單子的寫法，24 點以後印成「隔日 00:07」；匯出的 CSV 照班表頁的營運日寫法，24 點以後寫成 24:07。
- 刷卡率、跨小時重複：不用車上人數、不讀原始檔，不適用。

## Capabilities

### New Capabilities

- `day-dispatch-record`: 當天調度的紀錄：印出當天紀錄的內容與版面、匯出修改清單與最後的單兩個 CSV 的欄位與檔名、檔案只在瀏覽器裡產生。

### Modified Capabilities

(none)

## Impact

- 瀏覽器端：新增 app/frontend/timetable/day_record.js（產生兩個 CSV 與單子下面註記文字的純函式）與它的 Vitest 測試；新增 app/frontend/timetable/sheet_view.js（從單子 template 做出一張單，班表頁與當天紀錄共用），app/frontend/timetable/component.js 改用它；app/frontend/timetable/day_view.js 加上印出、兩個匯出按鈕與紀錄的內容。
- 元件與文案：app/components/day_dispatch_component.html.erb 與 app/components/day_dispatch_component.yml 加上紀錄的摘要、放單子的位置、按鈕與 CSV 表頭的文案；app/components/timetable_sheet_component.rb 改成只要路線名就能畫（app/views/timetables/show.html.erb 照新的參數放它）；新增 app/components/day_record_limitations_component（當天紀錄的資料限制）；app/frontend/stylesheets/application.css 加當天紀錄自己的具名頁與列印規則，單子的列印規則兩頁共用。
- 測試：新增 spec/system/timetable_day_record_spec.rb；改 spec/components/day_dispatch_component_spec.rb 與 spec/components/timetable_sheet_component_spec.rb；班表頁的 spec/system/timetable_print_spec.rb、spec/system/timetable_edit_spec.rb、spec/system/timetable_layout_spec.rb、spec/requests/timetables_spec.rb 照樣要綠。
- 文件：docs/spectra/LANGUAGE.md、README.md。
- 依賴 `01-day-dispatch-model` 的 app/frontend/timetable/day.js 與 app/frontend/timetable/day_storage.js；排在 `02-day-dispatch-timeline` 之後做，因為列印時要藏起 02 的時間軸與側欄。伺服器的資料、路由、網址參數不變。
