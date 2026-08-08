# frozen_string_literal: true

module JobBoard
  class RecurringTasksController < ApplicationController
    def index
      # next_time is derived from the cron schedule, not stored, so sort in Ruby.
      @tasks = SolidQueue::RecurringTask.all.sort_by { |task| [task.next_time, task.key] }
    end
  end
end
