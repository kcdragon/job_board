module JobBoard
  class MetricsController < ApplicationController
    def show
      render json: Throughput.snapshot(since: parse_time(params[:since]))
    end

    private

    def parse_time(value)
      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil # blank or malformed cursor → treat as a fresh baseline
    end
  end
end
