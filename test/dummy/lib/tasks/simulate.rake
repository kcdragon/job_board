# Each tick enqueues a batch of jobs and drains the oldest ready ones to finished (or failed), simulating a worker so the dashboard has live traffic to show.
#
#   cd test/dummy && bin/rails db:prepare db:seed   # optional starting data
#   bin/rails "job_board:simulate"                    # run with defaults
#   DURATION=300 INTERVAL=0.5 bin/rails "job_board:simulate"
#
# Knobs (all optional ENV vars):
#   DURATION  seconds to run          (default 120; 0 runs until Ctrl-C)
#   INTERVAL  seconds between ticks    (default 1.0)
#   ENQUEUE   max jobs enqueued/tick   (default 12)
#   RUN       max jobs finished/tick   (default 14)
namespace :job_board do
  desc "Simulate enqueueing and running many Solid Queue jobs (see file header for ENV knobs)"
  task simulate: :environment do
    duration = Integer(ENV.fetch("DURATION", "120"))
    interval = Float(ENV.fetch("INTERVAL", "1.0"))
    enqueue_max = Integer(ENV.fetch("ENQUEUE", "12"))
    run_max = Integer(ENV.fetch("RUN", "14"))
    queues = %w[within_30_seconds within_5_minutes within_1_hour within_24_hours reports mailers]

    enqueued = finished = failed = 0
    stop = false
    trap("INT") { stop = true }

    puts "Simulating job traffic (#{duration.zero? ? 'until Ctrl-C' : "#{duration}s"}, " \
         "every #{interval}s). View at /job_board. Ctrl-C to stop."
    deadline = duration.zero? ? nil : Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration

    until stop || (deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline)
      rand(1..enqueue_max).times do
        klass = rand < 0.15 ? FailingJob : SampleJob
        klass.set(queue: queues.sample).perform_later(rand(1..1000))
        enqueued += 1
      end

      SolidQueue::ReadyExecution.order(:created_at).limit(rand(1..run_max)).includes(:job).map(&:job).compact.each do |job|
        job.ready_execution&.destroy
        if job.class_name == "FailingJob"
          SolidQueue::FailedExecution.create!(job: job, error: {
            "exception_class" => "RuntimeError", "message" => "boom: simulated failure",
            "backtrace" => ["app/jobs/failing_job.rb:5:in 'FailingJob#perform'"]
          })
          failed += 1
        else
          job.update!(finished_at: Time.current)
          finished += 1
        end
      end

      backlog = SolidQueue::ReadyExecution.count
      print "\r  enqueued #{enqueued}  finished #{finished}  failed #{failed}  ready #{backlog}   "
      $stdout.flush
      sleep interval
    end

    puts "\nDone. enqueued #{enqueued}, finished #{finished}, failed #{failed}, " \
         "ready backlog #{SolidQueue::ReadyExecution.count}."
  end
end
