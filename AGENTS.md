<!-- SPECTRA:START v1.3.0 -->

# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `docs/spectra/specs/`, change proposals in `docs/spectra/changes/`.

## Use `$spectra-*` skills when:

- An explicitly requested Spectra decision needs structure → `$spectra-discuss`
- User explicitly requests a Spectra change proposal → `$spectra-propose`
- Continue tasks for an identified change → `$spectra-apply`
- Update requirements or plans for an identified change → `$spectra-ingest`
- Check implementation matches artifacts → `$spectra-verify`
- Review implementation quality and logic issues → `$spectra-review`
- Analyze artifact consistency before coding → `$spectra-analyze`
- Audit security sharp edges → `$spectra-audit`
- Check stale changes before resuming → `$spectra-drift`
- Debug a concrete bug systematically → `$spectra-debug`
- Implementation is done → `$spectra-archive`
- Commit only files related to a specific change → `$spectra-commit`

Explicit skill invocation takes precedence. Apply existing authorization within its unchanged scope.

## Workflow

discuss? → propose → apply ⇄ ingest → verify / review → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode (`/plan`) → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `docs/spectra/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `$spectra-apply` and `$spectra-ingest` skills disclose parking and restore when the named operation is already explicitly requested; respect a known refusal, otherwise ask for missing authorization.

<!-- SPECTRA:END -->

# website

## 技術棧

- Rails 8.1、PostgreSQL
- 前端：Vite + Tailwind CSS v4、Turbo + Alpine.js（沒有 Stimulus）
- View：ViewComponent；分頁：pagy
- 測試：RSpec + FactoryBot（沒有 minitest）

## 常用指令

- `bin/setup`：安裝 gem 與前端套件、安裝 git hooks（pre-commit）、準備開發與測試資料庫（含平行測試用的資料庫）
- `bin/dev`：啟動 Rails server 與 Vite dev server
- `bundle exec rspec <spec path[:line]>`：用單一 process 跑指定的 spec
- `bin/rails parallel:spec`：平行跑整套測試
- `bin/ci`：完整檢查（RuboCop、bundler-audit、Brakeman、平行 RSpec、seeds）
- `bin/rubocop`：style 檢查；`bin/brakeman`：安全掃描

## 慣例

- spec 要自己標 `type:`（例如 `type: :request`）：`spec/rails_helper.rb` 沒有開 `infer_spec_type_from_file_location!`，放在哪個目錄都不會自動推斷
- system spec 預設用 rack_test；標了 `:js`（等同 `js: true`）才開 headless Chrome
- ViewComponent 的 `.rb`、`.html.erb` 與選用的 `.yml` 放在同一層，用 `bin/rails g view_component:component` 產生就是這個結構；元件自己用的文案，用 `--locale` 產生同層的 `.yml`
- 交付前，對這次新增或修改的檔案跑 `bin/rubocop <檔案…>`
- `RSpec/ExampleLength` 上限 5 行（rubocop-rspec 的預設值）
- pre-commit 只檢查這次要 commit 的檔案；RuboCop 自動修正改到檔案時，該次 commit 會失敗，重新 `git add` 再 commit 即可
- model 的 schema 註解由 annotaterb 維護，跑完 migration 會自動更新
- test 環境的 Bullet 發現 N+1 查詢會讓 request spec 與 system spec 失敗；development 只寫進 `log/bullet.log`
- Gemfile 暫時限制 `json` 小於 3：Rails 8.1.3.1 與 json 3 不相容，原因與移除條件寫在 Gemfile 的註解
