## 1. 設定進版本控制

- [x] 1.1 使用者把 config/deploy.yml、config/database.yml、config/environments/production.rb、.kamal/secrets 這四個檔 commit（git 由使用者操作，可以跟 hero 那批改動分開 commit；agent 不碰 git）。這四個檔落實 design 的「資料庫位置用 DB_HOST 環境變數，database.yml 的 production primary 加 host 與 port」與「reserved IP 同時是 DNS 與 deploy.yml 的目標」：database.yml 的 production primary 有 host 與 port 兩行讀 DB_HOST、DB_PORT，deploy.yml 的 servers.web 與 accessories.db.host 都是同一個 reserved IP。完成時 image 會對應到含這些設定的 commit：`git diff HEAD --stat -- config/deploy.yml config/database.yml config/environments/production.rb .kamal/secrets` 沒有輸出，`bin/kamal config` 印出的 `:version` 等於 `git rev-parse HEAD` 的輸出。驗證：上面兩個指令。

## 2. 資料庫密碼

- [x] 2.1 production credentials 有 `database.password`，值是隨機字串（`openssl rand -hex 24` 產生），用 `bin/rails credentials:edit --environment production` 加進 config/credentials/production.yml.enc。完成時 `bin/rails credentials:fetch database.password --environment production` 印出那串、結束碼 0；`bin/kamal secrets print` 列出的 `RAILS_MASTER_KEY` 與 `WEBSITE_DATABASE_PASSWORD` 都不是空字串，後者等於 fetch 的輸出。驗證：上面兩個指令。fetch 失敗時 Kamal 會把空字串傳給 postgres 容器而不報錯，所以這一步沒過就不要跑 3.1。

## 3. 第一次部署

- [x] 3.1 跑 `bin/kamal setup` 並記下開始與結束的時刻：它在筆電建 amd64 的 image、推到 Kamal 的本機 registry，在主機裝 Docker，起 postgres accessory（容器名 website-db）、kamal-proxy 與網站容器，網站容器的 entrypoint 跑 db:prepare 建 website_production 與 website_production_cache、website_production_queue、website_production_cable。完成時 `bin/kamal app details` 與 `bin/kamal accessory details db` 各顯示一個 running 的容器；`bin/kamal app logs` 沒有例外，特別是沒有 `InvalidMessage`（那是 RAILS_MASTER_KEY 給錯把鑰匙）；`bin/kamal accessory logs db` 沒有「superuser password is not specified」（那是密碼成了空字串）。build 花的時間與主機上 `free -m` 的數字寫回 design.md 的 Risks 那兩條，取代「沒量過」。驗證：上面三個指令與 design.md 的更新。setup 中途斷線直接重跑 `bin/kamal setup`。[after: 1.1, 2.1]
- [x] 3.2 正式站以 https 提供服務，照 design 的「TLS 在 kamal-proxy 終止，Let's Encrypt 簽發，Cloudflare 維持 DNS only，Rails 開 assume_ssl 與 force_ssl」：`curl -sI https://bus.5xcamp.us/up` 回 200；`curl -sI http://bus.5xcamp.us/up` 回 3xx 且 Location 以 https:// 開頭；`curl -sv https://bus.5xcamp.us/up 2>&1 | grep -i issuer` 含 Let's Encrypt；`curl -sI https://bus.5xcamp.us/` 回 200 且有 strict-transport-security 標頭；`/routes/15373`、`/routes/10712`、`/routes/11764` 都回 200，此時還沒資料，回應不含 `data-section-nav`，首頁三張路線卡帶 `data-no-data`。證書在 setup 後可能要等一兩分鐘才簽下來（估計，以實際為準）；https 一直不通看 `bin/kamal proxy logs` 裡 ACME 的錯誤，不要反覆重跑 setup。驗證：上面的 curl。[after: 3.1]

## 4. 衍生表

- [x] 4.1 照 design 的「這次的資料用 pg_dump 從開發資料庫搬，不在主機上算」，開發資料庫的五張衍生表搬進正式資料庫，筆數一致、序號對齊。做法：`PGPASSWORD=postgres pg_dump -Fc --data-only -h localhost -U postgres -t route_days -t route_day_stops -t trips -t layovers -t trip_stop_counts website_development > tmp/derived.dump`（tmp/ 在 .gitignore）；另開一個終端用 ssh 轉送，把主機只綁本機的資料庫埠接到筆電本機的一個埠；`pg_restore --data-only --disable-triggers -h localhost -p <轉送的本機埠> -U website -d website_production tmp/derived.dump`，密碼是 2.1 的值（website 是 postgres image 用 POSTGRES_USER 建出來的 superuser，`--disable-triggers` 才能用）；最後 `bin/kamal app exec "bin/rails runner '%w[route_days route_day_stops trips layovers trip_stop_counts].each { |t| ActiveRecord::Base.connection.reset_pk_sequence!(t) }'"` 把序號對到現有的最大 id。完成時 `bin/kamal app exec "bin/rails runner 'p [RouteDay.count, RouteDayStop.count, Trip.count, Layover.count, TripStopCount.count]'"` 跟筆電上 `bin/rails runner 'p [RouteDay.count, RouteDayStop.count, Trip.count, Layover.count, TripStopCount.count]'` 印出同一個陣列（2026-10-23 量的是 [12, 1168, 1396, 1045, 64716]，之後若又 load 過，以當時的開發資料庫為準）；`bin/kamal app exec "bin/rails runner 'p RouteDay.connection.select_value(%q(select last_value from route_days_id_seq)) >= RouteDay.maximum(:id)'"` 印 true。pg_dump 與 pg_restore 是筆電的 17.5、伺服器是 16，data-only 還原預期可行但沒試過；pg_restore 拒絕或報版本時，改在 OrbStack 的開發 Postgres 容器裡用 16 的 pg_dump 產檔再 restore。驗證：上面的筆數與序號指令。[after: 3.1]

## 5. 正式站驗收

- [x] 5.1 正式站看得到資料：`curl -s https://bus.5xcamp.us/` 含 `data-latest-day` 三次、不含 `data-no-data`，且 `data-route="15373"`、`data-route="10712"`、`data-route="11764"` 各出現一次；`curl -s https://bus.5xcamp.us/routes/15373` 含 `data-section-nav`，10712 與 11764 同；使用者用瀏覽器打開首頁與三條路線的頁面各看一次，路線卡有最新資料日，折返停留分佈、載客剖面、行駛時間的區塊有數字；這段期間 `bin/kamal app logs` 沒有 500 或例外。驗證：上面的 curl 與使用者回報。[after: 4.1]

## 6. 紀錄

- [x] 6.1 docs/decisions.md 多一條「## 12. 網站部署在 DigitalOcean 新加坡的一台 Droplet」，標 2026-10-24：用 Kamal；Postgres 以 accessory 跟網站同一台；衍生表由筆電算好推上去，主機不裝 DuckDB、不放原始檔；採集器留在 Mac mini；IP 與網域在 config/deploy.yml，兩者從 DNS 就查得到、不是秘密，密碼一律在 credentials；第 11 條對採集器營運細節的限制照舊。完成時該節的內容對得上 design.md 的 Decisions，沒有寫到 design 沒決定的事（每晚自動跑在哪裡算）。驗證：內容審閱。[after: 3.2]
