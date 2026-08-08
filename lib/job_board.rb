# frozen_string_literal: true

require "solid_queue"

require "job_board/version"
require "job_board/configuration"
require "job_board/engine"

module JobBoard
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end
  end
end
