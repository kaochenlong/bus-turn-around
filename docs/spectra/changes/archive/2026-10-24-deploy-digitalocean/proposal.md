## Why

這個 change 服務三樣交付物的第一樣：路線健檢卡在網站上的路線頁，以及帶路線清單的首頁。中山幹線（15373）、251（10712）、251區（11764）三條路線的頁面與首頁都做好了，但只在筆電上用 `bin/dev` 看得到。三件事都在等一個公開的網址：demo 審核 2026-10-24 下午截止，要交網址；`home-hero-turnaround-loop` 的任務 11.2 要用手機開正式站看動畫順不順、會不會發熱，手機透過區網連開發機載不到動畫；`zhongshan-route-page` 的非目標寫著「每晚自動跑等主機定了另開 change」，主機定了那個 change 才開得了。

主機 2026-10-24 定了：DigitalOcean 新加坡（sgp1）的一台 Droplet，Ubuntu 24.04、1 vCPU、2 GiB 記憶體、48 GB 磁碟（量自機器），用一個 reserved IP，網域 bus.5xcamp.us 的 A 記錄已在 Cloudflare 以 DNS only 指到它，沒有 AAAA。網站用 repo 裡的 Kamal 2.12 部署，Postgres 以 Kamal accessory 跟網站跑在同一台。

需要的資料：五張衍生表 `route_days`、`route_day_stops`、`trips`、`layovers`、`trip_stop_counts`。三條路線的日子已經由 `derived:load` 算進筆電的開發資料庫（2026-10-23 量：12 個路線日、1,396 趟次、1,045 筆折返停留、64,716 筆趟次站人數，資料庫 16 MB）。正式主機上沒有 DuckDB 也沒有原始檔，所以這次資料是從開發資料庫 dump 過去，不在主機上重算。不新增資料來源，也不改任何指標定義，所以沒有新的資料限制要寫；首頁與路線頁的資料限制照舊。

## What Changes

- 部署設定四個檔已在工作目錄改好、尚未 commit，這個 change 把它們 commit 進去（git 由使用者操作）：
  - config/deploy.yml：servers.web 是那個 reserved IP；proxy 開 ssl、host 是 bus.5xcamp.us，kamal-proxy 向 Let's Encrypt 簽證書並把 http 轉到 https；env 多一個 secret WEBSITE_DATABASE_PASSWORD 與 clear 的 DB_HOST=website-db；accessories.db 用 postgres:16（對齊開發用的 PostgreSQL 16.10）、資料庫的埠只綁主機的 127.0.0.1、資料目錄掛在主機上、POSTGRES_PASSWORD 以 Kamal 的別名語法讀同一個 secret；builder 維持本機 build、arch amd64；registry 維持 Kamal 的本機 registry（Kamal 在筆電起一個 registry 容器，用 SSH 轉送讓主機拉 image）。
  - config/database.yml：production 的 primary 加 host 與 port，讀環境變數 DB_HOST、DB_PORT（預設 localhost 與 PostgreSQL 的預設埠），cache、queue、cable 一起繼承。只設 DATABASE_URL 不夠，它只覆蓋 primary。
  - config/environments/production.rb：打開 assume_ssl、force_ssl，/up 不轉址；mailer 的 default_url_options host 改成 bus.5xcamp.us。
  - .kamal/secrets：RAILS_MASTER_KEY 改讀 config/credentials/production.key。這個專案用 per-environment credentials，production 讀的是 config/credentials/production.yml.enc，範本給的 config/master.key 只解共用那份，容器會起不來。WEBSITE_DATABASE_PASSWORD 從 production credentials 的 database.password 讀（bin/rails credentials:fetch database.password --environment production）。
- production credentials 加 database.password（隨機字串），同一個值給 postgres accessory 與 Rails。Kamal 對空字串的 secret 不會擋，credentials 裡沒有這個 key 時要等 postgres 容器起不來才看得到，所以 setup 之前先用 bin/kamal secrets print 確認有值。
- 用 bin/kamal setup 第一次部署：在筆電上建 amd64 的 image（OrbStack 的 Rosetta 模擬）、推到本機 registry，在主機裝 Docker、啟動 postgres accessory、kamal-proxy 與網站容器；網站容器的 entrypoint 跑 db:prepare，建四個資料庫並載入 schema。Kamal 從 git HEAD 的乾淨 clone 建 image，沒 commit 的改動不會進 image。
- 驗證正式站：https://bus.5xcamp.us/up 回 200、證書由 Let's Encrypt 簽發、http 轉到 https；首頁與三條路線的頁面回 200。
- 把開發資料庫的五張衍生表用筆電的 pg_dump（17.5）以 data-only 匯出，透過 ssh 轉送到主機只綁本機的資料庫埠，用 pg_restore --data-only --disable-triggers 灌進 website_production；用 bin/kamal app exec 跑 bin/rails runner，核對五張表的筆數跟開發資料庫一致。
- 在正式站打開首頁與三條路線的頁面看一次：路線卡有最新資料日，折返停留、載客剖面有數字；bin/kamal logs 沒有 500。
- docs/decisions.md 加一條：網站部署在 DigitalOcean 新加坡的一台 Droplet，用 Kamal，Postgres 跟網站同一台，衍生表由筆電算好推上去，採集器留在 Mac mini。主機細節只寫到這個層級；IP 與網域在 config/deploy.yml，兩者從 DNS 就查得到，不是秘密，密碼一律在 credentials（決定第 11 條「營運細節不進公開 repo」照舊）。

## Non-Goals

非目標，這個 change 不做：

- 每晚自動跑 `derived:load`、排程、把原始檔或 DuckDB 放到主機上：主機定了之後另開 change，接 `zhongshan-route-page` 的非目標。
- 搬 n-gear 採集器：2026-10-24 決定先留在 Mac mini。
- Managed PostgreSQL、Droplet 備份、Volume、Spaces：衍生表隨時能從原始檔重算（docs/decisions.md 第 2 條），資料庫掛了的代價是重灌一次。
- Cloudflare 代理（橘雲）或 CDN：維持 DNS only，Let's Encrypt 的挑戰直接打到主機。
- Rails 的 config.hosts：kamal-proxy 只轉 bus.5xcamp.us 的請求進來，開了只多一個擋掉健康檢查的風險。
- deploy.yml 的 asset_path 改指 public/vite：部署切換那幾秒可能 404 一個 chunk，首頁動畫的 spec 本來就有載不到的退路，先不處理。
- builder.remote 在主機上 build：1 vCPU、2 GiB，不會比較快還可能記憶體不夠。builder.context 設成 . 從工作目錄 build：image 就不再對應一個 commit，否決。
- 專屬網域、IPv6（AAAA）：之後再說，kamal-proxy 的 hosts 可以同時列兩個網址做過渡。
- 任何程式碼、spec 或畫面上的改動；development 與 test 環境的設定不變。

## Impact

- Affected specs: none
- Affected code:
  - New: (none)
  - Modified: config/deploy.yml、config/database.yml、config/environments/production.rb、.kamal/secrets（已改好、待 commit）；config/credentials/production.yml.enc（加 database.password）；docs/decisions.md（加一條）
  - Removed: (none)
- Compatibility: no capability-level observable behavior changes。production 從此強制 https、cookie 標 secure；development 與 test 不受影響。
- 外部系統：DigitalOcean Droplet（每月 12 美元，reserved IP 掛在機器上不收費）、Cloudflare DNS、Let's Encrypt。
- 第一次 build 要多久還沒量過（估計：模擬 amd64 編原生 gem 與 vite build 要幾十分鐘），setup 的任務記下實際時間，供下次估。
