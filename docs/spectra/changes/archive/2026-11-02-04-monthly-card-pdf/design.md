## Context

Mac mini 每小時跑 `bin/nightly-load`（`docs/decisions.md` 第 14 條），透過 ssh 轉送連正式站的 PostgreSQL。mini 上的 ssh 金鑰只准轉送資料庫的埠，不能開 shell，所以它能寫資料庫、不能把檔案放到 Droplet。mini 有 `Google Chrome.app`，沒有 chromedriver（2026-11-02 查的）。Droplet 是 1 vCPU、2 GiB，上面還有 Puma、Solid Queue 與 Postgres。

2026-11-02 在筆電上實測：Chrome headless 印路線頁 3.1 秒、14 個 process 的 RSS 加總峰值約 2 GB（共用記憶體會重複算，實際比較少，Linux 上沒有量）；印月卡試印 5 頁、2.48 MB，字型是 Type 3。指令是 `--headless=new --disable-gpu --no-first-run --no-default-browser-check --no-pdf-header-footer --virtual-time-budget=10000 --user-data-dir=<暫存> --print-to-pdf=<輸出> <網址>`。mini 上還沒實測。

正式站資料庫不備份（第 12 條），理由是衍生表隨時能從原始檔重算。定稿的 PDF 與 `route_cards` 不在這個理由裡：重算出來的不會是同一份。

`RouteCard.newest` 與 `CardTrend` 都整列讀 `route_cards`，月卡頁每開一次就讀這條路線每個舊月份的列（2026-11-02 讀程式碼）。

既有的決定：

- `timetable-draft`「列印用瀏覽器與列印樣式表，一車一頁」：理由是不加 gem、不在 Droplet 上裝 headless Chrome，替代方案 Prawn 或 Grover（新依賴、部署要多裝東西）否決。那是給現場改、每次內容都不同的班表；這裡照舊適用於班表頁與當天調度。
- `timetable-draft` 的非目標「伺服器端產 PDF。」與 `03-day-dispatch-record` 的非目標「匯出之後再匯入、伺服器端產 PDF、.xlsx、存到網站、分享、帳號。」：使用者 2026-11-02 同意為定稿的月卡重開。
- `ui-touchups`、`site-bar-github-about` 的非目標「名稱列不做選單；車牌查詢、回報表單、月報等連結有了再說」：這次有了，加的是連結，不是選單。
- `nightly-derived-load` 的 launchd 排程與 `ProductionTunnel`、一次只跑一個的鎖、migration 版本檢查，這裡都照用。

## Goals / Non-Goals

**Goals:**

- 每個月自動產生每條路線上個月的定稿 PDF，不用人按。
- 資料沒到齊就不印；印過就不再變，更正有紀錄。
- 資料庫重建之後，定稿的檔不會被重印或蓋掉，而且存得回去。
- 名稱列點得到月份清單，每個月有固定的下載網址。

**Non-Goals:**

- 班表頁與當天調度改用伺服器產 PDF：照舊用瀏覽器列印。
- 在 Droplet 裝 Chrome、加 PDF gem、用 Solid Queue 印。
- 用外部儲存（R2、Spaces、GitHub Releases）。
- 全網月報、跨路線比較、訂閱、通知。
- 2026-10 之前的月份列進清單：資料從 2026-10-19 才開始收。
- 下拉式選單。

## Decisions

### 定稿的 PDF 在 Mac mini 用 Chrome 印好存進資料庫

**Supersedes**: timetable-draft / 伺服器端產 PDF。

`CardPrinter` 在 mini 上跑 Chrome 開正式站的月卡頁，印成 PDF；`bin/monthly-cards` 把位元組存進正式站資料庫，Rails 下載時直接回傳，不跑 Chrome。`03-day-dispatch-record` 那條非目標裡「伺服器端產 PDF」這一項同樣為月卡重開，其他項目（匯入、.xlsx、存到網站、分享、帳號）照舊，所以不標成推翻那一整條。

理由：引用要每個人拿到同一份。瀏覽器列印每次重算、版面因瀏覽器而異，也不是下載。mini 已有 Chrome，正式站不用多裝東西，所以 `timetable-draft` 否決 Prawn、Grover 的理由仍然成立。資料庫是 mini 唯一到得了正式站的路，不用多開一條路或多一個祕密。

替代方案：

