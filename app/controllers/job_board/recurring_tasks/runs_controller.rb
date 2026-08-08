# frozen_string_literal: true

module JobBoard
  module RecurringTasks
    class RunsController < ApplicationController
      def create
        task = SolidQueue::RecurringTask.find_by(key: params[:key])

        if task.nil?
          redirect_to recurring_tasks_path, alert: "Recurring task \"#{params[:key]}\" no longer exists."
        elsif task.enqueue(at: Time.current)
          redirect_to recurring_tasks_path, notice: "Enqueued \"#{task.key}\"."
        else
          alert = "\"#{task.key}\" was not enqueued — it already ran at " \
                  "this exact time or the enqueue failed."
          redirect_to recurring_tasks_path, alert: alert
        end
      end
    end
  end
end
