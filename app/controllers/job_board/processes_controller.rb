module JobBoard
  class ProcessesController < ApplicationController
    def index
      @tree = ProcessTree.build(stale_threshold: stale_threshold)
    end
  end
end