- 網站自己排程（Solid Queue `config/recurring.yml`）印：要把 Chrome 裝進 image，推翻「不在 Droplet 上裝 headless Chrome」；2 GiB 的機器放不下 Chrome 的峰值的風險；而且 Droplet 分不出「還沒載入」與「不會來了」。否決。
- 存 Kamal 的 `website_storage` volume：mini 的金鑰不能寫檔；volume 跟資料庫在同一台機器上，機器壞了一起不見，也沒有多一層保護。否決。deploy 不會丟檔：deploy 不動資料庫（第 12 條），Postgres 的資料在 accessory 掛的主機目錄。
- R2、Spaces、GitHub Releases：mini 上要多一個祕密（第 14 條：mini 上只有一個祕密）。否決。2026-11-02 使用者再看過一次，決定維持存資料庫：下載不跑 Chrome、deploy 不會丟檔，外部儲存解的是另外的問題（Droplet 以外多一份隨時下載得到的檔、下載不經過網站）；下載量大到不想經過網站，或不想只靠 mini 留備份時再開。

### PDF 的位元組放在自己的表

`route_card_pdfs` 一份一列：`route_card_id`（唯一、外鍵到 `route_cards`）、`pdf`（bytea）。`route_cards` 只多 `pdf_sha256`、`pdf_bytes`、`program_version`、`printed_at`、`revision_reason`。只有下載會讀 `route_card_pdfs`。

理由：`RouteCard.newest` 與 `CardTrend` 都整列讀，位元組留在 `route_cards` 的話，每開一次月卡頁就多讀一份約 2.4 MB 乘上印過的月份數，而且不會報錯，只會慢。每個讀 `route_cards` 的地方都要記得排除那一欄，下一個忘記的人不會有任何提醒。這仍然是存資料庫，不改上一條的決定。`route_card_pdfs` 只連到 `route_cards`，`bin/push-derived` 沿 `route_days` 的外鍵走，帶不走它。

替代方案：`route_cards` 加 `pdf` 欄，查的時候用 `select` 排除：否決，理由如上。

### 每小時檢查，資料到齊才印，不固定日期

`bin/monthly-cards --print` 接在 mini 每小時的 `bin/nightly-load` 後面跑。每條頁面路線、從 `first_month` 到上個月（台北時間）的每個月，沒有印過的就算涵蓋（`RouteCardCoverage`）：還在等就印一行跳過；到齊就印。印過就不再動作，所以實際上一個月只印一次。

理由：11-30 的資料要到 12-01 02:00 讀檔視窗結束之後才載入；載入停著（例如 2026-11-02 的 migration 不一致）時固定日期會把缺資料的月份定稿；mini 沒開時下一次補。沿用第 8、14 條每小時加冪等的做法。

`bin/nightly-load` 結束碼非零（10-30 那種原始檔不齊會讓它每小時 exit 1）時，`--print` 照樣要跑。repo 外的 script 開了 `set -e`，所以不能用 `&&` 串，也不能直接寫在下一行；要分別記下兩個結束碼，都跑完再決定整支的結束碼。涵蓋本身已經分得出原始檔不齊與還在等。

### 跟 bin/nightly-load 共用一把鎖

`bin/monthly-cards` 拿同一個 `tmp/nightly-load.lock`；另一個在跑就印一行、什麼都不做、結束碼 0。鎖、轉送與 migration 版本檢查從 `NightlyLoadCommand` 移到 `ProductionSession`，兩個指令共用，訊息裡的動詞（載入、印）由指令給。

理由：手動 `--recompute` 可以跑半小時，這段時間印出來的月卡可能讀到正在換的路線日；兩個指令也用同一個本機埠，分開的鎖只會變成埠被占用的錯誤。

### 第一份是 2026 年 11 月，設定放 config/route_cards.yml

`config/route_cards.yml`：`first_month`。格式不對時指令停下來並說明，比照 `DerivedDays`。清單頁的「第一份什麼時候出」也讀它。新路線上線時舊月份的衍生表也算得出來，一樣從 `first_month` 起補印。

原本是 `2026-11`，理由是 10 月只有 7 個平日（20 個裡），不符合每月一份的意思，只試印。使用者 2026-11-02 看過清單頁之後，決定不等 12 月，第一份提前成 2026 年 10 月（`first_month: 2026-10`）：接上排程的下一個小時就印，每條路線都標部分月份，第 1 頁寫明少了哪幾天。這個標題留著 11 月，因為完成的任務 1.1 照原文引用它。

### 印之前確認頁面是那一份，印好確認是 PDF

順序：

