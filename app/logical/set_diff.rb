# frozen_string_literal: true

class SetDiff
  attr_reader(:additions, :removals, :added, :removed, :obsolete_added, :obsolete_removed, :changed, :unchanged)

  def initialize(new, old, latest)
    new = new.to_a
    old = old.to_a
    latest = latest.to_a

    @additions = new - old
    @removals = old - new
    @unchanged = new & old
    @obsolete_added = additions - latest
    @obsolete_removed = removals & latest
    @added, @removed, @changed = changes(additions, removals)
  end

  def changes(added, removed)
    changed = []

    removed.each do |removal|
      next unless (addition = find_similar(removal, added))
      changed << [removal, addition]
      added -= [addition]
      removed -= [removal]
    end

    [added, removed, changed]
  end

  def find_similar(string, candidates, max_dissimilarity: 0.70)
    distance = ->(other) { DidYouMean::Levenshtein.distance(string, other) }
    max_distance = string.size * max_dissimilarity

    candidates.select { |candidate| distance[candidate] <= max_distance }.min_by(&distance)
  end
end
