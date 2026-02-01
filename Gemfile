# frozen_string_literal: true

source "https://rubygems.org"

gem "bootsnap", require: false
gem "dartsass-rails"
gem "haml-rails"
gem "importmap-rails"
gem "jbuilder"
gem "kamal", require: false
gem "kaminari", "~> 1.2"
gem "omniauth"
gem "omniauth-rails_csrf_protection"
gem "paper_trail"
gem "pg", "~> 1.1"
gem "propshaft"
gem "puma", ">= 5.0"
gem "pundit"
gem "rails", "~> 8.1.2"
gem "ransack"
gem "simple_form", "~> 5.4"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "stimulus-rails"
gem "tailwindcss-rails", "~> 4.4"
gem "thruster", require: false
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "factory_bot_rails"
  gem "faker"
  gem "i18n-tasks"

  gem "guard", "~> 2.20"
  gem "guard-brakeman", "~> 1.0"
  gem "guard-rspec", "~> 4.7"
  gem "guard-rubocop", "~> 1.5"

  gem "rspec-rails", "~> 8.0"
  gem "rubocop", require: false
  gem "rubocop-capybara", require: false
  gem "rubocop-factory_bot", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara", "~> 3.40"
  gem "pundit-matchers", "~> 4.0"
  gem "rspec-its"
  gem "shoulda-matchers"
  gem "simplecov", require: false
end
