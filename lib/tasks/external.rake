namespace :external do
  desc "下載北捷車站出入口座標，存成 UTF-8 的快照；資料根目錄給 TURNAROUND_DATA"
  task mrt_exits: :environment do
    exit MrtExitsSnapshot.run(ENV.to_h)
  end
end
