## Context

網站（Rails 8.1、Vite、PostgreSQL）到現在只在筆電上用 `bin/dev` 跑；`config/deploy.yml` 一直是 Kamal 範本，`zhongshan-route-page` 起每個 change 都把部署列為非目標。2026-10-24 主機定了：DigitalOcean 新加坡 sgp1 的一台 Droplet，Ubuntu 24.04、1 vCPU、2 GiB、48 GB（量自機器），沒有 Docker，也還沒有服務在聽，對外用一個 reserved IP。Cloudflare 的 bus.5xcamp.us A 記錄以 DNS only 指到 reserved IP，沒有 AAAA。筆電是 Apple Silicon，Docker 是 OrbStack，pg_dump 與 pg_restore 是 17.5；開發用的 Postgres 是 16.10。

這份 design 存在的理由是這個 change 做的全是部署層的決定：Postgres 放哪、image 在哪建、密碼怎麼流、資料怎麼進去、出事怎麼退。這些決定不在任何 spec 裡，寫在這裡給下一個 change（每晚自動跑 `derived:load`）接。capability 層的可觀察行為不變：路線頁與首頁的內容、定義、資料限制一個字都沒動。

## Goals / Non-Goals

目標：

- bus.5xcamp.us 以 https 提供現有的首頁與三條路線的頁面，資料跟筆電開發資料庫的五張衍生表一致。
- 部署設定進版本控制，image 對應一個 commit，密碼不進 git。
- 把主機的決定記進 docs/decisions.md，下一個 change 不用重新討論。

非目標：照 proposal 的 Non-Goals，不在這裡重抄。

## Decisions

### Postgres 用 Kamal accessory 跟網站同一台，image 是 postgres:16

accessory 名稱 `db`，容器在 kamal 的 docker network 裡叫 `website-db`，網站容器以這個名字連它；資料庫的埠只綁主機的 127.0.0.1，外面連不到，筆電要連先 `ssh -L`。資料目錄掛在主機的 Docker volume。版本選 16 是對齊開發用的 16.10，開發資料庫 pg_dump 出來的檔在同一個大版本裡還原，少一個變數。

理由：衍生表隨時能從原始檔重算（docs/decisions.md 第 2 條），資料庫壞掉的代價是重灌一次，不值得每月 15 美元的 Managed PostgreSQL 或備份附加。替代方案：Managed PostgreSQL（否決，理由如上，而且它的角色名與 sslmode 跟 database.yml 的 `username: website` 不合）；另開一台放資料庫（網站只讀 16 MB 的衍生表，不需要）。

### image 在筆電建、從 git HEAD 的乾淨 clone 建、推到 Kamal 的本機 registry

`builder.arch: amd64`、沒有 `builder.remote`、沒有 `builder.context`，`registry.server` 指向筆電本機。Kamal 2.12 在筆電本機起一個 registry 容器，build 時把它的埠用 SSH remote forward 送到主機，主機從那裡拉 image；不需要 Docker Hub、ghcr 或 DOCR 的帳號。沒 commit 的改動不會進 image，Kamal 會列出被忽略的檔案。

理由：主機只有 1 vCPU、2 GiB，在主機上 build 不會比較快，還可能跟網站與 Postgres 搶記憶體；從乾淨 clone 建讓每個 image 對應一個 commit，出問題能指回去。替代方案：`builder.remote` 指主機（否決，理由如上）；`builder.context: .` 從工作目錄建（否決，image 不再對應 commit，而且會把 hero 那批沒 commit 的改動一起帶進去）；外部 registry（否決，多一組 token 要管）。

### 密碼放 production credentials，.kamal/secrets 用 production.key 與 credentials:fetch

這個專案有 per-environment credentials：`config/credentials/production.yml.enc` 已有 `secret_key_base` 與 `tdx`。production 容器解它要用 `config/credentials/production.key`，所以 `.kamal/secrets` 的 `RAILS_MASTER_KEY=$(cat config/credentials/production.key)`；範本給的 `config/master.key` 只解共用的 `credentials.yml.enc`，容器會起不來。資料庫密碼加在 production credentials 的 `database.password`，`.kamal/secrets` 以 `bin/rails credentials:fetch database.password --environment production` 讀出來給 `WEBSITE_DATABASE_PASSWORD`；postgres accessory 的 `POSTGRES_PASSWORD` 用 Kamal 的別名語法 `POSTGRES_PASSWORD:WEBSITE_DATABASE_PASSWORD` 接同一個值。

理由：密碼只存在一個地方，而且是已經加密、已經在 git 裡的那個檔；`.kamal/secrets` 保持可以 commit。替代方案：從 shell 環境變數讀（每次要 export，忘了就空值）；1Password adapter（沒有設定過，多一個依賴）。代價：每次 kamal 指令都會起一次 Rails 讀 credentials，多幾秒。

### 資料庫位置用 DB_HOST 環境變數，database.yml 的 production primary 加 host 與 port

