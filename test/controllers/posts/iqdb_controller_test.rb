# frozen_string_literal: true

require("test_helper")

module Posts
  class IqdbControllerTest < ActionDispatch::IntegrationTest
    context("The iqdb controller") do
      setup do
        IqdbProxy.stubs(:endpoint).returns("http://iqdb:5588")
        @user = create(:user)
        @posts = create_list(:post, 2, uploader: @user)
      end

      context("show action") do
        context("with a url parameter") do
          setup do
            create(:upload_whitelist, pattern: "*google.com")
            @url = "https://google.com"
            @params = { url: @url }
            @mocked_response = [{
              "post"    => @posts[0],
              "post_id" => @posts[0].id,
              "score"   => 1,
            }]
          end

          should("render a response") do
            IqdbProxy.expects(:query_url).with(@user, @url, nil).returns(@mocked_response)
            get_auth(posts_iqdb_path, @user, params: @params)
            assert_select("#post_#{@posts[0].id}")
          end
        end

        context("with a post_id parameter") do
          setup do
            @params = { post_id: @posts[0].id }
            @url = @posts[0].preview_file_url(@user)
            @mocked_response = [{
              "post"    => @posts[0],
              "post_id" => @posts[0].id,
              "score"   => 1,
            }]
          end

          should("redirect to iqdb") do
            IqdbProxy.expects(:query_post).with(@posts[0], nil).returns(@mocked_response)
            get_auth(posts_iqdb_path, @user, params: @params)
            assert_select("#post_#{@posts[0].id}")
          end
        end

        context("with matches") do
          setup do
            json = @posts.map { |x| { "post_id" => x.id, "score" => 1 } }.to_json
            @params = { matches: json }
          end

          should("render with matches") do
            get_auth(posts_iqdb_path, @user, params: @params)
            assert_response(:success)
          end
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(posts_iqdb_path, user) }
        end
      end
    end
  end
end
