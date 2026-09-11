# frozen_string_literal: true

module JobBoard
  class QueuesController < ApplicationController
    def index
      @queue_list = QueueList.build
      @failed_counts = SolidQueue::FailedExecution.joins(:job)
                                                  .group("solid_queue_jobs.queue_name").count
      @running_counts = SolidQueue::ClaimedExecution.joins(:job)
                                                    .group("solid_queue_jobs.queue_name").count
    end
  end
end
