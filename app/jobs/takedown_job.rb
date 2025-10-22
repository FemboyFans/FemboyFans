# frozen_string_literal: true

class TakedownJob < ApplicationJob
  queue_as(:high)
  sidekiq_options(lock: :until_executing, lock_args_method: :lock_args)

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id, approver, del_reason)
    @takedown = Takedown.find(id)
    @takedown.update_with!(approver, approver: approver, status: @takedown.calculated_status)
    ModAction.log!(approver, :takedown_process, @takedown)

    user = User.system
    @takedown.actual_posts.find_each do |p|
      if @takedown.should_delete(p.id)
        next if p.is_deleted?
        p.delete!(user, "takedown ##{@takedown.id}: #{del_reason}", force: true, takedown: true)
      else
        next unless p.is_deleted? && p.is_taken_down?
        p.undelete!(user, force: true)
        p.update_with!(user, is_taken_down: false)
      end
    end
  end
end
