.PHONY: test

# 平行跑整套 RSpec。worker 數、先 build 前端的理由寫在 lib/tasks/parallel_tests.rake；
# 各 worker 的測試資料庫由 bin/setup 準備，不見了就先跑 bin/rails parallel:setup
test:
	bin/rails parallel:spec
