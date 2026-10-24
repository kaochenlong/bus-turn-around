這個 change 沒有新的自動測試。狗是固定的畫面內容；路線牌亮不亮由一圈裡的秒數決定、捲到哪裡是算出來的，照 TDD 的測試範圍要測，但專案的測試環境觀察不到：沒有 JS 的測試工具（`scene.js` 建場景要用瀏覽器的 canvas），首頁的 canvas 不保留畫面、讀不出像素，`parts` 與 `pose()` 從頁面拿不到，匯出頁 `tools/hero` 只在 Vite 底下跑、Rails 不提供。所以規格的新情境「Destination sign while the driver is out」照設計的 Implementation Contract，用匯出頁逐格截圖驗證，自動測試這一項記為未驗證。2.3 的先編譯材質也不寫自動測試：每格耗時受機器負載影響、不是決定性的，three.js 的編譯狀態從頁面也拿不到，由 4.1 的量測驗證。插圖現有的三個 spec 檔不用改，要照樣通過。對照的原型與截圖在 .spectra/design-cache/home-hero-samoyed-out-of-service/。

## 1. 場景：調度室裡的薩摩耶

- [x] 1.1 照設計「調度室裡加一隻坐著的薩摩耶，不會動」在 `app/frontend/hero/scene.js` 新增 `samoyed()`，由 `dispatchOffice()` 放在調度室座標 (−0.9, 0, 0.4)、`rotation.y` −0.5：造型、尺寸與顏色照設計的表，一共 13 個 mesh，毛是 `SLATE_100`，眼睛與鼻子是 `SLATE_800`；不加進 `parts`、不切；`dispatchOffice()` 上方的註解補上這隻狗。完成後，桌機的全景隔著調度室的窗看得到一隻坐著的白狗，一整圈都不動。驗證：用 headless Chrome 開 `yarn vite tools/hero`，匯出頁 `?s=5.5` 截一張全景圖，裁出調度室放大，跟 `.spectra/design-cache/home-hero-samoyed-out-of-service/renders/office-sitting.png` 對照做視覺檢查：狗整隻在窗洞裡，看得到尖耳朵、黑鼻子、兩個眼睛與捲在背上的尾巴，沒有擋到站長、桌子、排班板與海報，也沒有穿進牆或桌腳；`?s=12` 再截一張，狗在同一個位置、同一個姿勢。

## 2. 場景：車頭路線牌的跑馬燈

- [x] 2.1 照設計「車頭路線牌在司機下車到前門關好之間跑「暫停服務」」在 `bus()` 加路線牌的平面與字帶貼圖：1.9×0.28 的平面在空白路線牌外側 0.005、面向 +x，用 `MeshBasicMaterial`；字帶高 64 px，用 `measureText` 量字寬，`900 50px` 的「暫停服務」以 amber-400 畫在 slate-800 底的最左邊，後面留一段跟牌子一樣寬（434 px）的空白，`wrapS` 設成重複。`bus()` 回傳 `sign`，`buildScene()` 把它放進 `parts.sign`；`pose(parts, seconds)` 在 [`TIMELINE.stepOut` 的開始, `TIMELINE.doorClose` 的結束) 顯示平面，`offset.x` 照設計的式子在 `STILL` 置中、每秒往左移 150 px。完成後，規格「Hero picture」的新情境成立（設計「規格把「不顯示任何 figure」寫成「任何數字」」加的那個情境）：司機開始下車到前門關好之間，車頭路線牌由右往左跑「暫停服務」，其餘時間空白。驗證：匯出頁在情境「Destination sign while the driver is out」Example 的每個秒數（1.5、3.4、4.2、5.5、10.6、11.2、14.4）各截一張全景圖與一張窄螢幕圖（加 `&shot=narrow`），裁出車頭放大，路線牌的狀態跟表一致：1.5、3.4、11.2、14.4 空白，4.2 字從右邊進來，5.5 整句置中，10.6 還亮著；另外在第 4.0 到 10.8 秒之間每 0.4 秒截一張車頭特寫，平面與原本的方塊沒有互相閃爍，字一律從右邊進來，沒有糊成一團（糊掉就照設計 Risks 那條試 `minFilter` 或 `anisotropy`），也沒有被地塊左右兩緣的切面切錯。[after: 1.1]
- [x] 2.2 照設計「車頭路線牌在司機下車到前門關好之間跑「暫停服務」」改 `app/frontend/hero/scene.js` 的註解，讓註解說的跟現在的行為一致：開頭色票那段 `AMBER_400` 的用途補上路線牌的字；`bus()` 上方原本寫 a blank destination sign，改成平常空白、司機在車外時跑「暫停服務」；`pose()` 上方補上它也設路線牌。驗證：內容審閱 `git diff app/frontend/hero/scene.js` 的註解；`git grep -n "a blank destination sign" app/frontend/hero` 沒有結果。[after: 2.1]
- [x] 2.3 照設計「首頁在畫第一格之前，先編譯好所有材質、上傳貼圖」改 `app/frontend/hero/runtime.js` 的 `start()`：建好場景、renderer 與鏡頭之後、第一次 `render()` 之前，用當下的鏡頭呼叫 `renderer.compile(scene, camera)`，再走過場景，對每個有 `map` 的材質呼叫 `renderer.initTexture()`，上面加一段註解說明為什麼要先做；`start()` 照舊同步回傳 `toggle()` 與 `dispose()`，`scene.js` 與 `tools/hero` 不改。完成後，路線牌第一次亮起來的那一格不用再編譯它的材質、上傳它的貼圖。不寫自動測試：每格耗時受機器負載影響、不是決定性的，three.js 的編譯狀態從頁面也拿不到；效果由 4.1 的量測驗證。驗證：`bundle exec rspec spec/system/home_hero_spec.rb` 照舊全部通過；內容審閱 `git diff app/frontend/hero/runtime.js`，只多了先編譯材質與上傳貼圖這一段和它的註解。[after: 2.1]

