# frozen_string_literal: true

module Posts
  module Replacements
    class RejectionReasonsController < ApplicationController
      before_action(:load_reason, only: %i[edit update destroy])
      respond_to(:html, :json)

      def index
        @reasons = authorize(PostReplacementRejectionReason).html_includes(request, :creator)
                                                            .order(order: :asc)
        respond_with(@reasons)
      end

      def new
        @reason = authorize(PostReplacementRejectionReason).new
      end

      def edit
        authorize(PostReplacementRejectionReason)
      end

      def create
        @reason = authorize(PostReplacementRejectionReason.new(permitted_attributes(PostReplacementRejectionReason)))
        @reason.save
        flash[:notice] = @reason.valid? ? "Post replacement rejection reason created" : @reason.errors.full_messages.join("; ")
        respond_with(@reason) do |fmt|
          fmt.html { redirect_to(post_replacement_rejection_reasons_path) }
        end
      end

      def update
        authorize(@reason)
        @reason.update(permitted_attributes(@reason))
        flash[:notice] = @reason.valid? ? "Post replacement rejection reason updated" : @reason.errors.full_messages.join("; ")
        respond_with(@reason) do |fmt|
          fmt.html { redirect_to(post_replacement_rejection_reasons_path) }
        end
      end

      def destroy
        authorize(@reason)
        @reason.destroy
        flash[:notice] = "Post replacement rejection reason deleted"
        respond_with(@reason) do |format|
          format.html { redirect_to(post_replacement_rejection_reasons_path) }
        end
      end

      def reorder
        authorize(PostDeletionReason)
        new_orders = params[:_json].reject { |o| o[:id].nil? }
        new_ids = new_orders.pluck(:id)
        current_ids = PostReplacementRejectionReason.pluck(:id)
        missing = current_ids - new_ids
        extra = new_ids - current_ids
        duplicate = new_ids.select { |id| new_ids.count(id) > 1 }.uniq

        return render_expected_error(400, "Missing ids: #{missing.join(', ')}") if missing.any?
        return render_expected_error(400, "Extra ids provided: #{extra.join(', ')}") if extra.any?
        return render_expected_error(400, "Duplicate ids provided: #{duplicate.join(', ')}") if duplicate.any?

        changes = 0
        PostReplacementRejectionReason.find_each do |reason|
          order = new_orders.find { |o| o[:id] == reason.id }
          if reason.order != order[:order]
            reason.update_column(:order, order[:order])
            changes += 1
          end
        end

        PostReplacementRejectionReason.log_reorder(changes) if changes != 0

        respond_to do |format|
          format.html { redirect_back(fallback_location: post_replacement_rejection_reasons_path) }
          format.json
        end
      rescue ActiveRecord::RecordNotFound
        render_expected_error(400, "Replacement rejection reason not found")
      end

      private

      def load_reason
        @reason = PostReplacementRejectionReason.find(params[:id])
      end
    end
  end
end