四個資料庫（primary、cache、queue、cable）都從 `&primary_production` 繼承，所以 host 與 port 加在 primary 上，一處改四處生效。不用 `DATABASE_URL`：它只覆蓋 primary，cache、queue、cable 會去連容器內的 socket。預設 localhost 與 PostgreSQL 的預設埠，是為了從筆電透過 `ssh -L` 連正式資料庫時只要改 `DB_PORT`。

### TLS 在 kamal-proxy 終止，Let's Encrypt 簽發，Cloudflare 維持 DNS only，Rails 開 assume_ssl 與 force_ssl

`proxy.ssl: true`、`proxy.host: bus.5xcamp.us`。kamal-proxy 自己向 Let's Encrypt 簽證書並把 http 轉到 https，條件是 host 已指到這台、https 連得進來。Rails 這邊 `assume_ssl` 讓它把 proxy 後面的請求當 https，`force_ssl` 送 HSTS、cookie 標 secure，`/up` 排除轉址。不開 `config.hosts`：kamal-proxy 只轉這個 host 的請求進來，開了只多一個擋掉健康檢查的風險。Cloudflare 不開代理：開了 Let's Encrypt 的挑戰要繞過 Cloudflare，deploy.yml 的註解說 SSL 模式得設 Full，這條路沒試過。

### 這次的資料用 pg_dump 從開發資料庫搬，不在主機上算

主機上沒有 DuckDB 也沒有原始檔，image 也不裝。五張表用筆電的 pg_dump（17.5）data-only 匯出，透過 `ssh -L` 用 pg_restore 灌進 `website_production`，`--disable-triggers` 讓外鍵順序不用擔心（website 是 postgres image 用 POSTGRES_USER 建出來的 superuser，可以用）。灌完用 Rails 的 `reset_pk_sequence!` 把五張表的序號對到現有的最大 id，之後的 `derived:load` 才不會撞 id。

理由：demo 要的是現有的資料出現在正式站；每晚自動算的位置（筆電或 mini 算好推上去、或主機上跑 DuckDB）是下一個 change 的題目。替代方案：在主機上裝 duckdb 並 rsync 原始檔（否決，是下一個 change 的範圍）；用 `derived:load` 透過 `ssh -L` 直接寫正式資料庫（可行，但要重算、比 dump 慢，而且 production 環境在筆電跑要處理 credentials）。

### reserved IP 同時是 DNS 與 deploy.yml 的目標

A 記錄與 `servers.web`、`accessories.db.host` 都用同一個 reserved IP。換機器時把 reserved IP 移過去，DNS 與設定都不用改。掛在機器上不收費，機器砍掉後沒釋放才每月 5 美元。

### docs/decisions.md 加第 12 條

寫到「DigitalOcean 新加坡一台 Droplet、Kamal、Postgres 同機、衍生表由筆電推上去、採集器留在 Mac mini」這個層級。IP 與網域在 config/deploy.yml 裡，從 DNS 就查得到，不是秘密；決定第 11 條「主機、路徑、PID 這類營運細節不進公開 repo」照舊適用於採集器那邊的細節。

## Implementation Contract

完成時可以觀察到的事：

- `git diff HEAD --stat` 對 config/deploy.yml、config/database.yml、config/environments/production.rb、.kamal/secrets 沒有輸出；`bin/kamal config` 的 `:version` 等於 `git rev-parse HEAD`。
- `bin/kamal secrets print` 列出的 `RAILS_MASTER_KEY` 與 `WEBSITE_DATABASE_PASSWORD` 都不是空字串，後者等於 `bin/rails credentials:fetch database.password --environment production` 的輸出。
- 主機上 `docker ps` 有 kamal-proxy、網站容器、`website-db` 三個在跑；`bin/kamal app details` 與 `bin/kamal accessory details db` 各顯示一個 running 的容器。
- `curl -sI https://bus.5xcamp.us/up` 回 200；`curl -sI http://bus.5xcamp.us/up` 回 3xx、Location 是 https；`curl -sv https://bus.5xcamp.us/up` 的證書 issuer 是 Let's Encrypt；`curl -sI https://bus.5xcamp.us/` 帶 `strict-transport-security`。
- `/`、`/routes/15373`、`/routes/10712`、`/routes/11764` 都回 200；灌資料之後三個路線頁的回應含 `data-section-nav`（只在有資料時輸出的區塊導覽），首頁含三條路線的 Id。
- `bin/kamal app exec "bin/rails runner 'p [RouteDay.count, RouteDayStop.count, Trip.count, Layover.count, TripStopCount.count]'"` 的五個數字跟筆電 `bin/rails runner` 同一行的輸出一致。
- `bin/kamal logs` 在驗收期間沒有 500 或例外。

失敗的樣子與該看哪裡：

