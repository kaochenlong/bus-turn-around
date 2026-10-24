## Summary

這個 change 服務三樣交付物的第一樣：路線健檢卡在網站上的路線頁。它不需要新的資料，也不動任何指標、資料表或設定值，只改字：

- 折返點兩種性質裡的「開過去就走」改叫「直接折返」。
- 說明裡說這一端的車「不停」的句子，改成車在末站讓乘客下車之後「不停下來等」。

程式裡的 `pass_through` 不變。

## Motivation

2026-10-24 討論要不要把路線頁做到全台北市時，使用者說「開過去就走」這個詞他一直搞不清楚是什麼意思。這個詞是 `zhongshan-turnaround-ends` 的決定「頁面上每一端標出性質：文案用「停車」與「開過去就走」，程式用 stop 與 pass_through」定的，當時的理由是「讀頁面的司機與站長一看就懂」。現在連定這個網站方向的人都看不懂，這個理由就不成立了。

誤會出在兩個地方：

- 「開過去就走」聽起來像過站不停。可是這一端的車其實會在末站停靠，讓乘客下車；它沒做的是停下來等下一趟的發車時間。中山幹線青年公園端就是這樣：車到馬場町放完乘客，直接開約 200 公尺到青年社宅發下一趟，2026-10-20 的 75 筆折返停留中位數 1.9 分鐘（量到的，記在 `config/route_page.yml`）。
- 說明文字把這個誤會寫死了。折返停留表下面寫「車到了末站不停，直接開下一趟」，試算那一塊寫「不會停下來」，折返點設施卡寫「車在這一端不停」，詞彙表的定義也寫「車到末站不停」。英文說明同樣寫 “do not stop at the last stop”、“without stopping”。

正式站上有 7 個元件的文案用到這個詞，共 10 次（2026-10-24 用 grep 數的）。

為什麼是現在：下一個 change `02-end-nature-survey` 要把全路網每一端分成停車、直接折返、待查證三種，它的報告與文件會大量用到這個詞。先把詞定下來，後面的文件直接用新詞寫。

## Proposed Solution

- **標籤**：路線頁上折返點性質的兩個標籤改成「停車」與「直接折返」。出現在折返停留表、分佈圖每個方向的標題、站序區塊每個方向最後那一列、折返點設施卡。英文標籤 “Drives on” 不變。
- **說明句**：凡是說這一端的車「不停」的地方，都改成「不停下來等」，需要時寫出車在末站讓乘客下車。例如折返停留表下的說明改成「標「直接折返」的那一端，車在末站讓乘客下車後不停下來等，直接開到下一趟的起站，所以那裡的折返停留不算休息。」英文把 “do not stop” 與 “without stopping” 改成 “do not wait” 與 “without waiting”。
- **詞彙表**：`docs/spectra/LANGUAGE.md`「起站、末站、折返點、調度站」那一條，性質的兩個值改成「停車」與「直接折返」，定義改成「車在末站讓乘客下車後不停下來等，直接開到下一趟的起站」；「不要用」加上「開過去就走（舊說法，聽起來像過站不停）」。詞彙表其他條目裡的這個詞一起換。
- **規格**：`turnaround-ends` 的「Verified end nature per route」把 `pass_through` 的英文定義從 “drive on to the first stop of the next trip without stopping” 改成 “let passengers off at the last stop and drive on to the first stop of the next trip without waiting there”。行為不變，只是把定義寫準。
- **其他還在用的文件**：`docs/background.md`、`docs/decisions.md`、`README.md`、`analysis/README.md` 換成新詞，`config/route_page.yml` 開頭的英文註解把 “without stopping” 改成 “without waiting there”。測試的描述與斷言跟著文案改。

這個 change 不牽涉指標定義：折返停留怎麼量、哪一端算休息機會都不變，所以「車不等於人」、刷卡率、漏站、跨小時重複這些資料限制都跟原本一樣，不受影響。

## Non-Goals

- 改程式識別字：`pass_through`、`#n_pass_through_layovers`、`data-end-nature` 的值、`config/route_page.yml` 的設定值都不變，照 `docs/decisions.md` 第 10 條程式碼全英文。
- 改英文標籤 “Drives on”：英文沒有中文那種「過站不停」的讀法，只改說它 “do not stop” 的句子。
- 改標籤的樣子：`01-route-page-visual-refresh` 的決定「折返方式改成標籤，兩種同一個樣式」照舊，只換字。
- 改「停車」這個詞：使用者沒有說看不懂，跟「直接折返」放在一起時意思也清楚。
- 改已歸檔的 change 與 `docs/cards/` 裡已經產生的健檢卡：那些是當時的紀錄。
- 任何指標定義、資料表、兩端性質的值，以及把兩端性質改成從資料判斷（那是 `02-end-nature-survey` 之後的事）。

## Alternatives Considered

- 「不停車」：跟「停車」成對最簡單，但「停車」也可以指公車靠站，「不停車」一樣會被讀成過站不停，否決。
- 只改說明句，標籤照舊：標籤是讀者第一眼看到的字，誤會從標籤就開始了，否決。

## Impact

- Affected specs: `turnaround-ends`（修改 Verified end nature per route 的定義文字，行為不變）
- Affected code:
  - Modified:
    - app/components/layover_table_component.yml
    - app/components/layover_chart_component.yml
    - app/components/stop_sequence_component.yml
    - app/components/buffer_trade_component.yml
    - app/components/route_summary_component.yml
    - app/components/turnaround_facilities_component.yml
    - app/components/data_limitations_component.yml
    - spec/components/layover_table_component_spec.rb
    - spec/components/layover_chart_component_spec.rb
    - spec/components/stop_sequence_component_spec.rb
    - spec/components/buffer_trade_component_spec.rb
    - spec/components/route_summary_component_spec.rb
    - spec/components/turnaround_facilities_component_spec.rb
    - spec/components/cycle_table_component_spec.rb
    - spec/models/route_page/ends_spec.rb
    - spec/models/route_page/buffer_trade_spec.rb
    - spec/models/route_page/cycles_spec.rb
    - spec/requests/routes_spec.rb
    - spec/system/end_map_spec.rb
    - spec/analysis/turnaround_facilities_spec.rb
    - docs/spectra/LANGUAGE.md
    - docs/background.md
    - docs/decisions.md
    - README.md
    - analysis/README.md
    - config/route_page.yml
  - New: (無)
  - Removed: (無)
