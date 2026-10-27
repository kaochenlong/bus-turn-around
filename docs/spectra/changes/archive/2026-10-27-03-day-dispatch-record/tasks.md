## 1. 先畫再寫

- [x] 1.1 照 design「先在畫布畫紀錄的第一頁與一張帶註記的單，選定再寫程式」：在 Claude Design 畫布上用 A4 橫式（1123×794px）畫紀錄的第一頁（頁首、四個數字、修改清單含已復原、每台車的四小時休息）與一張帶 ＊、†、‡ 與註記的單，資料用 01 design 的 Design Source 那個 251區 情境；給使用者選，選定之後用 `/spectra-ingest 03-day-dispatch-record` 把尺寸補進 design，畫板快取到 `.spectra/design-cache/03-day-dispatch-record/`。驗證：使用者選定的方案與數值寫進 design（內容檢查）。

## 2. 匯出與列印

- [x] 2.1 Exporting the change log 與 Exporting the day's sheets 的檔案內容，照 design「匯出兩個 CSV，各一個按鈕，UTF-8 帶 BOM」：新增 `app/frontend/timetable/day_record.js` 的 `changeLogCsv(day, labels)`、`sheetsCsv(day, current, labels)` 與 `csvFileName(day, kind)`。先在 `app/frontend/timetable/day_record.test.js` 寫測試看它失敗：規格 Scenario「Two changes exported」（檔名、BOM、表頭、兩列的內容與已復原）、Example「Reason with a comma」、Scenario「A changed trip in the sheets file」、換行是 CRLF、24:07 照寫、修改清單是空的時只有表頭。驗證：`yarn test:js` 全綠。
- [x] 2.2 班表頁與當天紀錄共用填單子的程式，照 design「印出來的單子跟班表頁同一套行車憑單 template」，班表頁印出來與編輯的樣子不變：
  - 把 `app/frontend/timetable/component.js` 的 `timetable()` 裡從單子 template 做出一張單的部分（複製 template、一列一個來回、補到 14 列的空白列、印出來的時刻與起點、兩個停留、車次、標題下那一行、四小時休息那一句）搬到新的 `app/frontend/timetable/sheet_view.js`，班表頁改用它；時刻後面接的記號由呼叫的一方給（班表頁是到達格的退回全天標記）。排班時才有的部分（手動改過與往後推的標記、刪除與加一列、退回全天的說明、被退回的時刻）留在 `component.js`。
  - `TimetableSheetComponent` 改成只要路線名就能畫：給它涵蓋的日子與日型別時，照舊寫班表頁標題下那一行；沒給時那一行留給瀏覽器寫。`app/views/timetables/show.html.erb` 與 `spec/components/timetable_sheet_component_spec.rb` 改用新的參數。

  先跑下面的 spec 確認全綠；在 `spec/components/timetable_sheet_component_spec.rb` 加「只給路線名時，表單抬頭有路線名、標題下那一行留給瀏覽器寫」並先看它失敗；搬完之後故意改壞 `sheet_view.js` 補空白列的列數，確認 `spec/system/timetable_print_spec.rb` 會失敗，再還原。驗證：`bundle exec rspec spec/system/timetable_print_spec.rb spec/system/timetable_edit_spec.rb spec/system/timetable_layout_spec.rb spec/components/timetable_sheet_component_spec.rb spec/requests/timetables_spec.rb` 全綠；對改過的 `.rb` 跑 `bin/rubocop`。
- [x] 2.3 紀錄的 template 與文案，照 design「紀錄的內容與順序：摘要一頁、一車一頁、最後是資料限制與顯名聲明」與 Design Source 第一頁的數值：
  - `DayDispatchComponent` 加上紀錄的摘要區塊（小標、路線與日期、計畫依據、記下的不是量到的那一句、四個數字、每台車的四小時休息、修改清單與沒有修改時那一句）、放單子的位置與單子的 template（`TimetableSheetComponent` 只給路線名）、每張單下面放註記的位置、「印出當天紀錄」「匯出修改清單」「匯出最後的單」三個按鈕（放在「計畫的班表」與「重新開始」之間），以及兩個 CSV 的表頭、單子標題下那一行與註記的文案，都有 tw 與 en。
  - 新的 `DayRecordLimitationsComponent`：design 列的四條資料限制，tw 與 en，照 `TimetableLimitationsComponent` 的寫法。

  先在 `spec/components/day_dispatch_component_spec.rb` 寫測試看它失敗：三個按鈕都在、兩個 CSV 的表頭與單子標題下那一行、註記的文案經 data 屬性給瀏覽器並留著要填的位子、放單子的位置帶著有路線名的單子 template。驗證：`bundle exec rspec spec/components/day_dispatch_component_spec.rb` 全綠；摘要的文案與四條資料限制做內容檢查。[after: 1.1, 2.2]
