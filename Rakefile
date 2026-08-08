# frozen_string_literal: true

require "bundler/setup"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
end

RuboCop::RakeTask.new

task default: %i[test rubocop]
