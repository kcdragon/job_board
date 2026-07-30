require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"

require "solid_queue"
require "job_board"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.secret_key_base = "dummy"
    config.hosts.clear

    config.active_job.queue_adapter = :solid_queue
    # Single-database setup: SolidQueue models use the primary sqlite connection.
  end
end
