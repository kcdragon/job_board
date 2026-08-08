# frozen_string_literal: true

module JobBoard
  module Queues
    class PausesController < ApplicationController
      def create
        SolidQueue::Queue.find_by_name(params[:queue_name]).pause
        redirect_to queues_path, notice: "Queue \"#{params[:queue_name]}\" paused."
      end

      def destroy
        SolidQueue::Queue.find_by_name(params[:queue_name]).resume
        redirect_to queues_path, notice: "Queue \"#{params[:queue_name]}\" resumed."
      end
    end
  end
end
