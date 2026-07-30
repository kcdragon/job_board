require "test_helper"

module JobBoard
  class PageTest < ActiveSupport::TestCase
    test "empty relation produces an empty page" do
      page = Page.new(SolidQueue::Job.order(id: :desc))

      assert page.empty?
      assert_not page.more?
      assert_nil page.next_before
    end

    test "exactly limit records means no further page" do
      3.times { create_ready_job }

      page = Page.new(SolidQueue::Job.order(id: :desc), limit: 3)

      assert_equal 3, page.records.size
      assert_not page.more?
    end

    test "more records than limit sets more? and next_before cursor" do
      jobs = 5.times.map { create_ready_job }

      page = Page.new(SolidQueue::Job.order(id: :desc), limit: 2)

      assert_equal 2, page.records.size
      assert page.more?
      assert_equal jobs[-2].id, page.next_before
    end

    test "before cursor returns only older records" do
      jobs = 4.times.map { create_ready_job }

      page = Page.new(SolidQueue::Job.order(id: :desc), before: jobs[2].id, limit: 10)

      assert_equal [jobs[1].id, jobs[0].id], page.records.map(&:id)
    end

    test "row builder maps records" do
      create_ready_job(class_name: "SampleJob")

      page = Page.new(SolidQueue::Job.order(id: :desc)) { |job| job.class_name }

      assert_equal ["SampleJob"], page.to_a
    end
  end
end
