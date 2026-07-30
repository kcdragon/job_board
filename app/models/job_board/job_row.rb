module JobBoard
  # Uniform row facade so the jobs table doesn't care whether a row came from
  # an execution record or a finished job.
  class JobRow
    attr_reader :job, :status, :execution

    def self.from_execution(execution, status:)
      new(job: execution.job, status: status, execution: execution)
    end

    def self.from_job(job, status: :finished)
      new(job: job, status: status)
    end

    def initialize(job:, status:, execution: nil)
      @job = job
      @status = status.to_sym
      @execution = execution
    end

    def id = job.id
    def queue_name = job.queue_name
    def class_name = job.class_name
    def priority = job.priority
    def enqueued_at = job.created_at
    def finished_at = job.finished_at

    def scheduled_at
      status == :scheduled ? execution.scheduled_at : job.scheduled_at
    end

    def process
      execution.process if status == :claimed && execution
    end

    def concurrency_key
      execution.concurrency_key if status == :blocked && execution
    end

    def error_class
      execution.exception_class if status == :failed && execution
    end

    def error_message
      execution.message if status == :failed && execution
    end
  end
end