1. `RouteCard` 建或更新 `coverage`（未印的版本）。
2. `Net::HTTP` GET 月卡頁（連線限 10 秒、讀取限 120 秒），要 200，而且 `<meta name="turnaround-card" content="<路線 Id>/<YYYY-MM>/<version>">` 相符，頁面也沒有「數字不完整」的提醒（`data-card-incomplete`）。不符就記失敗，不印。
3. Chrome 印到暫存檔，限 120 秒，結束碼要 0；檔案開頭要是 `%PDF-`，大小至少 100 KB（字型就超過這個數字，只用來擋空白或錯誤頁）。
4. 同一個交易寫 `route_cards` 的 `pdf_sha256`、`pdf_bytes`、`summary`、`program_version`、`printed_at` 與 `route_card_pdfs` 的位元組；交易成功後寫本機副本。

理由：Chrome 會很樂意把 500 頁或 404 頁印成 PDF，還回傳 0。排程沒有人看著，卡住的 Chrome 不能把下一個小時也拖住，所以有時限。一條路線失敗不擋其他路線（同「One failing route day does not stop the others」），結束碼非零。

### 存的摘要與程式版本都從頁面讀

月卡頁多帶 `turnaround-program-version`（`ENV["KAMAL_VERSION"]` 前 7 碼）與 `turnaround-card-summary`（`RoutePage::MonthCard#summary` 的 JSON）兩個 meta。`CardPrinter` 檢查頁面時一起讀，存進 `route_cards`。

理由：mini 的 checkout 每小時跟上 origin/main，正式站要 deploy 才換版，migration 一樣時兩邊可以是不同版。從頁面讀，存下來的就是印出來那一份的數字與版本；`CardTrend` 之後比對舊月份時才不會因為 mini 版本不同，多寫一句「當時的數字不同」。

### 印過的版本不再改，更正要出新版並寫原因

有 PDF 的列，指令永遠不動它，模型層也擋：`RouteCard#readonly?` 對已印的列回 true，`update!` 會失敗。`ROUTE=<Id> MONTH=<YYYY-MM> REASON=<原因> bin/monthly-cards --revise` 新增 `version + 1` 一列（`revision_reason` 是原因），走同樣的流程。這一次失敗時那一列留著沒有 PDF，下一次 `--revise` 接著用它、換上新的原因，不多一個版本號。清單與下載預設給最新版，清單列出舊版與更正原因，舊版還下載得到。

理由：引用過的檔案不能悄悄變。定義改了不用出新版：舊檔是當時的數字，下個月的逐月表會註明（`03-monthly-card` 的決定「上月與逐月表用現在的定義重算，跟當時不同就註明」）。`--revise` 只給算錯或資料有誤的情況。

### 本機副本不覆寫，資料庫不見時灌回去

印好之後，PDF 與一份 JSON（`route_id`、`month`、`version`、`coverage`、`summary`、`program_version`、`printed_at`、`revision_reason`、`pdf_sha256`、`pdf_bytes`）寫到 `<TURNAROUND_DATA>/cards/<YYYY-MM>/<路線 Id>-v<version>.pdf` 與同名的 `.json`。兩個檔都先寫暫存檔，再用 hard link 放到位；已經有同名檔就失敗，不覆寫。

每個月份算狀態時先看 mini 上有哪些版本的檔：資料庫沒印過、mini 上有檔，就是「正式站沒有這一版」，不印也不更正，計畫與 `--print` 點名那一版並指向 `--restore`，結束碼非零，排程的 log 看得到。

`bin/monthly-cards --restore` 走過 `cards/` 底下每一份：PDF 的 SHA-256 要跟 JSON 寫的一樣；資料庫沒印過這一版就照 JSON 存回去；印過而且 SHA-256 相同就不動；不同就失敗、不動。有 PDF 沒有 JSON 也是失敗。一份失敗不擋其他份。

反過來，`--print` 碰到已印的版本在 mini 上沒有檔（上次寫副本失敗，或 mini 的檔不見了），從資料庫補寫，不重印。

理由：第 12 條不備份的前提是重灌就好，定稿的檔不在這個前提裡。沒有這一條時，資料庫重建、資料重新載入之後，每小時的 `--print` 會把舊月份當成沒印過，重印 v1，再蓋掉 mini 上唯一的原檔。JSON 要一起留，因為 `summary` 重算會用今天的定義，`CardTrend` 就比不出差異，`program_version` 與 `revision_reason` 也算不回來。mini 上的檔在 `<TURNAROUND_DATA>` 底下，原始檔的鏡射也會帶到筆電（鏡射只排除 `external/`，2026-11-02 查的）；沒有程式掃資料根目錄時會被 `cards/` 弄混。

