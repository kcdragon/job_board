module JobBoard
  class JobsController < ApplicationController
    before_action :set_query, only: [:index, :retry_all, :discard_all]

    def index
      @page = @query.page(before: params[:before], limit: JobBoard.config.per_page)
      @counts = @query.counts
      @queues = LatencySla.sort(SolidQueue::Queue.all)
    end

    def show
      @job = JobPresenter.new(find_job)
    end

    def retry
      job = find_job
      if job.failed_execution.present?
        job.retry
        redirect_back_or_to jobs_path(status: "failed"), notice: "Job ##{job.id} queued for retry."
      else
        redirect_back_or_to jobs_path, alert: "Job ##{job.id} is not failed, so it can't be retried."
      end
    end

    def discard
      job = find_job
      if job.status == :claimed
        redirect_back_or_to jobs_path, alert: "Job ##{job.id} is in progress and can't be discarded."
      elsif job.finished?
        redirect_back_or_to jobs_path, alert: "Job ##{job.id} is already finished."
      else
        job.discard
        redirect_to jobs_path(status: params[:status] || "failed"), notice: "Job ##{job.id} discarded."
      end
    end

    def retry_all
      count = 0
      failed_jobs_in_batches do |batch|
        SolidQueue::FailedExecution.retry_all(batch)
        count += batch.size
      end
      redirect_to failed_jobs_path, notice: "#{count} #{"job".pluralize(count)} queued for retry."
    end

    def discard_all
      count = 0
      failed_jobs_in_batches do |batch|
        SolidQueue::FailedExecution.discard_all_from_jobs(batch)
        count += batch.size
      end
      redirect_to failed_jobs_path, notice: "#{count} #{"job".pluralize(count)} discarded."
    end

    private
      def set_query
        status = params[:status].presence || "ready"
        head :not_found and return unless JobsQuery::STATUSES.include?(status)

        @query = JobsQuery.new(
          status: status,
          queue_name: params[:queue_name].presence,
          class_name: params[:class_name].presence
        )
      end

      def find_job
        SolidQueue::Job
          .includes(:ready_execution, :scheduled_execution, :claimed_execution,
                    :blocked_execution, :failed_execution)
          .find(params[:id])
      end

      def failed_jobs_in_batches(&block)
        query = JobsQuery.new(
          status: "failed",
          queue_name: params[:queue_name].presence,
          class_name: params[:class_name].presence
        )
        query.failed_jobs_relation.find_in_batches(batch_size: 500, &block)
      end

      def failed_jobs_path
        jobs_path(status: "failed", queue_name: params[:queue_name].presence,
                  class_name: params[:class_name].presence)
      end
  end
end