- `kamal setup` 在 push 失敗：本機 registry 或 SSH 轉送的問題，看筆電上的 kamal 輸出與 `docker ps` 有沒有 registry 容器。
- postgres 容器反覆重啟：`bin/kamal accessory logs db`，看到「superuser password is not specified」就是 `WEBSITE_DATABASE_PASSWORD` 是空字串，回到 secrets 那一步。
- 網站容器起不來、`app logs` 有 `ActiveSupport::MessageEncryptor::InvalidMessage`：`RAILS_MASTER_KEY` 給錯把鑰匙，確認 `.kamal/secrets` 讀的是 production.key。
- `/up` 走 http 通、https 不通：證書還沒簽下來，`bin/kamal proxy logs` 看 ACME 的錯誤；先確認 `dig +short bus.5xcamp.us` 是那個 reserved IP、https 從外面連得到。
- pg_restore 拒絕或報版本：改在開發 Postgres 的容器裡用 16 的 pg_dump 產檔。

範圍內：上面列的設定、第一次部署、資料搬入、docs/decisions.md 一條。範圍外：proposal 的 Non-Goals。capability 層的可觀察行為不變：頁面內容、指標定義、資料限制都沒改；development 與 test 環境的設定沒改。

## Risks / Trade-offs

- [第一次 build 在 OrbStack 模擬 amd64 編原生 gem 加 vite build，原估幾十分鐘] -> 2026-10-24 量到：`bin/kamal setup` 從開始到網站容器健康共 4 分 52 秒（00:54:41 到 00:59:33），其中主機裝 Docker 70 秒，build 加 push 約 3 分鐘；估計過於悲觀，OrbStack 的 Rosetta 模擬夠快，不需要 builder.remote。
- [pg_dump 與 pg_restore 是 17.5、伺服器是 16，data-only 還原預期可行但沒試過] -> 任務 4.1 寫了退路：在開發 Postgres 容器裡用 16 的 pg_dump 產檔。
- [Kamal 推到筆電本機 registry 這條路在 OrbStack 上沒跑過] -> setup 失敗在 push 時先看這裡；真的不行再改 registry 到 ghcr 或 DOCR，那是另一個決定。
- [主機一開機就被全網的 SSH 掃描器敲門，第一小時 185 筆、同時掛著約 38 個未認證連線（2026-10-24 量自 journalctl 與 ps），超過 sshd 預設 MaxStartups 10:30:100 的門檻，sshd 隨機丟新連線，第一次 `bin/kamal setup` 在第二個連線就被 reset；先前以為是 reserved IP 或防火牆，判斷錯了，兩個 IP 都會中] -> 2026-10-24 在主機加 /etc/ssh/sshd_config.d/55-turnaround.conf：MaxStartups 100:30:200、LoginGraceTime 20，`sshd -t` 後 `systemctl reload ssh`。密碼登入本來就關著（cloud-init），掃描器進不來，只是佔位子。更徹底的做法是 Cloud Firewall 把 22 限成自己的 IP，或換 SSH port 並設 Kamal 的 `ssh.port`，留給之後。
- [Let's Encrypt 對同一個網域的失敗次數有上限] -> 證書失敗不要反覆重跑 setup，先看 proxy logs 修掉原因。
- [force_ssl 送出的 HSTS 會讓瀏覽器一年內只走 https] -> 本來就只提供 https，沒有要回 http 的情境。
- [1 vCPU、2 GiB 同時跑 Puma、Solid Queue 的幾個 process 與 Postgres] -> 2026-10-24 部署後主機 `free -m`：總量 1967 MB、已用 742 MB、可用 1225 MB（沒有流量、資料庫還是空的時候量的）；夠用，有流量後再看一次，不夠就 resize，reserved IP 不用動。

## Migration Plan

部署步驟就是 tasks.md 的順序：commit 設定（1.1）與加密碼（2.1）可以同時做，然後 `bin/kamal setup`（3.1），驗 https（3.2），灌資料（4.1），正式站看一次（5.1），記決定（6.1）。

回退：`bin/kamal remove` 會拿掉主機上的網站容器、accessory 與 proxy（資料目錄也會刪），機器留著；要連機器也不要就在 DigitalOcean 砍掉 Droplet 並釋放 reserved IP，不然 IP 每月 5 美元。repo 這邊 revert 那一個 commit 就回到 Kamal 範本；credentials 裡的 database.password 留著無害。DNS 記錄不用動，指到一個沒服務的 IP 只是連不上。資料出錯只需重跑 4.1：先在正式資料庫 TRUNCATE 五張表（`trip_stop_counts`、`layovers`、`trips`、`route_day_stops`、`route_days` 的順序，或 TRUNCATE ... CASCADE）再 restore。

## Open Questions

- 每晚自動跑 `derived:load` 要在哪裡算（筆電或 Mac mini 算好推上來，或主機上裝 DuckDB 並 rsync 原始檔），這個 change 不決定，留給下一個 change；3.1 量到的記憶體與 build 時間是它的輸入。
- 第一次 build 若超過能接受的時間，是否改用外部 registry 加 GitHub Actions 之類在 amd64 機器上建 image，等 3.1 的數字再說。