資料庫重建時的步驟：先等 `bin/nightly-load` 把衍生表載回去（或用 `bin/push-derived`），再跑 `bin/monthly-cards --restore`。

替代方案：只擋覆寫、不提供灌回去：否決，手動用 psql 把 mini 上的位元組灌進 bytea 不實際，擋住之後也還是要有路走。

### 試印不存：--sample 印到指定的檔

`ROUTE=<Id> MONTH=<YYYY-MM> OUT=<路徑> bin/monthly-cards --sample`：不看 `first_month`，走同樣的檢查與 Chrome，寫到 `OUT`，不存 PDF、也不寫本機副本。如果為了開頁面新增了 `route_cards` 列，印完刪掉；已經有的列不動。涵蓋還在等也照印，並印一行提醒。

理由：排程上線前要能驗證 mini 上的 Chrome 真的印得出來，而且不留下任何東西。

### 下載網址一個月一個，舊版用 version 參數

`GET /routes/:route_id/cards/:month.pdf`：最新的已印版本，`Content-Type: application/pdf`，`Content-Disposition: attachment; filename="turnaround-<路線 Id>-<YYYY-MM>.pdf"`，`ETag` 是 `pdf_sha256`，`Cache-Control: public, max-age=86400`。`?version=1` 拿指定版本。沒有已印版本、版本不存在回 404。先讀 `route_cards`，`If-None-Match` 相符就回 304，不讀 `route_card_pdfs`。

理由：引用要有固定網址，更正之後同一個網址拿到最新版；要對舊版也拿得到。快取一天，更正最晚隔天生效。

### 名稱列多一個連結，點了到月份清單，不做下拉

`SiteBarComponent` 在「當天調度」後面加連結「健檢卡」到 `/routes/<Id>/cards`，清單頁與月卡頁上帶 `aria-current="page"`（`current: :cards`）。出現在路線頁、班表頁、當天調度頁、清單頁、月卡頁。

月份清單 `GET /routes/:route_id/cards`，只列已印的版本，新到舊：「2026 年 11 月　21 個平日、9 個假日，少 11-05　下載 PDF（2.5 MB）」，部分月份標出來，更正過的列原因與舊版連結。開頭一句說明：「每條路線每月一份，彙整折返停留、連續行駛與班表對照。」還沒有檔案時：「第一份是 2026 年 11 月，12 月初印出來。」月份是 `first_month` 與上個月取較晚的那個。頁面路線以外回 404。

理由：檔案逐月累積，一個直接下載的連結只指得到最新一份；還沒有檔案時也要有地方交代。連結文字用詞彙表的「健檢卡」，「報表」是列為不要用的詞。這個詞沒在網站上出現過，所以清單開頭要說明。

替代方案：下拉選單。否決：手機上放不下，也裝不下每個月的涵蓋，非目標也說過不做。

### 手機上縮標誌、間距與字級

640px 以下：標誌高度 `h-9`（約 105px 寬，現在 `h-12` 約 140px）、連結字級 15px（現在 16px）、標誌與連結之間與連結之間都 12px（現在 16 與 20）。算出來的寬度（估的，system spec 量）：現在 356px；多一個連結不縮時 424px；縮完 350px。640px 以上不變。

理由：390 寬是現有的測試寬度，360 是常見的小手機，現在放得下，不能因為這個連結變差。

### 定稿與排程記進 decisions.md

`docs/decisions.md` 加第 15 條：月卡在 Mac mini 印、PDF 存資料庫、每小時檢查、印過不改、mini 留一份而且灌得回去，理由與替代方案照這份 design，不寫主機與路徑。第 12 條「資料庫壞掉的代價是重灌一次」與第 14 條「mini 上只有一個祕密」照舊，第 15 條寫明 `route_cards` 是第 12 條那句話的例外。`AGENTS.md` 的常用指令加 `bin/monthly-cards`。`docs/spectra/LANGUAGE.md`「健檢卡」補定稿、更正與下載。

### 用真資料驗收：mini 印得出中山幹線 10 月

