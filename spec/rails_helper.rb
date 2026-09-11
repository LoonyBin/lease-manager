# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails"

# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require "rspec/rails"
require "capybara/rspec"
require "pundit/matchers"
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join("spec/fixtures")
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers

  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-1/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Specs that attach files upload to the Active Storage :test service, a Disk
  # service rooted at tmp/storage (config/storage.yml). use_transactional_fixtures
  # rolls the ActiveRecord rows back but leaves the uploaded blobs — and their
  # processed variants — on disk, so tmp/storage grows without bound across runs.
  # tmp/ is gitignored, so this is disk hygiene on long-lived local and CI hosts,
  # not a correctness problem. See #189.
  #
  # This is an rm_rf, so it refuses any root it cannot prove is throwaway scratch:
  # a non-Disk service (which has no root at all), the real storage/ directory, or
  # anything outside Rails.root/tmp. A mis-set storage.yml must fail closed here —
  # skipping the cleanup costs disk, deleting the wrong tree costs uploads.
  #
  # Note: if Rails parallel testing is ever enabled, each worker needs its own
  # service root before this hook is safe — otherwise the first worker to finish
  # deletes blobs the others are still using.
  config.after(:suite) do
    service = ActiveStorage::Blob.service
    if Rails.env.test? && service.respond_to?(:root)
      root = Pathname.new(service.root.to_s).expand_path
      tmp = Rails.root.join("tmp").expand_path
      FileUtils.rm_rf(root) if root.to_s.start_with?("#{tmp}/")
    end
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
