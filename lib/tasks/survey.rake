namespace :survey do
  desc "全路網兩端性質的試跑：FROM=2026-10-19 TO=2026-10-22，可加 ROUTES=<路線 Id,…> 與 OUT=<目錄>；資料根目錄給 TURNAROUND_DATA"
  task end_natures: :environment do
    exit EndNatureSurveyCommand.new(ENV.to_h).run
  end
end