deploy 之後，使用者在 mini 用 `!` 跑 `ROUTE=15373 MONTH=2026-10 OUT=<路徑> bin/monthly-cards --sample`：PDF 開得起來、不超過 6 頁、車牌掃描 0 筆，記下正式站開頁面的秒數與檔案大小。接上排程之後，下一個小時就會印 10 月的第一批。

## Implementation Contract

**行為**：

- 維運的人：`bin/monthly-cards` 印計畫，每條路線每個月一行：已印 vN、到齊可印、還在等（哪幾天）、數字還沒重算（哪幾天）、正式站沒有 vN（這台有它的檔）。還沒有到期的月份時印一行說第一份是哪個月。`--print` 印到齊的。指令只在 `RAILS_ENV=production` 跑（同 `bin/nightly-load`），環境變數同 `bin/nightly-load`，另加選用的 `CHROME_PATH`（預設 macOS 的 Chrome 路徑）與 `CARD_BASE_URL`（預設 `https://<config/deploy.yml 的 proxy.host>`）。
- 看網站的人：路線相關頁面的名稱列多「健檢卡」；清單列已印的月份；PDF 下載下來是定稿檔。

**資料形狀**：`route_cards` 多 `pdf_sha256`、`pdf_bytes`、`program_version`、`printed_at`、`revision_reason`；前四個要嘛全有要嘛全空，全有時 `summary` 也要有（check constraint）。`route_card_pdfs`：`route_card_id`（唯一、外鍵）、`pdf`（binary，不可空）。`summary` 是 `RoutePage::MonthCard#summary`：`CardTrend` 比對用的數字，鍵與四捨五入在 `03-monthly-card` 定。本機副本的 JSON 鍵見「本機副本不覆寫，資料庫不見時灌回去」。

**失敗模式與結束碼**：

| 情況 | 訊息 | 結束碼 |
| --- | --- | --- |
| 參數不對、環境變數缺、設定檔壞 | 用法或原因，轉送開之前就停 | 1 |
| 另一個 `bin/monthly-cards` 或 `bin/nightly-load` 在跑 | 印一行，什麼都不做 | 0 |
| migration 版本不一致 | 同 `bin/nightly-load` | 1 |
| 某條路線某個月還在等、數字還沒重算 | 計畫裡一行 | 不影響 |
| 這台有某一版的檔、資料庫沒印過這一版（包含只印計畫時） | 點名那一版與 `--restore`，不印 | 1 |
| 頁面不是 200、meta 不符、頁面說數字不完整 | 那一條路線那個月失敗，繼續下一條 | 1 |
| 找不到 Chrome、Chrome 非零、逾時、不是 PDF、太小 | 同上 | 1 |
| 本機副本已經有同名檔、寫不進去 | 同上，資料庫那一版留著 | 1 |
| `--restore`：PDF 跟 JSON 對不上、缺 JSON、資料庫同一版的 SHA-256 不同 | 點名檔案，不動，繼續下一份 | 1 |

**驗收**：`spec/models/monthly_cards_command_spec.rb`（`CardPrinter`、tunnel 都用替身）、`spec/models/production_session_spec.rb`、`spec/models/route_card_local_copy_spec.rb`、`spec/models/card_months_spec.rb`、`spec/models/card_printer_spec.rb`（用假的 chrome 腳本）、`spec/requests/route_cards_spec.rb`、`spec/requests/site_layout_spec.rb`、`spec/system/route_page_mobile_spec.rb`。

**範圍**：不改月卡內容與任何數字。

## Risks / Trade-offs

- [正式站開月卡頁太慢，超過 kamal-proxy 的逾時（預設 30 秒）] → 頁面只有印製時有人開；用 `--sample` 量秒數。`--sample` 量的是只有十天的 10 月，整個月的日子大約是它的三倍（估的，12-01 第一批印的時候才有實際數字）。超過時 `--print` 每小時失敗一次、結束碼非零，不會印出壞檔。超過再另外處理，目前沒有證據會超過。
- [`route_card_pdfs` 讓資料庫變大、`pg_dump` 變慢] → 一年約 200 MB（估的）；`bin/push-derived` 不帶這張表。其他查詢碰不到它。
- [Google Fonts 連不上時 Chrome 用系統字型印，版面會變] → 檢查抓不到這種情況；mini 跟正式站都連得上外網，發生時 `--revise`。之後可以改成自帶字型。
- [launchd 環境下 Chrome 跑不起來] → 排程上線前用 `--sample` 在 launchd 同樣的環境變數下跑一次；排程的 log 會有 Chrome 的錯誤。
- [頁面印製到寫入之間資料被重算] → 跟 `bin/nightly-load` 共用一把鎖，手動 `--recompute` 跑的時候不印。
- [印過的資料庫列被 `bin/push-derived` 或重算影響] → 沒有外鍵連到 `route_days`，兩者都不碰這兩張表（`03-monthly-card` 的規格）。
- [某一天的快照真的沒有公告檔，`published_schedule_day` 一直是空的] → 這個月一直跳過並點名，不會自己印，要人處理。`needs_reload?` 分不出這種情況與還沒重算；16 份快照都有這兩支檔（2026-11-02 查的），碰到再處理。
- [資料庫與 mini 上的檔一起不見] → 筆電的鏡射還有一份，放回 `cards/` 再 `--restore`；三處都沒了就回不來，那一版要重印成新的一版。

