# frozen_string_literal: true

FactoryBot.define do
  factory(:edit_history) do
    association(:updater, factory: :user)
    versionable { create(:comment, creator: updater) }
    body { versionable&.send(versionable.class.versioning_body_column) }
    subject { versionable.send(versionable.class.versioning_subject_column) if versionable&.class&.versioning_subject_column }
    edit_type { "original" }
    version { EditHistory.where(versionable_id: versionable&.id, versionable_type: versionable&.class&.name).count + 1 }
  end
end