- [x] 2.4 Day record files built in the browser：兩個匯出按鈕各自用 Blob 與帶 `download` 的連結下載 2.1 產生的檔案，不送請求。先在新增的 `spec/system/timetable_day_record_spec.rb` 寫測試看它失敗：規格 Scenario「Export without a request」（連結帶檔名與 `blob:` 位址、沒有送請求）、兩個按鈕各觸發一個下載。驗證：`bundle exec rspec spec/system/timetable_day_record_spec.rb` 全綠，每個例子不超過 5 行。[after: 2.1, 2.3]
- [x] 2.5 Printing the day record，照 design「列印用瀏覽器與列印樣式表，當天紀錄有自己的具名頁」、「紀錄的內容與順序：摘要一頁、一車一頁、最後是資料限制與顯名聲明」與 Design Source 的數值：
  - 「印出當天紀錄」呼叫瀏覽器的列印。`app/frontend/timetable/day_view.js` 把摘要（頁首、四個數字、每台車的休息、修改清單或沒有修改那一句）與一車一頁的單畫進 2.3 的 template，在瀏覽器要印之前照當天最後的樣子畫（按鈕與瀏覽器自己的列印都會先發 `beforeprint`；畫面每次重畫都連紀錄一起畫太浪費，307 有 82 台車）；單用 2.2 的 `sheet_view.js` 與當天最後的單，標題下那一行寫日期與計畫依據（`day_record.js` 的 `sheetHeader`），時刻照單子的寫法，24 點以後印隔日。
  - `app/frontend/stylesheets/application.css` 加 `@page day-record` 與當天紀錄的列印規則：摘要一頁、一車一頁、最後一頁是 `DayRecordLimitationsComponent` 與顯名聲明；名稱列與畫面上的頁首、四個數字、時間軸、側欄、表單、按鈕不印；紀錄的摘要、單子與最後一頁在螢幕上看不到；單子的列印規則跟班表頁共用一份。

  先在 `spec/system/timetable_day_record_spec.rb` 用 CDP 把媒體換成 print 寫測試看它失敗：規格 Scenario「Order of the printed record」（印成 PDF 是四頁）、「Nothing of the record on screen」、按鈕呼叫瀏覽器的列印一次、修改清單是空的時寫沒有修改；排班時的列印照舊（`spec/system/timetable_print_spec.rb` 不用改照樣綠）。驗證：`bundle exec rspec spec/system/timetable_day_record_spec.rb spec/system/timetable_print_spec.rb` 全綠，每個例子不超過 5 行。[after: 2.2, 2.3]
- [x] 2.6 Marks on the printed sheets，照 design「換過的、記下的、改過的印成符號加註記，不靠顏色」與 Design Source 單子的數值：單子的發車格與到達格在時刻後面印 ＊、‡、†；單子下面印註記，原排同一台車的 ＊ 合成一條，先 ＊ 再 † 再 ‡，沒有記號的單不印註記。註記的文字由 `app/frontend/timetable/day_record.js` 的純函式依當天最後的單算，先在 `app/frontend/timetable/day_record.test.js` 寫測試看它失敗：規格 Example「Grouped notes」、沒有記號的單沒有註記、原排兩台不同的車時各一條。列印的部分先在 `spec/system/timetable_day_record_spec.rb` 寫測試看它失敗：規格 Scenario「Notes under the sheets」、帶三行註記的單印成 PDF 照樣一車一頁（放不下照 design 的 Risks 把註記改成 9pt，再放不下就停下來回報）。驗證：`yarn test:js` 與 `bundle exec rspec spec/system/timetable_day_record_spec.rb` 全綠，每個例子不超過 5 行。[after: 2.5]

## 3. 文件與驗收

- [x] 3.1 `docs/spectra/LANGUAGE.md`「當天調度」那條補上印出當天紀錄與匯出兩個 CSV（檔名、只在瀏覽器裡產生）；README.md 班表頁那段補一句當天調度可以印出與匯出，「伺服器只給量到的資料，什麼都不存」照舊成立。驗證：內容檢查，寫法跟 design「匯出兩個 CSV，各一個按鈕，UTF-8 帶 BOM」與「檔案在瀏覽器裡產生，伺服器什麼都不收」一致。
- [x] 3.2 驗收，照 design「測試：CSV 寫 Vitest，列印用系統測試的列印預覽」：跑 `yarn test:js`、`bundle exec rspec spec/system/timetable_day_record_spec.rb spec/components/day_dispatch_component_spec.rb spec/components/timetable_sheet_component_spec.rb spec/system/timetable_print_spec.rb spec/system/timetable_edit_spec.rb spec/system/timetable_layout_spec.rb spec/requests/timetables_spec.rb`、對改過的 `.rb` 跑 `bin/rubocop`，最後 `bin/ci`。列印預覽與 Excel 打開兩個 CSV 由使用者自己驗收，不在這個 task。驗證：指令全綠，回報跑了哪些指令與結果。[after: 2.4, 2.6, 3.1]

> 附註（不是任務）：2026-10-27 在畫布選定版面之後改了這份清單。原本 3.2 的「在 `bin/dev` 上照 01 的 251區 情境走一次，列印預覽截第一頁與 8 號車那一頁給使用者看；匯出兩個 CSV，交給使用者用 Excel 打開確認中文正常」拿掉，改由使用者自己驗收（design「測試：CSV 寫 Vitest，列印用系統測試的列印預覽」）。新增 2.2（班表頁與當天紀錄共用填單子的程式）；原本的 2.2、2.3 改成 2.3、2.4；原本的 2.4 拆成 2.5（Printing the day record）與 2.6（Marks on the printed sheets）。
