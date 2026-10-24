<!--
每條任務寫兩件事：做完之後哪個行為看得到、用什麼驗證。
Requirement 名稱（英文）與 design 決定標題（中文）都原文照抄，分析器靠字串比對。
ui-touchups 與 buffer-trade-cost-curve 也改到這裡會碰的 .yml、測試檔或詞彙表（見 design 的 Context 與 Risks）：apply 前先看 spectra list 與 git status；標任務完成時用 `spectra task done <任務> --change 01-pass-through-wording --file <檔>` 列出這條任務改的檔，不讓對方的修改算進這個 change。
-->

## 1. 畫面上的字

- [x] 1.1 套用 design「性質的標籤改成「停車」與「直接折返」」與「文案」：路線頁上 `pass_through` 那一端的標籤顯示「直接折返」，出現在折返停留表、分佈圖每個方向的標題、站序區塊、折返點設施卡；兩端都是 `pass_through` 時摘要那一句是「兩端都是直接折返，沒有停車的一端」。改的是 `layover_table_component.yml`、`layover_chart_component.yml`、`stop_sequence_component.yml`、`turnaround_facilities_component.yml` 的 tw `natures.pass_through`，以及 `route_summary_component.yml` 的 tw `no_stopping_end`；en 不動。先改測試：`spec/components/layover_table_component_spec.rb` 斷言儲存格文字的那個例子（去程那一列目前預期「開過去就走」）改成預期「直接折返」，看到它在改 `.yml` 之前失敗。驗證：`bundle exec rspec spec/components/layover_table_component_spec.rb spec/components/layover_chart_component_spec.rb spec/components/stop_sequence_component_spec.rb spec/components/turnaround_facilities_component_spec.rb spec/components/route_summary_component_spec.rb` 全綠；內容檢查，`git diff app/components` 裡這五個鍵的值跟 design「文案」逐字相同。
- [x] 1.2 [after: 1.1] 套用 design「說明句寫「不停下來等」，不寫「不停」」、「英文標籤不變，只改說它不停的句子」與「文案」：折返停留表下的說明、試算那一塊報直接折返那一端筆數的那一句、折返點設施卡的說明與末站那一句、資料限制的兩項，中文都寫成車「不停下來等」，表下說明與試算那一句寫出車在末站讓乘客下車；英文的 “do not stop” 與 “without stopping” 換成 “do not wait” 與 “without waiting”，英文標籤 “Drives on” 不變。驗證：內容檢查，每一個改到的字串跟 design「文案」那張表逐字相同；`grep -rn -E "do not stop|without stopping" app/components` 沒有結果；`grep -n "不停" app/components/*.yml` 只剩 `stop_sequence_component.yml` 的 `member_note` 與新句子裡的「不停下來等」；`bundle exec rspec spec/components/buffer_trade_component_spec.rb spec/components/turnaround_facilities_component_spec.rb spec/components/layover_table_component_spec.rb` 全綠。
- [x] 1.3 [after: 1.1] 套用 design「站序區塊那一句拿掉開頭的「折返」」與「文案」：站序區塊每個方向最後那一句，中文是「這一端 停車，下一趟從 … 出發」或「這一端 直接折返，下一趟從 … 出發」，沒有下一趟起站時是「這一端 停車」這種形式；英文 “Turnaround …” 不變。只改 `stop_sequence_component.yml` 的 tw `turnaround_html` 與 `turnaround_only_html`。驗證：內容檢查，兩個字串跟 design「文案」逐字相同；`bundle exec rspec spec/components/stop_sequence_component_spec.rb` 全綠；`bin/dev` 開 `/routes/15373`，展開站序區塊，去程最後一句是「這一端 直接折返，下一趟從 … 出發」，返程是「這一端 停車，…」。

## 2. 測試描述、詞彙表與文件

- [x] 2.1 [after: 1.1] 測試的描述用新詞：13 個測試檔（proposal 的 Impact 列的 `spec/` 檔）裡 `it`、`describe` 描述中的「開過去就走」都換成「直接折返」，句子不通時只做最小幅度的改寫，不改每個例子在測什麼。驗證：`grep -rn "開過去就走" spec` 沒有結果；`bin/rails parallel:spec` 全綠，例子數跟改之前相同。
- [x] 2.2 套用 design「詞彙表把舊詞列進不要用」：`docs/spectra/LANGUAGE.md`「起站、末站、折返點、調度站」那一條的定義、在資料或程式碼裡、邊界三行用「直接折返」，定義寫出車在末站讓乘客下車後不停下來等；「來回一趟」、「換休息試算」兩條裡的舊詞一起換，「來回一趟」裡「一兩分鐘的過站」照 design 改寫；「不要用」那一行最後加上舊詞與原因。動手前重讀這個檔，因為 ui-touchups 可能改了「路線頁」那一條。驗證：`grep -n "開過去就走" docs/spectra/LANGUAGE.md` 只剩「不要用」那一行；內容檢查，`git diff docs/spectra/LANGUAGE.md` 只動到這三條。
- [x] 2.3 還在用的文件與設定註解用新詞：`docs/background.md`、`docs/decisions.md`、`README.md`、`analysis/README.md` 裡的「開過去就走」換成「直接折返」，句子不通時只做最小幅度的改寫；`config/route_page.yml` 開頭英文註解的 “without stopping” 改成 “without waiting there”，設定值不動。驗證：`grep -rn "開過去就走" docs/background.md docs/decisions.md README.md analysis/README.md config` 沒有結果；`bundle exec rspec spec/models/route_page/ends_spec.rb` 全綠，表示設定照常讀得到。

## 3. 規格與收尾

- [x] 3.1 套用 design「規格只把 pass_through 的定義寫準」：這個 change 的 `specs/turnaround-ends/spec.md` 修改 Verified end nature per route，只換 `pass_through` 的那一句定義，六個情境不變。驗證：把 delta 跟 `docs/spectra/specs/turnaround-ends/spec.md` 裡同一條需求做 diff，差別只有那一句；`spectra validate 01-pass-through-wording` 通過。
- [x] 3.2 [after: 1.2, 1.3, 2.1, 2.2, 2.3, 3.1] 全部驗收：design Implementation Contract 的兩個 `grep` 都只得到預期的結果；`bin/rails parallel:spec` 全綠；`bin/rubocop` 對改到的 `.rb` 測試檔沒有 offense；`bin/dev` 開 `/routes/15373` 與 `/routes/16111`，前者的折返停留表、分佈圖、站序、試算、設施卡、資料限制都看得到新詞與新句子，後者兩端在折返停留表、分佈圖、站序都標「停車」；設施卡的說明與資料限制是每一頁都顯示的通用說明，在後者照樣用新詞。驗證：以上指令的輸出與人工畫面檢查，在任務完成的說明裡記下看過的頁。
  - 2026-10-24 apply 時經使用者同意更正：原本寫「後者沒有任何直接折返的字」，但設施卡說明與資料限制在改之前的 307 頁上也有舊詞（`HEAD` 版本的資料限制 2 處、設施卡說明 1 處），不是這個 change 造成的。
  - 驗收紀錄：兩個 `grep` 只剩詞彙表「不要用」那一行；`bin/rails parallel:spec` 1,067 個例子全過；13 個測試檔 RuboCop 沒有 offense。看過的頁是 `/routes/15373` 與 `/routes/16111`：1.3 時開發伺服器還在跑，用 curl 看；3.2 時伺服器已經停了，改用 `bin/rails runner` 在開發環境內部送請求。15373 的六個地方都是新詞與新句子，16111 兩端的標籤都是「停車」，兩頁都沒有舊詞。
