source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
gem "turbo-rails"
gem "view_component"
gem "pagy", "~> 43.5"
gem "rails-i18n"
# Rails 8.1.3.1 的 ActiveSupport::JSON.decode 以位置參數把選項傳給 JSON.parse，json 3.0 起只收 keyword，
# 解密 session cookie 時丟出 ArgumentError，帶 cookie 的請求一律回 500。
# Rails 發布支援 json 3 的版本後拿掉這行；拿掉前先確認帶 session cookie 的請求回 200
gem "json", "< 3"
# csv 從 Ruby 3.4 起是 bundled gem，bundler 底下沒列在這裡就載不到；公廁快照用它檢查與寫出 CSV
gem "csv"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "rubocop-rspec", require: false
  gem "bullet"
end

group :development do
  gem "annotaterb"
  gem "letter_opener"
end

group :test do
  gem "parallel_tests", "~> 4.10"
end
