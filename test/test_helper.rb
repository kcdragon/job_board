ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"

ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

require_relative "support/solid_queue_fixtures"

class ActiveSupport::TestCase
  include SolidQueueFixtures
end