## Migration Plan

1. 先完成 `01`、`02`、`03`，deploy，mini 跑 `--recompute`。
2. deploy 這個 change。mini 的 checkout 每小時跟上 origin/main 之後，使用者跑 `--sample` 驗證，再把 `bin/monthly-cards --print` 接進 repo 外的 script。
3. 接上排程的下一個小時印出 10 月的第一批，檢查清單與下載。12-01 清晨自動印 11 月，那是第一個整月，也才知道整個月開頁面要幾秒。
4. 退回：拿掉 script 那一行、名稱列連結；`route_cards`、`route_card_pdfs` 留著不影響其他頁面。

## apply 時補的細節

- 版本號與月份的寫法只有一處：`RouteCard#identity`（`15373/2026-11/1`）與 `RouteCard#year_month`，頁面的 meta、`CardPrinter` 與本機副本都讀它們。
- `--print` 只印還沒印過的月份各一行，早就印過的不印，最後一行是總數：七條路線累積十幾個月之後，排程的 log 不能每小時多一百行。只印計畫時照規格每個月一行。
- `--restore` 碰到有 JSON 沒有 PDF 一樣算失敗，規格只寫了反過來的情況；少了哪一個都要有人看。
- `--sample` 的 `OUT` 目錄不存在時，在開轉送之前就停。
- 清單裡舊版的列也寫自己的更正原因，不是只有最新版：更正過兩次時，第一次的原因不能看不到。
- 名稱列的連結加 `whitespace-nowrap`、標誌的連結加 `shrink-0`：不加的話中文會自己折行、圖會被壓扁，整頁還是沒有橫向捲動，放不下這件事就看不出來。2026-11-02 拿舊尺寸驗過，這樣才會失敗（連結的右緣超出畫面）。
- 大小的算法是 1,000,000 bytes 一 MB，四捨五入到一位小數。
- 印好與試印好的那一行帶開頁面的秒數（`CardPrinter::Printed#page_seconds`）：5.1 要記這個數字，排程的 log 也看得出來離 kamal-proxy 的 30 秒逾時多遠。

## 本機驗收（2026-11-02，筆電、開發庫，轉送用替身，沒有連正式站）

- 真的 Chrome 走 `CardPrinter`：15373 與 16111 的 2026-10 印好 v1，2,370,066 與 2,413,206 bytes，跟 `03-monthly-card` 印的兩份同樣大小；存的摘要有 `weekdays` 7、15373 的 `short_share` 43.1、`morning_on_road` 10。兩份連 Rails 開機共 8 秒（量到的）。
- 下載：`ETag` 是 SHA-256，檔名是 `turnaround-15373-2026-10.pdf`，內容跟本機副本 SHA-256 相同；帶 `If-None-Match` 回 304、0 bytes。
- 資料庫清空：只印計畫與 `--print` 都點名 `--restore`、結束碼 1，沒有重印、沒有多一列、原檔 SHA-256 不變。`--restore` 存回 2 份，印製時間、程式版本與 SHA-256 都一樣；再跑一次是本來就有 2 份；之後的 `--print` 是早就印過 2 份。
- `--revise` 出 v2，v1 的 SHA-256 不變。`--sample` 印一個沒有列的月份，檔案寫出來，資料庫沒有多一列。
- 名稱列實測：1400 寬標誌 140×48、字級 16px，跟原本一樣；390 與 360 寬標誌 105×36、字級 15px，五個連結都顯示，360 寬時最右邊的連結右緣在 344px。
- mini 上的 Chrome 與 launchd 環境要等 5.1。

## Open Questions

- 換靜態字型能把檔案縮到多小：等第一批真的印出來再決定要不要做。
