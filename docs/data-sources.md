# 資料來源、授權與顯名聲明

整理日期：2026-10-18。

## 主資料：臺北市公車動態 feed

全部來自臺北市公共運輸處的公開網址 `https://tcgbusfs.blob.core.windows.net/blobbus/`，gzip 包 JSON，不需金鑰。欄位定義在公運處的「臺北市 Data.Taipei 平台 API 說明文件 V6.3」（2025-09）。由 [n-gear](../../gems/n-gear) 採集。

### 事件型（每輪都收）

| feed | 來源檔 | 內容 | 主要欄位 |
|---|---|---|---|
| `bus_event` | GetBusEvent.gz | 定點車機：每輛車每次到站、離站一筆 | StopID、CarOnStop（1 進站、0 離站）、DutyStatus、DataTime |
| `bus_seat_event` | BusSeatEvent.gz | 車上擁擠度：同上，但多了人數 | RemainingNum 車上人數、Level 擁擠等級 0/1/2 |
| `bus_data` | GetBusData.gz | 定時車機：GPS 位置 | Longitude、Latitude、Speed、Azimuth、BusStatus |

三支共用 BusID 車牌、RouteID 附屬路線、GoBack 去返程、StationID 所屬場站，DutyStatus 勤務狀態（文件：0 正常、1 開始、2 結束），BusStatus 行車狀態（文件：0 正常、3 塞車、99 非營運等）。

### 靜態（每天抓一份快照）

路線（含核定總班次、往返里程、尖離峰班距、路線類別）、站牌與站序、站位、公車路線軌跡、預定班表、機動班次時刻表（分時段班距）、車輛基本資料（含所屬調度站）、業者與營業站、路線與營業站對應、附屬路線站序、預估到站、車機異常、智慧型站牌、票價、營運通阻、最新消息、特殊時刻表。`ngear feeds` 會列出全部 23 支。

n-gear 每天 04:30 用 `ngear snapshot-static` 把這些檔整份複製一次，存在資料根目錄的 `static/<台北日>/<原始檔名>.gz`。衍生表與健檢卡讀其中三支：`GetRoute.gz`（路線名稱、起迄與附屬路線）、`GetStop.gz`（站牌與座標）、`GetPathDetail.gz`（附屬路線的站序），讀法在 `analysis/10_load.sql`。

data.gov.tw 的資料集頁面列的是 `TstRoute.json` 這類檔名，n-gear 照 API 說明文件 V6.3 抓的是 `GetRoute.gz`，兩者在同一個主機、同一個機關。動態那三支也是這樣，逐支的對照見授權一節。

### 實測的行為（2026-10-18）

- 動態 feed 每輛車只保留最新一筆，舊事件保留約十分鐘。blob 的 Last-Modified 約每 5 到 6 秒變一次。沒有任何地方存歷史。
- 相隔 55 秒抓兩次，1,072 台共同出現的車裡有 505 台站牌變了、307 台車上人數變了，變化量多在 ±1 到 4 人。也有車直接從某站跳到下下站，所以輪詢要壓到 10 秒左右，而且還是會漏站。
- 預定班表有 3.5 萬筆發車時刻、538 條附屬路線，但平均每條每個日型別只有約 10 筆，可能只涵蓋定時班次。班距型路線要看分時段班距與路線的尖離峰班距欄位。
- 路線 feed 有 791 條附屬路線、15 家業者，含新北業者的路線。
- 快照裡 DutyStatus 只出現 1 和 2，文件寫的 0 一筆都沒有。BusStatus 則出現了文件沒列的 92、93。
- 寫入速率約 2.4 MB/分鐘（GPS 佔六成），未壓縮一天 2 到 3 GB。gzip 之後，GPS 壓了 10.4 倍、到離站 12.2 倍、車上人數 12.0 倍。

### 授權

衍生表與健檢卡讀的六支 feed，在 data.gov.tw 各有一個資料集頁面：

