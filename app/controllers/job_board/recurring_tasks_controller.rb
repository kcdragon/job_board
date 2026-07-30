module JobBoard
  class RecurringTasksController < ApplicationController
    def index
      @tasks = SolidQueue::RecurringTask.order(:key)
    end
  end
end
