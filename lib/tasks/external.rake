namespace :external do
  desc "下載北捷車站出入口座標，存成 UTF-8 的快照；資料根目錄給 TURNAROUND_DATA"
  task mrt_exits: :environment do
    exit MrtExitsSnapshot.run(ENV.to_h)
  end

  desc "下載人事行政總處的辦公日曆，一年一份存成快照：YEAR=2026（預設今年）；資料根目錄給 TURNAROUND_DATA"
  task office_calendar: :environment do
    exit OfficeCalendarSnapshot.run(ENV.to_h)
  end

  desc "下載環境部的全國公廁建檔資料，照 number 分頁抓完整份存成快照；資料根目錄給 TURNAROUND_DATA"
  task public_toilets: :environment do
    exit PublicToiletsSnapshot.run(ENV.to_h)
  end
end
