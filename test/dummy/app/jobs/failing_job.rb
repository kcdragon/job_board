# frozen_string_literal: true

class FailingJob < ActiveJob::Base
  queue_as :within_30_seconds

  def perform(*_args)
    raise "boom"
  end
end
