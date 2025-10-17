# frozen_string_literal: true

require("test_helper")

module Posts
  class ReplacementsControllerTest < ActionDispatch::IntegrationTest
    context("The post replacements controller") do
      setup do
        @user = create(:janitor_user, created_at: 2.weeks.ago)
        @admin = create(:admin_user)
        @upload = create(:jpg_upload, uploader: @user)
        @post = @upload.post
        @replacement = create(:png_replacement, creator: @user, post: @post)
      end

      context("create action") do
        should("work") do
          file = fixture_file_upload("alpha.png")
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              file:   file,
              reason: "test replacement",
            },
          }

          assert_difference("@post.reload.replacements.size", 1) do
            post_auth(post_replacements_path, @user, params: params)
            assert_response(:success)
            assert_equal(@response.parsed_body["location"], post_path(@post))
          end
        end

        should("work with direct url") do
          file = fixture_file_upload("alpha.png")
          create(:upload_whitelist, pattern: "http://example.com/*")
          CloudflareService.stubs(:ips).returns([])
          stub_request(:get, "http://example.com/alpha.png").to_return(status: 200, body: file.read, headers: { "Content-Type" => "image/png" })
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              direct_url: "http://example.com/alpha.png",
              reason:     "test replacement",
            },
          }

          assert_difference("@post.reload.replacements.size", 1) do
            post_auth(post_replacements_path, @user, params: params)
            assert_response(:success)
            assert_equal(@response.parsed_body["location"], post_path(@post))
          end
        end

        should("automatically approve replacements by approvers") do
          file = fixture_file_upload("alpha.png")
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              file:       file,
              reason:     "test replacement",
              as_pending: false,
            },
          }

          assert_difference("@post.reload.replacements.size", 2) do
            post_auth(post_replacements_path, @user, params: params)
            assert_response(:success)
            assert_equal(post_path(@post), @response.parsed_body["location"])
          end

          assert_equal(%w[approved original], @post.replacements.last(2).pluck(:status))
          assert_equal(false, @user.notifications.replacement_approve.exists?)
        end

        should("not automatically approve replacements by approvers if as_pending=true") do
          file = fixture_file_upload("alpha.png")
          params = {
            format:           :json,
            post_id:          @post.id,
            post_replacement: {
              file:       file,
              reason:     "test replacement",
              as_pending: true,
            },
          }

          assert_difference("@post.replacements.size") do
            post_auth(post_replacements_path, @user, params: params)
            assert_response(:success)
            @post.reload
          end

          assert_equal(@response.parsed_body["location"], post_path(@post))
          assert_equal("pending", @post.replacements.last.status)
        end

        context("with a previously destroyed post") do
          setup do
            @admin = create(:admin_user)
            @replacement.destroy_with(@admin)
            @upload2 = create(:apng_upload, uploader: @user)
            @post2 = @upload2.post
            @post2.expunge!(@admin)
          end

          should("fail and create ticket") do
            previous_md5 = @post.md5
            assert_difference({ "Ticket.count" => 1 }) do
              assert_enqueued_jobs(1, only: NotifyExpungedMediaAssetReuploadJob) do
                file = fixture_file_upload("test.png")
                post_auth(post_replacements_path, @user, params: { post_id: @post.id, post_replacement: { file: file, reason: "test replacement" }, format: :json })
                assert_response(:precondition_failed)
                assert_equal("That image has been deleted and cannot be reuploaded", @response.parsed_body["message"])
                assert_equal("expunged", PostReplacementMediaAsset.last.status)
                assert_equal(previous_md5, @post.reload.md5)
              end
              perform_enqueued_jobs(only: NotifyExpungedMediaAssetReuploadJob)
            end
          end

          # TODO: reimplement ability to disable notifications
          # should "fail and not create ticket if notify=false" do
          #   DestroyedPost.find_by!(post_id: @post2.id).update_column(:notify, false)
          #   assert_difference(%w[Post.count Ticket.count], 0) do
          #     file = fixture_file_upload("test.png")
          #     post_auth post_replacements_path, @user, params: { post_id: @post.id, post_replacement: { replacement_file: file, reason: "test replacement" }, format: :json }
          #   end
          # end
        end

        should("restrict access") do
          FemboyFans.config.stubs(:disable_age_checks?).returns(true)
          file = fixture_file_upload("alpha.png")
          assert_access(User::Levels::MEMBER, anonymous_response: :forbidden) do |user|
            PostReplacement.delete_all
            post_auth(post_replacements_path, user, params: { post_replacement: { file: file, reason: "test replacement" }, post_id: @post.id, format: :json })
          end
        end
      end

      context("reject action") do
        should("reject replacement") do
          janitor = create(:janitor_user)
          put_auth(reject_post_replacement_path(@replacement), janitor)
          assert_redirected_to(post_path(@post))

          @replacement.reload
          @post.reload
          assert_equal("rejected", @replacement.status)
          assert_equal(janitor.id, @replacement.rejector_id)
          assert_not_equal(@replacement.md5, @post.md5)
          assert_equal(true, @replacement.creator.notifications.replacement_reject.exists?)
        end

        should("reject replacement with a reason") do
          put_auth(reject_post_replacement_path(@replacement), @user, params: { post_replacement: { reason: "test" } })
          assert_redirected_to(post_path(@post))
          @replacement.reload
          @post.reload
          assert_equal("rejected", @replacement.status)
          assert_equal(@user.id, @replacement.rejector_id)
          assert_equal("test", @replacement.rejection_reason)
          assert_not_equal(@replacement.md5, @post.md5)
        end

        should("restrict access") do
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], success_response: :redirect) do |user|
            PostReplacement.delete_all
            replacement = create(:png_replacement, creator: @user, post: @post)
            put_auth(reject_post_replacement_path(replacement), user)
          end
        end
      end

      context("reject_with_reason action") do
        should("render") do
          get_auth(reject_with_reason_post_replacement_path(@replacement), @user)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]) { |user| get_auth(reject_with_reason_post_replacement_path(@replacement), user) }
        end
      end

      context("approve action") do
        should("replace post") do
          put_auth(approve_post_replacement_path(@replacement), create(:janitor_user))
          assert_redirected_to(post_path(@post))
          @replacement.reload
          @post.reload
          assert_equal(@replacement.md5, @post.md5)
          assert_equal(@replacement.status, "approved")
          assert_equal(true, @replacement.creator.notifications.replacement_approve.exists?)
        end

        should("restrict access") do
          @janitor = create(:janitor_user)
          [Upload, PostReplacement, PostReplacementMediaAsset, PostVersion, Post, UploadMediaAsset].each(&:delete_all)
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], anonymous_response: :forbidden) do |user|
            upload = create(:jpg_upload, uploader: @janitor)
            replacement = create(:png_replacement, post: upload.post, creator: @janitor)
            put_auth(approve_post_replacement_path(replacement), user, params: { format: :json })
          end
        end
      end

      context("promote action") do
        should("create post") do
          post_auth(promote_post_replacement_path(@replacement), create(:janitor_user))
          last_post = Post.last
          assert_redirected_to(post_path(last_post))
          @replacement.reload
          @post.reload
          assert_equal(last_post.md5, @replacement.md5)
          assert_equal("promoted", @replacement.status)
          assert_equal(true, @replacement.creator.notifications.replacement_promote.exists?)
        end

        should("restrict access") do
          @janitor = create(:janitor_user)
          [Upload, PostReplacement, PostReplacementMediaAsset, PostVersion, Post, UploadMediaAsset].each(&:delete_all)
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], success_response: :redirect) do |user|
            upload = create(:jpg_upload, uploader: @janitor, uploader_ip_addr: "127.0.0.1")
            replacement = create(:png_replacement, post: upload.post)
            post_auth(promote_post_replacement_path(replacement), user)
          end
        end
      end

      context("toggle action") do
        should("change penalize_uploader flag") do
          put_auth(approve_post_replacement_path(@replacement, penalize_current_uploader: true), @user)
          @replacement.reload
          assert(@replacement.penalize_uploader_on_approve)
          put_auth(toggle_penalize_post_replacement_path(@replacement), @user)
          assert_redirected_to(post_replacement_path(@replacement))
          @replacement.reload
          assert_not(@replacement.penalize_uploader_on_approve)
        end

        should("restrict access") do
          @replacement.approve!(create(:admin_user), penalize_current_uploader: true)
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], anonymous_response: :forbidden) { |user| put_auth(toggle_penalize_post_replacement_path(@replacement), user, params: { format: :json }) }
        end
      end

      context("index action") do
        should("render") do
          get(post_replacements_path)
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(post_replacements_path, user) }
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_post_replacement_path, @user, params: { post_id: @post.id })
          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER) { |user| get_auth(new_post_replacement_path, user, params: { post_id: @post.id }) }
        end
      end

      context("destroy action") do
        should("work") do
          delete_auth(post_replacement_path(@replacement), @admin)
          assert_redirected_to(post_path(@post))
          assert_equal(false, ::PostReplacement.exists?(@replacement.id))
          assert_equal("expunged", @replacement.media_asset.reload.status)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(post_replacement_path(@replacement), user) }
        end
      end
    end
  end
end
