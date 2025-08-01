# frozen_string_literal: true

class PostApproval < ApplicationRecord
  belongs_to_user(:user, ip: true) # TODO: convert to creator
  belongs_to(:post, inverse_of: :approvals)

  validate(:validate_approval)

  def validate_approval
    post.lock!

    if post.is_status_locked?
      errors.add(:post, "is locked and cannot be approved")
    end

    if post.status == "active"
      errors.add(:post, "is already active and cannot be approved")
    end
  end

  concerning(:SearchMethods) do
    class_methods do
      def post_tags_match(query, user)
        where(post_id: Post.tag_match_sql(query, user))
      end

      def search(params, user)
        q = super

        if params[:post_tags_match].present?
          q = q.post_tags_match(params[:post_tags_match], user)
        end

        q = q.where_user(:user_id, :user, params)
        q = q.attribute_matches(:post_id, params[:post_id])

        q.apply_basic_order(params)
      end
    end
  end

  def self.available_includes
    %i[post user]
  end
end
