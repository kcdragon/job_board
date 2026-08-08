# frozen_string_literal: true

module JobBoard
  # Detail-page wrapper around a SolidQueue::Job loaded with all five
  # has_one execution associations preloaded.
  class JobPresenter
    attr_reader :job

    delegate :id, :queue_name, :class_name, :priority, :active_job_id,
             :concurrency_key, :created_at, :finished_at, :finished?,
             :failed_execution, :status, to: :job

    def initialize(job)
      @job = job
    end

    # The serialized ActiveJob payload (Job#arguments is JSON-coded by SolidQueue).
    def payload
      @payload ||= job.arguments || {}
    rescue StandardError
      @payload = {}
    end

    def arguments = payload["arguments"]
    def executions_count = payload["executions"]
    def exception_executions = payload["exception_executions"]
    def enqueued_at = payload["enqueued_at"]

    def scheduled_at
      job.scheduled_execution&.scheduled_at || job.scheduled_at
    end

    def error = failed_execution

    def process
      job.claimed_execution&.process
    end
  end
end
