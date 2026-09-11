# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "debug"
# Pin json to 2.x: json 3.0 dropped the positional options arg that
# activesupport 8.1's ActiveSupport::JSON.decode still passes, which otherwise
# breaks every SolidQueue::Job (de)serialization in the test suite and seeds.
gem "json", "~> 2.21"
gem "puma"
gem "rubocop", require: false
gem "sqlite3"
