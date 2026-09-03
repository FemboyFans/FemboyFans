# frozen_string_literal: true

require("test_helper")

module Posts
  class AudioTracksControllerTest < ActionDispatch::IntegrationTest
    context("The post audio tracks controller") do
      setup do
        @user = create(:janitor_user, created_at: 2.weeks.ago)
        @admin = create(:admin_user)
        # mp4_post's media asset duration (5.7s) matches the m4a_audio_track_media_asset factory's,
        # so tracks built from either factory naturally satisfy AudioTrack's within-1-second check.
        @post = create(:mp4_post, uploader: @user)
        @track = create(:audio_track, creator: @user, post: @post, status: "pending")
      end

      context("create action") do
        should("work") do
          file = fixture_file_upload("test-300x300-with-audio.mp4")
          params = {
            format:      :json,
            post_id:     @post.id,
            audio_track: {
              file:   file,
              label:  "English Dub",
              reason: "test audio track",
            },
          }

          assert_difference("@post.reload.audio_tracks.size", 1) do
            post_auth(post_audio_tracks_path, @user, params: params)

            assert_response(:success)
            assert_equal(@response.parsed_body["location"], post_path(@post))
          end

          assert_equal("pending", @post.audio_tracks.last.status)
          assert_equal("m4a", @post.audio_tracks.last.media_asset.file_ext)
        end

        should("fail without a label or reason") do
          file = fixture_file_upload("test-300x300-with-audio.mp4")
          params = {
            format:      :json,
            post_id:     @post.id,
            audio_track: {
              file: file,
            },
          }

          assert_no_difference("@post.reload.audio_tracks.size") do
            post_auth(post_audio_tracks_path, @user, params: params)

            assert_response(:precondition_failed)
          end
        end

        context("access control") do
          setup { GayFurCity.config.stubs(:disable_age_checks).returns(true) }

          asserts do
            access.gte(User::Levels::MEMBER).json.post(post_audio_tracks_path).params { { audio_track: { file: fixture_file_upload("test-300x300-with-audio.mp4"), label: "Dub", reason: "test audio track" }, post_id: @post.id } }
          end
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_post_audio_track_path, @user, params: { post_id: @post.id })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_post_audio_track_path).params { { post_id: @post.id } }
          end
        end
      end

      context("approve action") do
        should("approve the track") do
          put_auth(approve_post_audio_track_path(@track), create(:janitor_user), params: { format: :json })

          assert_response(:success)
          @track.reload

          assert_equal("approved", @track.status)
        end

        should("set the track as default when requested") do
          put_auth(approve_post_audio_track_path(@track, set_default: true), create(:janitor_user), params: { format: :json })

          assert_response(:success)
          @track.reload

          assert_equal("approved", @track.status)
          assert(@track.is_default)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { approve_post_audio_track_path(@track) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { approve_post_audio_track_path(@track) }
          end
        end
      end

      context("reject action") do
        should("reject the track with a reason") do
          put_auth(reject_post_audio_track_path(@track), @user, params: { audio_track: { reason: "not needed" }, format: :json })

          assert_response(:success)
          @track.reload

          assert_equal("rejected", @track.status)
          assert_equal(@user.id, @track.rejector_id)
          assert_equal("not needed", @track.rejection_reason)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { reject_post_audio_track_path(@track) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { reject_post_audio_track_path(@track) }
          end
        end
      end

      context("set_default action") do
        setup { @track.approve!(@admin) }

        should("set the track as default") do
          put_auth(set_default_post_audio_track_path(@track), create(:janitor_user), params: { format: :json })

          assert_response(:success)

          assert(@track.reload.is_default)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { set_default_post_audio_track_path(@track) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { set_default_post_audio_track_path(@track) }
          end
        end
      end

      context("index action") do
        should("render") do
          get(post_audio_tracks_path)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(post_audio_tracks_path)
            access.gte(User::Levels::ANONYMOUS).json.get(post_audio_tracks_path)
          end
        end

        context("search parameters") do
          subject { post_audio_tracks_path }
          setup do
            AudioTrack.delete_all
            @creator = create(:user, created_at: 2.weeks.ago)
            @approver = create(:user)
            @rejector = create(:user)
            # mp4_post hardcodes its checksum/md5, which the outer setup's @post already claimed -
            # build a video post with distinct ones instead of reusing that factory here.
            @post = create(:post, media_asset: build(:mp4_upload_media_asset, :active, checksum: SecureRandom.hex(16), md5: SecureRandom.hex(16)))
            @audio_track = create(:audio_track, post: @post, creator: @creator, creator_ip_addr: "127.0.0.2", approver: @approver, rejector: @rejector, status: "approved")
          end

          asserts do
            search(:label).value { @audio_track.label }.records { [@audio_track] }.user { @admin }
            search(:status, "approved").records { [@audio_track] }.user { @admin }
            search(:post_id).value { @post.id }.records { [@audio_track] }.user { @admin }
            search(:creator_id).value { @creator.id }.records { [@audio_track] }.user { @admin }
            search(:creator_name).value { @creator.name }.records { [@audio_track] }.user { @admin }
            search(:approver_id).value { @approver.id }.records { [@audio_track] }.user { @admin }
            search(:approver_name).value { @approver.name }.records { [@audio_track] }.user { @admin }
            search(:rejector_id).value { @rejector.id }.records { [@audio_track] }.user { @admin }
            search(:rejector_name).value { @rejector.name }.records { [@audio_track] }.user { @admin }
            search(:ip_addr, "127.0.0.2").records { [@audio_track] }.user { @admin }
          end
        end
      end

      context("destroy action") do
        should("work") do
          delete_auth(post_audio_track_path(@track), @admin, params: { format: :json })

          assert_response(:success)
          assert_not(::AudioTrack.exists?(@track.id))
          assert_equal("expunged", @track.media_asset.reload.status)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { post_audio_track_path(@track) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.delete { post_audio_track_path(@track) }.success(:no_content)
          end
        end
      end
    end
  end
end
