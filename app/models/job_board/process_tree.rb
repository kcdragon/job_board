# frozen_string_literal: true

module JobBoard
  # Supervisor -> supervisee tree of SolidQueue processes with staleness flags,
  # claimed-job counts, and the in-progress jobs each worker holds.
  class ProcessTree
    Node = Data.define(:process, :children, :claimed_count, :stale)

    attr_reader :roots, :orphaned_claimed_count

    def self.build(stale_threshold:)
      new(stale_threshold: stale_threshold)
    end

    def initialize(stale_threshold:)
      processes = SolidQueue::Process.order(:id).to_a
      ids = processes.to_set(&:id)
      counts = SolidQueue::ClaimedExecution.group(:process_id).count
      @claimed_by_process =
        SolidQueue::ClaimedExecution.where(process_id: processes.map(&:id))
                                    .includes(:job).group_by(&:process_id)

      cutoff = stale_threshold.ago
      children = processes.group_by(&:supervisor_id)
      build_node = nil
      build_node = lambda do |process|
        Node.new(
          process: process,
          children: (children[process.id] || []).map(&build_node),
          claimed_count: counts[process.id] || 0,
          stale: process.last_heartbeat_at < cutoff
        )
      end

      # Roots: no supervisor, or a supervisor that no longer exists.
      root_processes = processes.select { |p| p.supervisor_id.nil? || !ids.include?(p.supervisor_id) }
      supervisors, others = root_processes.partition { |p| p.kind.to_s.start_with?("Supervisor") }
      @roots = (supervisors + others).map(&build_node)

      @orphaned_claimed_count = SolidQueue::ClaimedExecution.orphaned.count
    end

    def claimed_executions_for(process)
      @claimed_by_process[process.id] || []
    end

    def empty?
      roots.empty?
    end
  end
end
