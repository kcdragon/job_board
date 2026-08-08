# frozen_string_literal: true

require "fugit"

module JobBoard
  # Turns a cron expression into an English frequency description,
  # e.g. "30 9 * * 1-5" => "At 09:30 on Monday through Friday".
  # Returns nil for anything it can't describe faithfully.
  class CronDescription
    DAYS = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze
    MONTHS = %w[January February March April May June
                July August September October November December].freeze

    def self.describe(schedule)
      cron = Fugit.parse(schedule.to_s)
      new(cron).to_s if cron.instance_of?(Fugit::Cron)
    rescue StandardError
      nil
    end

    def initialize(cron)
      @cron = cron
    end

    def to_s
      time = time_clause
      return nil if time.nil?

      days = day_clause
      description =
        if days
          "#{time} #{days}"
        elsif time.start_with?("At ")
          "Every day #{time.sub(/\AAt /, "at ")}"
        else
          time
        end
      cron.zone ? "#{description} (#{cron.zone})" : description
    end

    private

    attr_reader :cron

    def time_clause
      if (step = seconds_step)
        # Sub-minute schedules only describe cleanly when nothing else is constrained.
        return nil unless cron.minutes.nil? && cron.hours.nil?

        "Every #{step} seconds"
      elsif cron.seconds && cron.seconds != [0]
        nil
      elsif cron.minutes.nil? && cron.hours.nil?
        "Every minute"
      elsif (step = minutes_step) && cron.hours.nil?
        "Every #{step} minutes"
      elsif cron.minutes == [0] && cron.hours.nil?
        "Every hour"
      elsif cron.hours.nil?
        "Every hour at #{numbers("minute", cron.minutes)}"
      elsif (step = hours_step)
        cron.minutes == [0] ? "Every #{step} hours" : "Every #{step} hours at #{numbers("minute", cron.minutes)}"
      else
        times = cron.hours.product(cron.minutes || [0]).sort
        if times.size <= 4
          "At #{join_and(times.map { |h, m| format("%<h>02d:%<m>02d", h: h, m: m) })}"
        else
          "At #{numbers("minute", cron.minutes)} past #{numbers("hour", cron.hours)}"
        end
      end
    end

    # nil when there is no day-of-week/month restriction (i.e. runs every day).
    def day_clause
      day_parts = [weekday_clause, monthday_clause].compact
      # Cron treats day-of-month and day-of-week as OR when both are restricted.
      clause = day_parts.join(" or ").presence
      [clause, month_clause].compact.join(" ").presence
    end

    def weekday_clause
      return nil if cron.weekdays.nil?

      plain = cron.weekdays.select { |_, nth| nth.nil? }.map { |day,| day % 7 }.sort.uniq
      nth = cron.weekdays.filter_map do |day, n|
        next if n.nil?

        "the #{n == -1 ? "last" : n.ordinalize} #{DAYS[day % 7]} of the month"
      end

      phrases = []
      if plain.any?
        phrases << if plain.size > 2 && consecutive?(plain)
                     "#{DAYS[plain.first]} through #{DAYS[plain.last]}"
                   else
                     join_and(plain.map { |day| DAYS[day] })
                   end
      end
      "on #{join_and(phrases + nth)}"
    end

    def monthday_clause
      return nil if cron.monthdays.nil?

      # "0 0 1 1 *" reads better as "on January 1" than "on day 1 of the month in January".
      if cron.monthdays.size == 1 && cron.monthdays.first.positive? &&
         cron.months&.size == 1 && cron.weekdays.nil?
        @month_consumed = true
        return "on #{MONTHS[cron.months.first - 1]} #{cron.monthdays.first}"
      end

      positive, negative = cron.monthdays.partition(&:positive?)
      phrases = []
      phrases << numbers("day", positive) if positive.any?
      phrases += negative.sort.reverse.map do |day|
        day == -1 ? "the last day" : "the #{(-day).ordinalize}-to-last day"
      end
      "on #{join_and(phrases)} of the month"
    end

    def month_clause
      return nil if cron.months.nil? || @month_consumed

      names = cron.months.sort.map { |m| MONTHS[m - 1] }
      if names.size > 2 && consecutive?(cron.months.sort)
        "in #{names.first} through #{names.last}"
      else
        "in #{join_and(names)}"
      end
    end

    def seconds_step = step_of(cron.seconds, 60)
    def minutes_step = step_of(cron.minutes, 60)
    def hours_step   = step_of(cron.hours, 24)

    # [0, 15, 30, 45] within 60 => 15; anything not starting at 0 or unevenly spaced => nil.
    def step_of(values, span)
      return nil if values.nil? || values.size < 2 || values.first != 0

      gap = values[1] - values[0]
      values == (0...span).step(gap).to_a ? gap : nil
    end

    def consecutive?(values)
      values.each_cons(2).all? { |a, b| b == a + 1 }
    end

    def numbers(noun, values)
      "#{noun.pluralize(values.size)} #{join_and(values.sort)}"
    end

    def join_and(items)
      items = items.map(&:to_s)
      return items.join(" and ") if items.size <= 2

      "#{items[0..-2].join(", ")}, and #{items.last}"
    end
  end
end
