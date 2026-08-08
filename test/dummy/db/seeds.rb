# frozen_string_literal: true

# Realistic Solid Queue data for exercising the Job Board UI.
# Records are created directly (no running workers needed).
#
# Note: SolidQueue::Job auto-creates a ready/scheduled execution after create,
# so we either backdate that execution or strip it before attaching another one.

require "securerandom"

[SolidQueue::Job, SolidQueue::ReadyExecution, SolidQueue::ScheduledExecution,
 SolidQueue::ClaimedExecution, SolidQueue::FailedExecution, SolidQueue::BlockedExecution,
 SolidQueue::RecurringExecution, SolidQueue::RecurringTask, SolidQueue::Process,
 SolidQueue::Pause, SolidQueue::Semaphore].each(&:delete_all)

def active_job_payload(class_name, queue, arguments: [], executions: 0)
  {
    "job_class" => class_name, "job_id" => SecureRandom.uuid, "provider_job_id" => nil,
    "queue_name" => queue, "priority" => nil, "arguments" => arguments,
    "executions" => executions, "exception_executions" => {},
    "locale" => "en", "timezone" => "UTC", "enqueued_at" => Time.now.utc.iso8601
  }
end

def create_job(queue:, class_name: "SampleJob", age: 0, arguments: [], executions: 0, **attrs)
  SolidQueue::Job.create!(
    queue_name: queue, class_name: class_name, priority: attrs.delete(:priority) || 0,
    active_job_id: SecureRandom.uuid, created_at: age.seconds.ago,
    arguments: active_job_payload(class_name, queue, arguments: arguments, executions: executions),
    **attrs
  )
end

def strip_executions(job)
  job.ready_execution&.delete
  job.scheduled_execution&.delete
  job.reload
end

# --- Ready jobs across latency-SLA queues (a la Gusto's within_* convention),
# backdated so latency is visible; within_30_seconds and within_1_hour breach their SLA ---
{
  "within_30_seconds" => 45,
  "within_5_minutes" => 130,
  "within_1_hour" => 3700,
  "within_24_hours" => 7200
}.each do |queue, max_age|
  6.times do |i|
    age = (max_age * (i + 1) / 6.0).round
    job = create_job(queue: queue, class_name: %w[SampleJob SampleJob FailingJob].sample,
                     age: age, arguments: [i, { "batch" => queue }])
    job.ready_execution.update_columns(created_at: age.seconds.ago)
  end
end

# --- Scheduled jobs (auto-created scheduled executions) ---
[10.minutes, 1.hour, 1.day].each_with_index do |wait, i|
  create_job(queue: "within_5_minutes", age: 60, scheduled_at: wait.from_now, arguments: [i])
end

# --- Processes: supervisor with two workers (one stale) and a dispatcher ---
supervisor = SolidQueue::Process.create!(
  kind: "Supervisor(fork)", name: "supervisor-#{SecureRandom.hex(5)}",
  pid: 4000, hostname: "worker-1.internal", last_heartbeat_at: Time.current, metadata: {}
)
worker = SolidQueue::Process.create!(
  kind: "Worker", name: "worker-#{SecureRandom.hex(5)}", supervisor: supervisor,
  pid: 4001, hostname: "worker-1.internal", last_heartbeat_at: Time.current,
  metadata: { "queues" => "within_30_seconds,within_5_minutes", "thread_pool_size" => 3 }
)
SolidQueue::Process.create!(
  kind: "Worker", name: "worker-#{SecureRandom.hex(5)}", supervisor: supervisor,
  pid: 4002, hostname: "worker-1.internal", last_heartbeat_at: 12.minutes.ago,
  metadata: { "queues" => "within_1_hour,within_24_hours", "thread_pool_size" => 1 }
)
SolidQueue::Process.create!(
  kind: "Dispatcher", name: "dispatcher-#{SecureRandom.hex(5)}", supervisor: supervisor,
  pid: 4003, hostname: "worker-1.internal", last_heartbeat_at: Time.current,
  metadata: { "batch_size" => 500, "concurrency_maintenance_interval" => 600 }
)

# --- In-progress jobs claimed by the live worker ---
2.times do |i|
  job = strip_executions(create_job(queue: "within_30_seconds", age: 30, arguments: [i]))
  SolidQueue::ClaimedExecution.create!(job: job, process: worker)
end

# --- An orphaned claimed job (process gone) ---
orphan = strip_executions(create_job(queue: "within_5_minutes", age: 500))
SolidQueue::ClaimedExecution.insert_all([{ job_id: orphan.id, process_id: nil, created_at: Time.current }])

# --- Failed jobs ---
5.times do |i|
  job = strip_executions(create_job(queue: %w[within_30_seconds within_5_minutes].sample, class_name: "FailingJob",
                                    age: 3600 + (i * 60), arguments: [i], executions: 1))
  SolidQueue::FailedExecution.create!(
    job: job,
    error: {
      "exception_class" => ["RuntimeError", "ActiveRecord::Deadlocked", "Net::ReadTimeout"].sample,
      "message" => "boom: something went wrong processing item #{i}",
      "backtrace" => [
        "app/jobs/failing_job.rb:5:in 'FailingJob#perform'",
        "activejob (8.1.3) lib/active_job/execution.rb:68:in 'block in ActiveJob::Execution#_perform_job'",
        "activesupport (8.1.3) lib/active_support/callbacks.rb:100:in 'ActiveSupport::Callbacks#run_callbacks'"
      ]
    }
  )
end

# --- Blocked job behind a concurrency semaphore ---
# Creating a job with a concurrency_key acquires its semaphore automatically.
blocked = strip_executions(create_job(queue: "within_5_minutes", age: 120, concurrency_key: "user/42"))
SolidQueue::BlockedExecution.create!(job: blocked, queue_name: "within_5_minutes", priority: 0,
                                     concurrency_key: "user/42", expires_at: 5.minutes.from_now)

# --- Finished jobs ---
10.times do |i|
  strip_executions(create_job(queue: %w[within_30_seconds within_5_minutes within_1_hour].sample,
                              age: 7200 + (i * 300),
                              arguments: [i], finished_at: ((i * 10) + 5).minutes.ago))
end

# --- Long-dead queues (only weeks-old finished jobs) — these land in the
# "Inactive queues" section, since development configures queue_activity_window ---
{ "legacy_exports" => 30, "onboarding_v1" => 90 }.each do |queue, days_old|
  2.times do |i|
    strip_executions(create_job(queue: queue, age: (days_old * 86_400) + (i * 3600),
                                arguments: [i], finished_at: ((days_old * 86_400) - 60).seconds.ago))
  end
end

# --- Paused queue ---
SolidQueue::Queue.find_by_name("within_24_hours").pause

# --- Recurring tasks, one with a past run ---
cleanup = SolidQueue::RecurringTask.create!(
  key: "cleanup_finished_jobs", schedule: "0 3 * * *", class_name: "SampleJob",
  queue_name: "within_24_hours", static: true, description: "Nightly cleanup"
)
SolidQueue::RecurringTask.create!(
  key: "hourly_report", schedule: "0 * * * *", class_name: "SampleJob",
  queue_name: "within_1_hour", static: false
)
last_run_job = strip_executions(create_job(queue: "within_24_hours", age: 3600 * 5, finished_at: 5.hours.ago))
SolidQueue::RecurringExecution.create!(job: last_run_job, task_key: cleanup.key, run_at: 5.hours.ago)

puts "Seeded: #{SolidQueue::Job.count} jobs, #{SolidQueue::Process.count} processes, " \
     "#{SolidQueue::RecurringTask.count} recurring tasks"
