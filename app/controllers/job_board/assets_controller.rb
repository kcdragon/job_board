# frozen_string_literal: true

module JobBoard
  class AssetsController < ApplicationController
    skip_forgery_protection

    ASSETS = {
      "application.css" => "text/css",
      "throughput_chart.css" => "text/css",
      "application.js" => "text/javascript",
      "throughput_chart.js" => "text/javascript"
    }.freeze

    def show
      name = params[:name]
      content_type = ASSETS[name] or return head(:not_found)

      expires_in 1.year, public: true
      send_file JobBoard::Engine.root.join("lib/job_board/assets", name),
                type: content_type, disposition: :inline
    end
  end
end
