# 自己 require 一次：support 檔按檔名排序載入，capybara_matchers.rb 排在 view_component.rb 前面
require "capybara/rspec"

RSpec.configure do |config|
  config.include Capybara::RSpecMatchers, type: :request
end
