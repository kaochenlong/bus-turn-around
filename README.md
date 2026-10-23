# TurnAround 折返點

> English summary. Taipei's bus system is short of drivers and its routes overlap heavily with the metro. In three years the city adjusted 147 of 288 routes and lowered off-peak service on 80 of them, mostly wherever drivers happened to run out rather than where cuts would hurt least. The city's own review rules already set thresholds (70% overlap with the metro, fewer than five boardings per peak trip), but nobody measures, route by route, how many riders the overlapping segments actually carry or how many minutes drivers really get to rest at the terminals. TurnAround builds that evidence layer from the city's open real-time feeds and turns it into three things officials can act on: a per-route health card, a "trade overlap for rest" calculator, and proposal drafts that match the review rules. Data collection is done by the companion gem [n-gear](../gems/n-gear).

## 要解決的問題

台北公車缺司機，缺額依來源與時點在 12% 到近三成之間，路線又跟捷運疊床架屋。2023 到 2026 年市府對 288 條路線中的 147 條做了調整、80 條調降離峰服務水準，但調整的依據是「哪裡人不夠就減哪裡」，不是「哪裡最該減」。

市府的審議規則早就有兩個門檻：與捷運重疊 70% 以上可列為裁撤或縮短對象、尖峰每班次低於 5 人上下車可檢討。缺的是證據，沒有人持續、公開、逐路線地量「重疊路段實際載多少人」和「折返點實際能休幾分鐘」。有了這兩個數字，路線調整才有機會從「省錢」改寫成「把省下來的駕駛工時換成合法的休息與穩定的班距」，政治上比較推得動，也才處理得到駕駛過勞的問題。

完整的背景、附日期的數字、法規錨點與來源在 [docs/background.md](docs/background.md)。

## 交付物

1. 路線健檢卡：每條路線一頁，含與捷運的重疊度與競爭力、分時段載客剖面、班表達成、折返停留分佈、法規風險、折返點設施、建議動作。
2. 「換休息」試算：輸入縮駛某段、改區間、離峰改預約、每趟加 15 分鐘緩衝等動作，輸出車時與駕駛工時變化、休息達成率、受影響乘客數。
3. 提案草稿與每月公開報告：格式對齊《臺北市聯營公車申請分配調整路線及車次處理原則》，讓公運處、業者、工會、議員、研究者都能引用。

## 誰受益

1. 公車駕駛：休息時間第一次有人在量，而且可以拿去對照法規。想要班表加緩衝、終點站有廁所，手上也有數字可以講，不只是抱怨。
2. 公運處：面對民代和業者的時候，有逐路線、公開可以驗證的依據，不再只能被動減班。
3. 業者：可以排出合法又跑得完的班表，脫班罰款和留不住人的成本都有機會降下來。
4. 乘客：班距比較穩、脫班比較少、司機不用趕。離峰低運量的區段改成預約或小巴，而不是直接砍掉。
5. 工會、議員、研究者：每月的公開報告，以及可以釋出的原始資料。

代價也要算，被縮駛路段的乘客要多走幾步，失去路線的業者少了收入。這些要算出來放在提案裡，不能假裝沒有。工具本身不會讓任何人多休息一分鐘，要等有人做了決定才會有好處。如果資料被拿去單純減班，那就是用錯地方了。

## 明確不做

- 乘客用的到站 app 或即時地圖。
- 全網排班最佳化。那是排班研究的題目，本系統提供它需要的輸入。
- 依賴拿不到的票證 OD 或 TDX 歷史資料。

## 架構

```
data.taipei 公車即時 feed
  └─▶ n-gear：每 10 秒採集、去重、每小時 JSONL，兩小時後壓成 .jsonl.gz（唯一的資料來源，可重算、可釋出）
        └─▶ DuckDB：每晚批次算趟次、折返停留、載客剖面、重疊與競爭力
              └─▶ PostgreSQL：只放算好的衍生表
                    └─▶ Rails：健檢卡、試算、報告
```

網頁只查衍生表，不碰原始檔。為什麼這樣切，見 [docs/decisions.md](docs/decisions.md)。

## 資料來源與授權

原始資料是臺北市公共運輸處依「政府資料開放授權條款第 1 版」釋出的開放資料。各資料集、其他外部資料、顯名聲明的原文見 [docs/data-sources.md](docs/data-sources.md)。提供資料不代表該機關推薦、同意或核准本專案。

## 開發

技術棧與慣例見 [AGENTS.md](AGENTS.md)。

```sh
bin/setup   # gem、前端套件、git hooks、開發與測試資料庫
bin/dev     # Rails server 與 Vite
bin/ci      # RuboCop、bundler-audit、Brakeman、平行 RSpec、seeds
```

需求與計畫用 Spectra 管理：規格在 `docs/spectra/specs/`，進行中的 change 在 `docs/spectra/changes/`，專案脈絡在 `docs/spectra/config.yaml`。

## 文件

- [docs/background.md](docs/background.md)：問題、數字、法規錨點、要算的指標、限制、來源
- [docs/data-sources.md](docs/data-sources.md)：feed、資料集、授權與顯名聲明
- [docs/decisions.md](docs/decisions.md)：架構與命名的決定及理由
- [docs/use-cases.md](docs/use-cases.md)：十一個使用場景，含駕駛本人，誰、做什麼、何時、在哪、拿著什麼
- [docs/100-days.md](docs/100-days.md)：如果市府上任 100 天內要落地，需要哪個局處、哪些資料、多少成本

## 名字

折返點是公車掉頭的地方，也是司機在兩趟之間休息的地方，取這個名字也是希望這套制度能在這裡轉彎。英文 turnaround 同時有車輛折返和局面翻轉的意思。採集器叫「空檔 Neutral」，gem 名 n-gear，N 檔就是空檔。班表裡的空檔是司機能休息的時間，車子打空檔引擎才真的歇著。
