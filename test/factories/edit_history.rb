# frozen_string_literal: true

FactoryBot.define do
  factory(:edit_history) do
    association(:updater, factory: :user)
    versionable { create(:comment, creator: updater) }
    body { versionable&.send(versionable.class.versioning_body_column) }
    subject { versionable.send(versionable.class.versioning_subject_column) if versionable&.class&.versioning_subject_column }
    edit_type { "original" }
    sequence(:version) { |n| n }
  end
end
