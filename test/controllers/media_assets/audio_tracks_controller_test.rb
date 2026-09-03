# frozen_string_literal: true

require("test_helper")

module MediaAssets
  class AudioTracksControllerTest < ActionDispatch::IntegrationTest
    context("The audio track media assets controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
        @user2 = create(:user)
        @janitor = create(:janitor_user)
        @admin = create(:admin_user)
        @combined = file_fixture("test-300x300-with-audio.mp4")
        @media_asset = create(:audio_track_media_asset, creator: @user, checksum: MediaAsset.md5(@combined))
      end

      context("index action") do
        should("render") do
          get_auth(audio_track_media_assets_path, @user)

          assert_response(:success)
        end

        should("list created media assets") do
          get_auth(audio_track_media_assets_path, @user)

          assert_response(:success)
          assert_select("#audio-track-media-asset-#{@media_asset.id}", count: 1)
        end

        should("list all media assets for staff") do
          get_auth(audio_track_media_assets_path, @janitor)

          assert_response(:success)
          assert_select("#audio-track-media-asset-#{@media_asset.id}", count: 1)
        end

        should("not list media assets created by others") do
          get_auth(audio_track_media_assets_path, @user2)

          assert_response(:success)
          assert_select("#audio-track-media-asset-#{@media_asset.id}", count: 0)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(audio_track_media_assets_path)
            access.gte(User::Levels::MEMBER).json.get(audio_track_media_assets_path)
          end
        end

        context("search parameters") do
          subject { audio_track_media_assets_path }
          setup do
            AudioTrackMediaAsset.delete_all
            @janitor = create(:janitor_user)
            @creator = create(:user, created_at: 2.weeks.ago)
            @admin = create(:admin_user)
            @post = create(:mp4_post)
            @audio_track = create(:audio_track, post: @post, creator: @creator, creator_ip_addr: "127.0.0.2")
            @media_asset = @audio_track.media_asset
            @media_asset.update(status_message: "foo")
          end

          asserts do
            search(:checksum).value { @media_asset.checksum }.records { [@media_asset] }.user { @janitor }
            search(:md5).value { @media_asset.md5 }.records { [@media_asset] }.user { @janitor }
            search(:file_ext, "m4a").records { [@media_asset] }.user { @janitor }
            search(:status, "active").records { [@media_asset] }.user { @janitor }
            search(:status_message_matches, "foo").records { [@media_asset] }.user { @janitor }
            search(:audio_track_id).value { @audio_track.id }.records { [@media_asset] }.user { @janitor }
            search(:creator_id).value { @creator.id }.records { [@media_asset] }.user { @janitor }
            search(:creator_name).value { @creator.name }.records { [@media_asset] }.user { @janitor }
            search(:ip_addr, "127.0.0.2").records { [@media_asset] }.user { @admin }
          end
        end
      end

      context("append action") do
        should("work") do
          put_auth(append_audio_track_media_asset_path(@media_asset), @user, params: { audio_track_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:success)
          assert_equal(@media_asset.tempfile_checksum, MediaAsset.md5(@combined.to_s))
          assert_equal(File.size(@media_asset.tempfile_path), File.size(@combined.to_s))
        end

        should("not allow invalid chunk ids") do
          put_auth(append_audio_track_media_asset_path(@media_asset), @user, params: { audio_track_media_asset: { chunk_id: 2, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:unprocessable_entity)
          assert_equal(["unexpected: 2, expected: 1"], @response.parsed_body.dig("errors", "chunk_id"))
        end

        should("not allow files that are too large") do
          AdminConfig.any_instance.stubs(:max_file_size).returns(0)
          AdminConfig.any_instance.stubs(:max_file_sizes).returns({ "mp4" => 0 })
          put_auth(append_audio_track_media_asset_path(@media_asset), @user, params: { audio_track_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) }, format: :json })

          assert_response(:unprocessable_entity)
          assert_equal("failed", @media_asset.reload.status)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).json.put { |user| append_audio_track_media_asset_path(create(:audio_track_media_asset, creator: user)) }.params { { audio_track_media_asset: { chunk_id: 1, data: file_fixture_upload(@combined) } } }
          end
        end
      end

      context("finalize action") do
        should("work, transcoding the upload to AAC/m4a") do
          @media_asset.append_chunk!(1, @combined.open)

          assert_enqueued_jobs(1, only: MediaAssetDeleteTempfileJob) do
            put_auth(finalize_audio_track_media_asset_path(@media_asset), @user, params: { format: :json })

            assert_response(:success)
          end
          @media_asset.reload

          assert_equal("active", @media_asset.status)
          assert_equal("m4a", @media_asset.file_ext)
          assert_operator(@media_asset.duration.to_f, :>, 0)
        end

        should("mark the parent audio track pending") do
          @audio_track = @media_asset.create_audio_track!(post: create(:mp4_post), creator: @user, creator_ip_addr: "127.0.0.1", label: "Dub", reason: "testing")
          @media_asset.append_chunk!(1, @combined.open)

          assert_equal("uploading", @media_asset.reload_audio_track.status)

          put_auth(finalize_audio_track_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          @media_asset.reload
          @audio_track = @media_asset.audio_track

          assert_equal("pending", @audio_track.status)
          assert_equal({ "success" => true, "location" => post_path(@audio_track.post_id), "post_id" => @audio_track.post_id, "audio_track_id" => @audio_track.id }, @response.parsed_body)
        end

        should("not allow finalizing empty media assets") do
          put_auth(finalize_audio_track_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:unprocessable_entity)
          assert_equal(["Upload is empty"], @response.parsed_body.dig("errors", "base"))
        end

        context("access control") do
          asserts do
            access do |builder|
              builder.gte(User::Levels::MEMBER).json.put do |user|
                asset = create(:audio_track_media_asset, creator: user, checksum: MediaAsset.md5(@combined.to_s))
                asset.append_chunk!(1, @combined.open)
                finalize_audio_track_media_asset_path(asset)
              end
            end
          end
        end
      end

      context("cancel action") do
        should("work") do
          put_auth(cancel_audio_track_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          assert_equal("cancelled", @media_asset.reload.status)
        end

        should("remove file") do
          @media_asset.append_chunk!(1, @combined.open)

          assert_path_exists(@media_asset.tempfile_path)

          put_auth(cancel_audio_track_media_asset_path(@media_asset), @user, params: { format: :json })

          assert_response(:success)
          assert_equal("cancelled", @media_asset.reload.status)
          assert_not(File.exist?(@media_asset.tempfile_path))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).json.put { |user| cancel_audio_track_media_asset_path(create(:audio_track_media_asset, creator: user)) }
          end
        end
      end
    end
  end
end
