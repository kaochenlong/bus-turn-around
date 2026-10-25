# Run using bin/ci
#
# 本機的完整檢查：commit 時的快速檢查交給 pre-commit，這裡跑全部的 lint、安全掃描與測試

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # 班表頁的鋪排、四小時休息與微調演算法在瀏覽器端，用 Vitest 測；頁面上的流程仍在 RSpec 的 system spec
  step "Tests: JavaScript", "yarn test:js"
  step "Tests: RSpec", "bin/rails parallel:spec"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end
