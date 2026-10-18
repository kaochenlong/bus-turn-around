RSpec.configure do |config|
  config.before(:suite) do
    # 平行 worker 同時 build 會互相覆寫 public/vite/，那一次由 bin/rails parallel:spec 在啟動 worker 前做掉。
    # 第一個 worker 的 TEST_ENV_NUMBER 是空字串，所以問的是有沒有這個變數，不是它有沒有值
    next if ENV.key?("TEST_ENV_NUMBER")

    manifest = Rails.root.join("public/vite/.vite/manifest.json")
    running_system = RSpec.configuration.files_to_run.any? { |f| f.include?("/system/") }
    system("yarn build", exception: true) if running_system || !manifest.exist?
  end
end
