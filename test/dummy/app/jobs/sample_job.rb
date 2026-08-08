# frozen_string_literal: true

class SampleJob < ActiveJob::Base
  queue_as :within_5_minutes

  def perform(*args); end
end
