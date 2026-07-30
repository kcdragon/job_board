module JobBoard
  # Keyset pagination over a relation ordered by id DESC.
  # Fetches limit + 1 records to detect whether an older page exists.
  class Page
    include Enumerable

    attr_reader :records, :rows

    def initialize(relation, before: nil, limit: 25, &row_builder)
      relation = relation.where(id: ...before.to_i) if before.present?
      fetched = relation.limit(limit + 1).to_a
      @more = fetched.size > limit
      @records = fetched.first(limit)
      @rows = row_builder ? @records.map(&row_builder) : @records
    end

    def more?
      @more
    end

    # Keyset cursor for the next (older) page — the id of the raw record,
    # which is an execution id for execution-backed lists and a job id for finished.
    def next_before
      records.last&.id
    end

    def each(&block)
      rows.each(&block)
    end

    def empty?
      records.empty?
    end
  end
end
