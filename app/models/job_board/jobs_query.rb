# frozen_string_literal: true

module JobBoard
  # Status-scoped job finder. Each status is driven by its execution table so a
  # row's status is known without calling Job#status (which needs 5 preloads).
  class JobsQuery
    STATUSES = %w[ready scheduled in_progress blocked failed finished].freeze

    ROW_STATUS = {
      "ready" => :ready, "scheduled" => :scheduled, "in_progress" => :claimed,
      "blocked" => :blocked, "failed" => :failed, "finished" => :finished
    }.freeze

    attr_reader :status, :queue_name, :class_name

    def initialize(status:, queue_name: nil, class_name: nil)
      @status = status.to_s
      @queue_name = queue_name
      @class_name = class_name
    end

    def page(before: nil, limit: 25)
      row_status = ROW_STATUS.fetch(status)
      builder =
        if status == "finished"
          ->(job) { JobRow.from_job(job) }
        else
          ->(execution) { JobRow.from_execution(execution, status: row_status) }
        end
      Page.new(relation.order(id: :desc), before: before, limit: limit, &builder)
    end

    # One COUNT per status, with the current filters applied — for tab badges.
    def counts
      STATUSES.index_with do |s|
        self.class.new(status: s, queue_name: queue_name, class_name: class_name).count
      end
    end

    def count
      relation.count(:all)
    end

    # Job relation backing bulk retry/discard. Only meaningful for the failed set,
    # so it is always scoped to jobs with a failed execution.
    def failed_jobs_relation
      scope = SolidQueue::Job.joins(:failed_execution)
      scope = scope.where(queue_name: queue_name) if queue_name
      scope = scope.where(class_name: class_name) if class_name
      scope
    end

    private

    def relation
      case status
      when "ready"
        filtered(SolidQueue::ReadyExecution.includes(:job), own_queue_column: true)
      when "scheduled"
        filtered(SolidQueue::ScheduledExecution.includes(:job), own_queue_column: true)
      when "in_progress"
        filtered(SolidQueue::ClaimedExecution.includes(:process, :job), own_queue_column: false)
      when "blocked"
        filtered(SolidQueue::BlockedExecution.includes(:job), own_queue_column: true)
      when "failed"
        filtered(SolidQueue::FailedExecution.includes(:job), own_queue_column: false)
      when "finished"
        filtered_jobs(SolidQueue::Job.finished)
      else
        raise ArgumentError, "unknown status #{status.inspect}"
      end
    end

    def filtered(scope, own_queue_column:)
      if queue_name
        scope = if own_queue_column
                  scope.where(queue_name: queue_name)
                else
                  scope.joins(:job).where(solid_queue_jobs: { queue_name: queue_name })
                end
      end
      scope = scope.joins(:job).where(solid_queue_jobs: { class_name: class_name }) if class_name
      scope
    end

    def filtered_jobs(scope)
      scope = scope.where(queue_name: queue_name) if queue_name
      scope = scope.where(class_name: class_name) if class_name
      scope
    end
  end
end
