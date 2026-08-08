# frozen_string_literal: true

module JobBoard
  class Engine < ::Rails::Engine
    isolate_namespace JobBoard
  end
end
