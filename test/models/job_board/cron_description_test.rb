# frozen_string_literal: true

require "test_helper"

module JobBoard
  class CronDescriptionTest < ActiveSupport::TestCase
    EXPECTATIONS = {
      "* * * * *" => "Every minute",
      "*/5 * * * *" => "Every 5 minutes",
      "0 * * * *" => "Every hour",
      "30 * * * *" => "Every hour at minute 30",
      "15,45 * * * *" => "Every hour at minutes 15 and 45",
      "0 */2 * * *" => "Every 2 hours",
      "30 */6 * * *" => "Every 6 hours at minute 30",
      "0 3 * * *" => "Every day at 03:00",
      "0 9,17 * * *" => "Every day at 09:00 and 17:00",
      "30 9 * * 1-5" => "At 09:30 on Monday through Friday",
      "0 12 * * mon" => "At 12:00 on Monday",
      "0 9 * * 1,3,5" => "At 09:00 on Monday, Wednesday, and Friday",
      "0 9 * * 0" => "At 09:00 on Sunday",
      "0 12 * * mon#2" => "At 12:00 on the 2nd Monday of the month",
      "0 12 * * mon#-1" => "At 12:00 on the last Monday of the month",
      "0 0 1 * *" => "At 00:00 on day 1 of the month",
      "0 0 1,15 * *" => "At 00:00 on days 1 and 15 of the month",
      "0 0 L * *" => "At 00:00 on the last day of the month",
      "0 0 1 1 *" => "At 00:00 on January 1",
      "0 0 1 1,7 *" => "At 00:00 on day 1 of the month in January and July",
      "0 6 * 6-8 *" => "At 06:00 in June through August",
      "*/10 * * * 1-5" => "Every 10 minutes on Monday through Friday",
      "*/30 * * * * *" => "Every 30 seconds",
      "0 3 * * * America/New_York" => "Every day at 03:00 (America/New_York)",
      "every day at 9am" => "Every day at 09:00"
    }.freeze

    EXPECTATIONS.each do |schedule, expected|
      test "describes #{schedule.inspect}" do
        assert_equal expected, CronDescription.describe(schedule)
      end
    end

    test "returns nil for unparseable schedules" do
      assert_nil CronDescription.describe("not a schedule")
      assert_nil CronDescription.describe(nil)
    end

    test "lists times when there are few, falls back to fields when there are many" do
      assert_equal "Every day at 08:00, 08:30, 12:00, and 12:30", CronDescription.describe("0,30 8,12 * * *")
      assert_equal "Every day at minutes 0, 15, 30, and 45 past hours 8, 10, 12, 14, and 16",
                   CronDescription.describe("0,15,30,45 8,10,12,14,16 * * *")
    end
  end
end
