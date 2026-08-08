# frozen_string_literal: true

# Factory helpers that create Solid Queue records directly — no workers needed.
#
# SolidQueue::Job auto-creates a ready or scheduled execution after create, so
# helpers either backdate that execution or strip it before attaching another.
module SolidQueueFixtures
  def active_job_payload(class_name:, queue:, arguments: [], executions: 0)
    {
      "job_class" => class_name, "job_id" => SecureRandom.uuid, "queue_name" => queue,
      "arguments" => arguments, "executions" => executions, "exception_executions" => {},
      "enqueued_at" => Time.now.utc.iso8601
    }
  end

  def create_job!(queue: "default", class_name: "SampleJob", created_at: Time.current,
                  arguments: [], **attrs)
    SolidQueue::Job.create!(
      queue_name: queue, class_name: class_name, priority: attrs.delete(:priority) || 0,
      active_job_id: SecureRandom.uuid, created_at: created_at,
      arguments: active_job_payload(class_name: class_name, queue: queue, arguments: arguments),
      **attrs
    )
  end

  def strip_executions(job)
    job.ready_execution&.delete
    job.scheduled_execution&.delete
    job.reload
  end

  def create_ready_job(queue: "default", class_name: "SampleJob", created_at: Time.current, priority: 0)
    job = create_job!(queue: queue, class_name: class_name, created_at: created_at, priority: priority)
    job.ready_execution.update_columns(created_at: created_at)
    job
  end

  def create_scheduled_job(scheduled_at: 1.hour.from_now, queue: "default", class_name: "SampleJob")
    create_job!(queue: queue, class_name: class_name, scheduled_at: scheduled_at)
  end

  def create_claimed_job(process: nil, queue: "default", class_name: "SampleJob")
    process ||= create_process
    job = strip_executions(create_job!(queue: queue, class_name: class_name))
    SolidQueue::ClaimedExecution.create!(job: job, process: process)
    job
  end

  def create_failed_job(queue: "default", class_name: "SampleJob", error_class: "RuntimeError",
                        message: "boom", backtrace: ["app/jobs/sample_job.rb:5:in 'perform'"])
    job = strip_executions(create_job!(queue: queue, class_name: class_name))
    SolidQueue::FailedExecution.create!(
      job: job,
      error: { "exception_class" => error_class, "message" => message, "backtrace" => backtrace }
    )
    job
  end

  def create_blocked_job(concurrency_key: "key/#{SecureRandom.hex(3)}", queue: "default",
                         class_name: "SampleJob")
    job = strip_executions(create_job!(queue: queue, class_name: class_name,
                                       concurrency_key: concurrency_key))
    SolidQueue::BlockedExecution.create!(job: job, queue_name: queue, priority: 0,
                                         concurrency_key: concurrency_key,
                                         expires_at: 5.minutes.from_now)
    job
  end

  def create_finished_job(queue: "default", class_name: "SampleJob", finished_at: Time.current)
    strip_executions(create_job!(queue: queue, class_name: class_name, finished_at: finished_at))
  end

  def create_orphaned_claimed_job(queue: "default")
    job = strip_executions(create_job!(queue: queue))
    SolidQueue::ClaimedExecution.insert_all([{ job_id: job.id, process_id: nil,
                                               created_at: Time.current }])
    job
  end

  def create_process(kind: "Worker", supervisor: nil, last_heartbeat_at: Time.current,
                     metadata: {}, hostname: "test-host", pid: 1234)
    SolidQueue::Process.create!(
      kind: kind, name: "#{kind.parameterize}-#{SecureRandom.hex(4)}", supervisor: supervisor,
      last_heartbeat_at: last_heartbeat_at, metadata: metadata, hostname: hostname, pid: pid
    )
  end

  def create_recurring_task(key: "task-#{SecureRandom.hex(3)}", schedule: "0 * * * *",
                            class_name: "SampleJob", **attrs)
    SolidQueue::RecurringTask.create!(key: key, schedule: schedule, class_name: class_name,
                                      static: true, **attrs)
  end
end
