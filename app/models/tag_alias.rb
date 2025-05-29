# frozen_string_literal: true

class TagAlias < TagRelationship
  attr_accessor(:skip_forum)

  after_save(:create_mod_action)
  validates(:antecedent_name, uniqueness: { conditions: -> { duplicate_relevant } }, unless: :is_deleted?)
  validate(:absence_of_transitive_relation, unless: :is_deleted?)

  module ApprovalMethods
    def approve!(approver: CurrentUser.user, update_topic: true)
      CurrentUser.scoped(approver) do
        update(status: "queued", approver_id: approver.id)
        TagAliasJob.perform_later(id, update_topic)
      end
    end

    def undo!(user: CurrentUser.user)
      TagAliasUndoJob.perform_later(id, user.id, true)
    end
  end

  module ForumMethods
    def forum_updater
      @forum_updater ||= ForumUpdater.new(
        forum_topic,
        forum_post:     (forum_post if forum_topic),
        expected_title: TagAliasRequest.topic_title(antecedent_name, consequent_name),
        skip_update:    !TagRelationship::SUPPORT_HARD_CODED,
      )
    end
  end

  module TransitiveChecks
    def list_transitives
      return @transitives if @transitives
      @transitives = []
      aliases = TagAlias.duplicate_relevant.where("consequent_name = ?", antecedent_name)
      aliases.each do |ta|
        @transitives << [:alias, ta, ta.antecedent_name, ta.consequent_name, consequent_name]
      end

      implications = TagImplication.duplicate_relevant.where("antecedent_name = ? or consequent_name = ?", antecedent_name, antecedent_name)
      implications.each do |ti|
        if ti.antecedent_name == antecedent_name
          @transitives << [:implication, ti, ti.antecedent_name, ti.consequent_name, consequent_name, ti.consequent_name]
        else
          @transitives << [:implication, ti, ti.antecedent_name, ti.consequent_name, ti.antecedent_name, consequent_name]
        end
      end

      @transitives
    end

    def has_transitives
      @has_transitives ||= !list_transitives.empty?
    end
  end

  include(ApprovalMethods)
  include(ForumMethods)
  include(TransitiveChecks)

  concerning(:EmbeddedText) do
    class_methods do
      def embedded_pattern
        /\[ta:(?<id>\d+)\]/m
      end
    end
  end

  def self.to_aliased_with_originals(names)
    names = Array(names).map(&:to_s)
    return {} if names.empty?
    aliases = active.where(antecedent_name: names).to_h { |ta| [ta.antecedent_name, ta.consequent_name] }
    names.to_h { |tag| [tag, tag] }.merge(aliases)
  end

  def self.to_aliased(names)
    TagAlias.to_aliased_with_originals(names).values
  end

  def self.to_aliased_query(query, overrides: nil, comments: false)
    # Remove tag types (newline syntax)
    query.gsub!(/(^| )(-)?(#{TagCategory.mapping.keys.sort_by { |x| -x.size }.join('|')}):([\S])/i, '\1\2\4')
    # Remove tag types (comma syntax)
    query.gsub!(/, (-)?(#{TagCategory.mapping.keys.sort_by { |x| -x.size }.join('|')}):([\S])/i, ', \1\3')
    lines = query.downcase.split("\n")
    processed = []
    lookup = []

    lines.each do |line|
      content = { tags: [] }
      if line.strip.empty?
        processed << content
        next
      end

      # Remove comments
      comment = line.match(/(?: |^)#(.*)/)
      unless comment.nil?
        content[:comment] = comment[1].strip
        line = line.delete_suffix("##{comment[1]}")
      end

      # Process tags
      line.split.compact_blank.map do |tag|
        data = {
          opt: tag.match(/^-?~/),
          neg: tag.match(/^~?-/),
          tag: tag.gsub(/^[-~]{1,}/, ""),
        }

        # ex. only - or ~ surrounded by spaces
        next if data[:tag].empty?

        content[:tags] << data
        lookup << data[:tag]
      end

      processed << content
    end

    # Look up the aliases
    aliases = to_aliased_with_originals(lookup.uniq)
    aliases.merge!(overrides) if overrides

    # Rebuild the blacklist text
    output = processed.map do |line|
      output_line = line[:tags].map do |data|
        (data[:opt] ? "~" : "") + (data[:neg] ? "-" : "") + (aliases[data[:tag]] || data[:tag])
      end
      output_line << "# #{line[:comment]}" if comments && !line[:comment].nil?

      output_line.uniq.join(" ")
    end

    # TODO: This causes every empty line except for the very first one will get stripped.
    # At the end of the day, it's not a huge deal.
    output.uniq.join("\n")
  end

  def process_undo!(user: User.system, update_topic: true)
    unless valid?
      errors.add(:base, "Nothing to undo") if undo_data.blank?
      raise(errors.full_messages.join("; "))
    end

    CurrentUser.scoped(user) do
      update!(status: "retired")
      mover = tag_mover_undo(user)
      mover.undo!
      update_column(:undo_data, undo_data - mover.applied.as_json)
      forum_updater.update(retirement_message, "RETIRED") if update_topic
    end
  end

  def process!(update_topic: true)
    tries = 0

    begin
      CurrentUser.scoped(approver) do
        update!(status: "processing")
        mover = tag_mover(approver)
        mover.move!
        update_column(:undo_data, mover.undos)
        forum_updater.update(approval_message(approver), "APPROVED") if update_topic
        update(status: "active", post_count: consequent_tag.post_count)
        # TODO: Race condition with indexing jobs here.
        antecedent_tag.fix_post_count if antecedent_tag&.persisted?
        consequent_tag.fix_post_count if consequent_tag&.persisted?
      end
    rescue Exception => e
      Rails.logger.error("[TA] #{e.message}\n#{e.backtrace}")
      if tries < 5 && !Rails.env.test?
        tries += 1
        sleep(2**tries)
        retry
      end

      CurrentUser.scoped(approver) do
        forum_updater.update(failure_message(e), "FAILED") if update_topic
        update_columns(status: "error: #{e}")
      end
    end
  end

  def tag_mover(user = CurrentUser.user)
    TagMover.new(antecedent_name, consequent_name, user: user, tcr: self)
  end

  def tag_mover_undo(user = CurrentUser.user)
    TagMover::Undo.new(undo_data, user: user, tcr: self)
  end

  def absence_of_transitive_relation
    # We don't want a -> b && b -> c chains if the b -> c alias was created first.
    # If the a -> b alias was created first, the new one will be allowed and the old one will be moved automatically instead.
    if TagAlias.active.exists?(antecedent_name: consequent_name)
      errors.add(:base, "A tag alias for #{consequent_name} already exists")
    end
  end

  def reject!(update_topic: true)
    update(status: "deleted")
    forum_updater.update(reject_message(CurrentUser.user), "REJECTED") if update_topic
  end

  def self.update_cached_post_counts_for_all
    TagAlias.without_timeout do
      connection.execute("UPDATE tag_aliases SET post_count = tags.post_count FROM tags WHERE tags.name = tag_aliases.consequent_name")
    end
  end

  def create_mod_action
    alias_desc = %("tag alias ##{id}":[#{Rails.application.routes.url_helpers.tag_alias_path(self)}]: [[#{antecedent_name}]] -> [[#{consequent_name}]])

    if previously_new_record?
      ModAction.log!(:tag_alias_create, self, alias_desc: alias_desc)
    else
      # format the changes hash more nicely.
      change_desc = saved_changes.except(:updated_at).map do |attribute, values|
        old = values[0]
        new = values[1]
        if old.nil?
          %(set #{attribute} to "#{new}")
        else
          %(changed #{attribute} from "#{old}" to "#{new}")
        end
      end.join(", ")

      ModAction.log!(:tag_alias_update, self, alias_desc: alias_desc, change_desc: change_desc)
    end
  end

  def self.fix_nonzero_post_counts!
    TagAlias.joins(:antecedent_tag).where("tag_aliases.status in ('active', 'processing') AND tags.post_count != 0").find_each { |ta| ta.antecedent_tag.fix_post_count }
  end
end
