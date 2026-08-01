module JobBoard
  # Partitions queues into active and inactive based on when each queue last
  # had a job enqueued. A queue is inactive when its newest job is older than
  # the activity window; paused queues always count as active, since a pause
  # is deliberate state someone needs to see. Without a window, every queue
  # is active.
  class QueueList
    attr_reader :active, :inactive, :last_enqueued_at, :window

    def self.build(window: JobBoard.config.queue_activity_window)
      new(LatencySla.sort(SolidQueue::Queue.all),
        last_enqueued_at: SolidQueue::Job.group(:queue_name).maximum(:created_at),
        window: window)
    end

    def initialize(queues, last_enqueued_at:, window: nil)
      @last_enqueued_at = last_enqueued_at
      @window = window
      @active, @inactive = partition(queues)
    end

    private

    def partition(queues)
      return [queues, []] unless window

      cutoff = Time.current - window
      paused = SolidQueue::Pause.where(queue_name: queues.map(&:name)).pluck(:queue_name).to_set
      queues.partition do |queue|
        newest = last_enqueued_at[queue.name]
        paused.include?(queue.name) || (newest && newest >= cutoff)
      end
    end
  end
end
