# Run using bin/ci
#
# 本機的完整檢查：commit 時的快速檢查交給 pre-commit，這裡跑全部的 lint、安全掃描與測試

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: RSpec", "bin/rails parallel:spec"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end