## 3. alt 文字與靜態圖

- [x] 3.1 照設計「兩張靜態圖重新匯出，alt 文字補上薩摩耶與「暫停服務」」把 `app/components/home_hero_component.yml` 的 `alt` 換成設計寫的兩句：`tw`（`zh-TW` 跟著它）與 `en`。完成後，靜態圖的 alt 寫到調度室地上的薩摩耶與車頭的「暫停服務」。驗證：內容審閱，兩種語系都寫到薩摩耶與「暫停服務」，其餘描述跟原本一樣；`bundle exec rspec spec/components/home_hero_component_spec.rb` 通過。
- [x] 3.2 照設計「兩張靜態圖重新匯出，alt 文字補上薩摩耶與「暫停服務」」重新匯出兩張靜態圖：用 headless Chrome 按匯出頁的兩個匯出按鈕，存成 `app/assets/images/home-hero-wide.webp` 與 `app/assets/images/home-hero-narrow.webp`，`ls -l` 記下新的大小；再匯出一次，跟剛存的檔用 `magick compare -metric AE` 比對（規格「Hero picture」的情境「Still matches the static image」，以新檔為準）。完成後，靜態圖就是新的定格畫面：全景有坐著的狗，兩張的路線牌都亮著、整句置中。驗證：兩張比對都是 0；`bundle exec rspec spec/assets/home_hero_images_spec.rb spec/components/home_hero_component_spec.rb` 通過，也就是檔案在預算內、寬高照舊是 2048×976 與 1170×780；全景圖裁出調度室與車頭、窄螢幕圖裁出車頭，做視覺檢查。[after: 2.2]

## 4. 效能與整套檢查

- [x] 4.1 照設計「效能預算照舊，加了薩摩耶與跑馬燈之後重新量」與「首頁在畫第一格之前，先編譯好所有材質、上傳貼圖」重新量：開發機的 headless Chrome，用 CDP 開 4 倍 CPU 節流，在頁面腳本執行前包住 `requestAnimationFrame`，量每次回呼的執行時間與開始時間，不計前三次；全景（寬 1400 px、DPR 1）與窄螢幕（寬 390 px、DPR 3，壓到 2）各量至少兩次、每次 26 秒（一整圈再加下一圈的第 3.8 秒），記下格數、中位數、p95、最大值，以及最慢的五格各是第幾格；首頁動畫的 chunk 用 brotli（q11）與 gzip（-9）量大小。量的時候只開 test 環境的 Rails，匯出頁的 Vite 與其他用不到的 server 先關掉。同一輪也量改之前的版本做對照：用 `git archive ca14701`（這個 change 開始時的 HEAD）把當時的程式取到 scratchpad 另外 build，先確認它的動畫 chunk 不 import 其他 chunk，再暫時蓋過 `public/vite/assets` 裡同名的動畫 chunk，照同樣的方法量，量完重新 `yarn build` 還原；repo 裡受版本控制的檔案一律不動。數字與量的日期接在設計「效能預算照舊，加了薩摩耶與跑馬燈之後重新量」的「修正後再量的數字」後面，並寫明中位數「多約 0.5 ms」的估計成立還是被推翻。完成後，design 記著先編譯材質之後的每格耗時、chunk 大小與改之前的對照。驗證：每格不超過 16 ms、chunk brotli 後不超過 200 KB；路線牌第一次亮的那一格跟 `ca14701` 的同一格比較，多出來的耗時寫進 design；超出預算就停下回報，不自己放寬。[after: 2.3]
- [x] 4.2 跑整套檢查。完成後，這個 change 改到的程式、圖檔與文案都通過專案的完整檢查。驗證：`bin/ci` 全部通過。[after: 3.1, 3.2, 4.1]

## 5. 人工確認

- [x] 5.1 使用者用 `bin/dev` 開首頁，在 1280 px 與 390 px 寬各看至少兩圈：桌機上隔著調度室的窗看得到坐著的薩摩耶，讀起來會不會太像玩具；司機開始下車時車頭路線牌亮起來、前門關好時熄掉，捲動的速度可不可以接受；手機上路線牌比較大，字讀不讀得出來（設計估計勉強讀得出），看不到狗是預期的。驗證：使用者回報結果；要調的地方記在這條任務下面，另外處理。[after: 4.2]
