module JobBoard
  class Throughput
    READY_AT = "COALESCE(scheduled_at, created_at)".freeze

    class << self
      def snapshot(since:)
        now = Time.current
        {
          now: now.iso8601(3),
          enqueued: since ? count_between(READY_AT, since, now) : 0,
          completed: since ? count_between("finished_at", since, now) : 0
        }
      end

      private

      def count_between(expression, since, now)
        SolidQueue::Job.where("#{expression} > ? AND #{expression} <= ?", since, now).count
      end
    end
  end
end
