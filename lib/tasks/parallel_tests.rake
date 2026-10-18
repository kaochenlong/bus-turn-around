# parallel_tests 在 test group，rake 卻跑在 development：Bundler.require 不會 require 它，
# gem 的 task 也就不會自動載入，所以這裡自己 require。
# bundle 排除 test group 的環境（例如部署時的 BUNDLE_WITHOUT）直接略過整個檔案，
# 否則 docker-entrypoint 的 bin/rails db:prepare 會跟著載入失敗
begin
  require "parallel"
  require "parallel_tests/tasks"
rescue LoadError
  return
end

# 每個 worker 各開一份 Rails，跑 system spec 時還各開一個 headless Chrome，所以上限 8。要調就改這裡
worker_count = [ Parallel.processor_count, 8 ].min.to_s

# rake 的同名 task 會疊加 action 而不是覆寫：不先清掉，gem 的版本跑完這裡的會再跑一次
Rake::Task["parallel:setup"].clear
Rake::Task["parallel:spec"].clear

namespace :parallel do
  desc "建立每個 worker 的測試資料庫並載入 schema"
  task :setup do
    Rake::Task["parallel:create"].invoke(worker_count)
    # 用 load_schema 不用 gem 的 prepare：prepare 會先從 development 資料庫 dump 回 db/schema.rb。
    # 還沒有任何 migration 的專案沒有 db/schema.rb，空資料庫就是正確狀態，不載入
    if Rails.root.join("db/schema.rb").exist?
      Rake::Task["parallel:load_schema"].invoke(worker_count)
    end
  end

  desc "drop 每個 worker 的測試資料庫後重新建立"
  task :reset do
    Rake::Task["parallel:drop"].invoke(worker_count)
    Rake::Task["parallel:setup"].invoke
  end

  desc "平行執行整套測試"
  task :spec do
    # worker 各自 build 會互相覆寫 public/vite/，在啟動 worker 之前做一次（worker 那一側見 spec/support/vite.rb）
    sh "yarn build"
    sh "bundle exec parallel_rspec spec -n #{worker_count}"
  end
end
