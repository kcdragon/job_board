module JobBoard
  class QueuesController < ApplicationController
    def index
      @queues = LatencySla.sort(SolidQueue::Queue.all)
      @failed_counts = SolidQueue::FailedExecution.joins(:job)
        .group("solid_queue_jobs.queue_name").count
    end
  end
end
