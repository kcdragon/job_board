class FailingJob < ActiveJob::Base
  queue_as :within_30_seconds

  def perform(*args)
    raise "boom"
  end
end
