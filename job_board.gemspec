# frozen_string_literal: true

require_relative "lib/job_board/version"

Gem::Specification.new do |spec|
  spec.name        = "job_board"
  spec.version     = JobBoard::VERSION
  spec.authors     = ["Mike"]
  spec.email       = ["mike@rowhomelabs.com"]
  spec.summary     = "A dashboard for monitoring Solid Queue queues and jobs."
  spec.description = "Mountable Rails engine that shows queue latency, jobs by status, " \
                     "failed job management, workers, and recurring tasks for Solid Queue."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/kcdragon/job_board"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{app,config,lib}/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]

  # Data.define in ProcessTree requires 3.2.
  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "rails", ">= 7.1"
  # SolidQueue::Queue#latency was added in 1.1.0.
  spec.add_dependency "solid_queue", ">= 1.1"
end
