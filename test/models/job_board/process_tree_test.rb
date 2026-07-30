require "test_helper"

module JobBoard
  class ProcessTreeTest < ActiveSupport::TestCase
    test "builds a supervisor tree with claimed counts" do
      supervisor = create_process(kind: "Supervisor(fork)")
      worker = create_process(kind: "Worker", supervisor: supervisor)
      create_process(kind: "Dispatcher", supervisor: supervisor)
      2.times { create_claimed_job(process: worker) }

      tree = ProcessTree.build(stale_threshold: 5.minutes)

      assert_equal [supervisor.id], tree.roots.map { |n| n.process.id }
      children = tree.roots.first.children
      assert_equal 2, children.size
      worker_node = children.find { |n| n.process.id == worker.id }
      assert_equal 2, worker_node.claimed_count
      assert_equal 2, tree.claimed_executions_for(worker).size
    end

    test "flags processes with old heartbeats as stale" do
      fresh = create_process(last_heartbeat_at: 30.seconds.ago)
      stale = create_process(last_heartbeat_at: 10.minutes.ago)

      tree = ProcessTree.build(stale_threshold: 5.minutes)
      nodes = tree.roots.index_by { |n| n.process.id }

      assert_not nodes[fresh.id].stale
      assert nodes[stale.id].stale
    end

    test "processes whose supervisor is gone become roots" do
      supervisor = create_process(kind: "Supervisor(fork)")
      worker = create_process(kind: "Worker", supervisor: supervisor)
      supervisor.delete

      tree = ProcessTree.build(stale_threshold: 5.minutes)

      assert_equal [worker.id], tree.roots.map { |n| n.process.id }
    end

    test "counts orphaned claimed executions" do
      create_orphaned_claimed_job
      create_claimed_job

      tree = ProcessTree.build(stale_threshold: 5.minutes)

      assert_equal 1, tree.orphaned_claimed_count
    end

    test "supervisors sort before orphan roots" do
      lone_worker = create_process(kind: "Worker")
      supervisor = create_process(kind: "Supervisor(async)")

      tree = ProcessTree.build(stale_threshold: 5.minutes)

      assert_equal [supervisor.id, lone_worker.id], tree.roots.map { |n| n.process.id }
    end
  end
end
