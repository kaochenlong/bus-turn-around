RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium_chrome_headless

    # driven_by 沒有指定尺寸，前一個 example 留下的視窗大小會被沿用。
    # 視窗太小時點擊落在視窗外，症狀是按了沒反應，截圖卻看起來正常
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
