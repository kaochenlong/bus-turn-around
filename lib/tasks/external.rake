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

  desc "抓 TDX 估算的一條路線的站間旅行時間，原始回應存成快照，只做內部對照：ROUTE_NAME=307；憑證在 credentials 的 tdx 底下，資料根目錄給 TURNAROUND_DATA"
  task tdx_s2s_travel_time: :environment do
    exit TdxS2sTravelTimeSnapshot.run(ENV.to_h)
  end

  desc "下載公運處一期的評鑑總體報告書 PDF 存成快照，印 sha256 並跟 config/depot_inspections.yml 對照：TERM=115-1；資料根目錄給 TURNAROUND_DATA"
  task pto_assessment: :environment do
    exit PtoAssessmentSnapshot.run(ENV.to_h)
  end
end