| feed | 資料集頁面 | 頁面列的 JSON | 查證日期 |
|---|---|---|---|
| 定時車機資訊（GetBusData） | [臺北市定時車機資訊](https://data.gov.tw/dataset/128710) | TstBusData.json | 2026-10-24 |
| 定點車機資訊（GetBusEvent） | [臺北市定點車機資訊](https://data.gov.tw/dataset/128739) | TstBusEvent.json | 2026-10-24 |
| 公車車上擁擠度（BusSeatEvent） | [臺北市公車車上擁擠度](https://data.gov.tw/dataset/175726) | TstBusSeatEvent.json | 2026-10-24 |
| 路線（GetRoute） | [臺北市路線](https://data.gov.tw/dataset/129024) | TstRoute.json | 2026-10-24 |
| 站牌（GetStop） | [臺北市站牌](https://data.gov.tw/dataset/128743) | TstStop.json | 2026-10-24 |
| 附屬路線與路線對應（GetPathDetail） | [臺北市附屬路線與路線對應資訊](https://data.gov.tw/dataset/128741) | TstPathDetail.json | 2026-10-24 |

六頁的提供機關都是臺北市公共運輸處，授權方式都是政府資料開放授權條款第 1 版。頁面列的 JSON 跟 n-gear 抓的檔名不同，但在同一個主機，而且每一頁的資料集說明都指向公運處的「臺北市 Data.Taipei 平台 API 說明文件」，這份文件 V6.3 的 API 總表列的正是 n-gear 抓的 `GetBusData.gz`、`GetBusEvent.gz`、`BusSeatEvent.gz`、`GetRoute.gz`、`GetStop.gz`、`GetPathDetail.gz`。

- 授權方式：政府資料開放授權條款第 1 版（SPDX：`OGDL-Taiwan-1.0`），不限目的、不可撤回、免授權金，可重製、散布、改作、開發衍生物、再轉授權，與 CC BY 4.0 相容。
- 義務：顯名標示。條款第三條規定未盡顯名義務者，視為自始未取得授權。不得暗示機關推薦、同意或核准。
- 凡是用這批檔案做出來的東西，包括再散布的 JSONL 或 Parquet，都要帶下面這段，格式照條款附件：

> 臺北市公共運輸處 2026 臺北市公車開放資料：定時車機資訊（GetBusData）、定點車機資訊（GetBusEvent）、公車車上擁擠度（BusSeatEvent）、路線（GetRoute）、站牌（GetStop）、附屬路線與路線對應（GetPathDetail），見 Data.Taipei 平台 API 說明文件 V6.3
> 此開放資料依政府資料開放授權條款 (Open Government Data License) 進行公眾釋出，使用者於遵守本條款各項規定之前提下，得利用之。
> 政府資料開放授權條款：https://data.gov.tw/license

- 個資：資料裡是車牌、路線、場站、車上人數，沒有駕駛或乘客的識別資料。但同一車牌整天的軌跡，業者內部的人對得出是誰在開，所以對外公開時以路線、時段彙總，不要放單一車牌的逐日時間軸。
- 存取頻率：臺北市的開放資料規範管的是機關怎麼釋出，沒有對使用者的頻率限制條文。採集器帶識別用的 User-Agent、用 ETag 條件式請求、間隔 10 秒。知會公運處是禮貌，也可能換到歷史資料。
- 以上是對條款的理解，不是法律意見。

## 其他外部資料

### 第一張健檢卡就需要的

| 資料 | 用途 | 來源 | 狀態 |
|---|---|---|---|
| 上面的靜態 feed | 把事件串成趟要知道起訖站序，算脫班要班表，推調度站位置要車輛對應 | 同一個 blob | 待做每日快照 |
| 辦公日曆（平日、假日、補班） | 分平假日、對應班表日型別 | [data.gov.tw/dataset/14718](https://data.gov.tw/dataset/14718)，行政院人事行政總處，同一授權 | 已抓，一年一個 CSV，原檔是 UTF-8 帶 BOM、CRLF 換行，每年的檔案網址都不同。`bin/rails external:office_calendar YEAR=<年>` 檢查整年的日期、星期與「是否放假」之後，去掉 BOM、換成 LF，存到資料根目錄的 `external/office-calendar/<年>/<台北日>.csv`。日曆會在年中改版，改版的檔案有自己的網址，要先把 `OfficeCalendarSnapshot::DOWNLOAD_URLS` 裡那一年換成新網址，再下載、重跑受影響的日子 |
| 底圖圖磚 | 路線頁每一端地圖的底圖 | [OpenStreetMap](https://www.openstreetmap.org/copyright) 標準圖磚 `https://tile.openstreetmap.org/{z}/{x}/{y}.png`，地圖資料是 ODbL，顯名「© OpenStreetMap contributors」，照 [OSMF 圖磚使用政策](https://operations.osmfoundation.org/policies/tiles/)使用 | 不抓、不存：只在瀏覽器裡、地圖捲進畫面時才載看得到的圖磚，網址、顯名與最大縮放寫在 `config/map.yml`，頁尾與地圖右下角顯示同一段顯名。2026-10-24 查證：國土測繪中心臺灣通用電子地圖的開放資料版（圖層 EMAP6，[data.gov.tw/dataset/25108](https://data.gov.tw/dataset/25108)，政府資料開放授權條款第 1 版）只到圖磚第 15 等級，16 級以上適用國土測繪圖資服務雲的[使用條款](https://maps.nlsc.gov.tw/pro/use_clause.jsp)（附上來源之外，還有不可移轉、只能用在宣傳或表示使用該系統的服務、可隨時限量或改收費），不是只要求顯名，所以改用 OpenStreetMap |
| 捷運車站出入口座標 | 站牌到出口距離 | [data.gov.tw/dataset/128428](https://data.gov.tw/dataset/128428)，北捷，同一授權 | 已抓，原檔是 Big5 編碼的 CSV，`bin/rails external:mrt_exits` 轉成 UTF-8 存到資料根目錄的 `external/taipei-mrt-exits/<台北日>.csv`，資料不定期更新 |
| 全國公廁建檔資料（一列一間廁所，含經緯度與類別） | 折返點設施：每一端位置 500 公尺內的公廁 | [data.gov.tw/dataset/30794](https://data.gov.tw/dataset/30794)，環境部，同一授權 | 已抓。沒有整份檔案，只有環境部資料開放平臺的 API `https://data.moenv.gov.tw/api/v2/fac_p_07`，`api_key` 跟著資料集頁的下載連結公開，不是祕密。一頁最多 1,000 列，`bin/rails external:public_toilets` 照 `number` 排序翻頁、逐頁檢查，整份收齊、`number` 嚴格遞增才寫一次，存到資料根目錄的 `external/public-toilets/<台北日>.csv`（UTF-8、無 BOM、LF）。每月更新。一列是一間廁所（男廁、女廁、無障礙廁所分開），路線頁把同一地址的併成一處。沒有開放時段，也看不出駕駛能不能借用 |
| 捷運站間行駛時間、班距 | 門到門競爭力 | TDX（免費帳號，有審核）。北捷另有「相鄰兩站間之行駛時間、停靠站時間」資料集，正式頁面還待確認。另有[轉乘步行時間](https://data.gov.tw/dataset/128417) | 要申請帳號 |
| 捷運分時 OD 月檔 | 重疊走廊的捷運實際流量 | [data.gov.tw/dataset/128506](https://data.gov.tw/dataset/128506) | 每月 CSV |

公廁原本用臺北市的公廁點位（data.gov.tw/dataset/138798），2026-10-24 換成全國檔，因為有路線頁的停車端有兩個在新北市。下表是那天用各方向末站的座標（2026-10-23 的靜態快照）對兩份檔量到的直線距離，「處」是不同地址，「間」是全國檔的一列。正式的數字以 `derived:load` 從折返點位置算出來的為準，位置可能離末站一百多公尺：

| 端點 | 300 公尺內，全國檔 | 500 公尺內，全國檔 | 300 公尺內，臺北市檔 | 500 公尺內，臺北市檔 |
|---|---|---|---|---|
| 職能發展學院二（中山幹線停車端，士林） | 2 處 33 間 | 2 處 33 間 | 1 處 | 1 處 |
| 福安居一（251 與 251區 停車端，深坑） | 1 處 2 間，正洋加油站 200 公尺 | 9 處 28 間 | 0 處，最近 2,549 公尺 | 0 處 |
| 臺北客運板橋前站(藝文)（307 一端，板橋） | 4 處 13 間 | 9 處 22 間 | 0 處 | 0 處 |
| 莊敬里（307 另一端，松山） | 0 處 | 4 處 9 間 | 0 處 | 3 處 |

### 第二階段

| 資料 | 用途 | 來源 |
|---|---|---|
| 公有停車場 | 大車暫停空間 | 停管處 |
| 最小統計區人口 | 覆蓋率 | 內政部社會經濟資料服務平台 |
| OSM 公車調度站、停靠灣 | 補市府沒有的場站幾何 | Overpass API |
| 聯營公共汽車行車效率按路線分（表號 20621-01-04） | 逐路線行駛段次、行駛里程、載客人數、客運收入、每公里營收，可以拿來校驗車上人數的加總 | 公運處年度公務統計報表，PDF |
| 行車間隔四等級標準表 | 服務等級的正式門檻 | 未開放，要問公運處 |
| 票證 OD、捷運轉公車轉乘紀錄 | 替代性與轉乘的真值 | 拿不到，介面先留著 |

## 不需要抓的

- 既有 app 的轉乘查詢，一次只回答一趟、只回答現在，而且不當成資料開放出來，Google Directions API 的條款也禁止大量存下來分析。我們用捷運站間時間、班距、出口座標，自己算一個全面但粗略的門到門模型。
- 台北捷運 Go 每個出口的「可轉乘公車」對照表，用出口座標和站牌座標算距離就能得到一樣的東西。
- 臺北市公廁點位資訊（[data.gov.tw/dataset/138798](https://data.gov.tw/dataset/138798)，環保局）。它只收到臺北市界，福安居一（深坑）與臺北客運板橋前站（板橋）這兩個端點 300 與 500 公尺內都是 0 處，不是沒有廁所，是檔案沒收。全國公廁建檔資料已經涵蓋臺北市，不再拿它來補。
