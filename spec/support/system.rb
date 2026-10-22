# 沒有 WebGL 的瀏覽器：--disable-3d-apis 關掉 WebGL 與 WebGPU，首頁插圖要退回靜態圖
Capybara.register_driver :selenium_chrome_headless_without_webgl do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[--headless=new --disable-3d-apis --window-size=1400,1400].each { options.add_argument(it) }
  Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
end

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

  config.before(:each, :without_webgl, type: :system) do
    driven_by :selenium_chrome_headless_without_webgl
  end
end
