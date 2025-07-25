# frozen_string_literal: true

require("test_helper")

class RelatedTagCalculatorTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    reset_post_index
  end

  context("A related tag calculator") do
    context("for a post set") do
      setup do
        create(:post, tag_string: "aaa bbb ccc ddd")
        create(:post, tag_string: "aaa bbb ccc")
        create(:post, tag_string: "aaa bbb")
        @posts = Post.tag_match("aaa", @user).records
      end

      should("calculate the related tags") do
        assert_equal({ "aaa" => 3, "bbb" => 3, "ccc" => 2, "ddd" => 1 }, RelatedTagCalculator.calculate_from_posts(@posts))
      end
    end

    should("calculate related tags for a tag") do
      posts = []
      posts << create(:post, tag_string: "aaa bbb ccc ddd")
      posts << create(:post, tag_string: "aaa bbb ccc")
      posts << create(:post, tag_string: "aaa bbb")

      assert_equal({ "aaa" => 3, "bbb" => 3, "ccc" => 2, "ddd" => 1 }, RelatedTagCalculator.calculate_from_sample("aaa", 10))
    end

    should("calculate related tags for multiple tag") do
      posts = []
      posts << create(:post, tag_string: "aaa bbb ccc")
      posts << create(:post, tag_string: "aaa bbb ccc ddd")
      posts << create(:post, tag_string: "aaa eee fff")

      assert_equal({ "aaa" => 2, "bbb" => 2, "ddd" => 1, "ccc" => 2 }, RelatedTagCalculator.calculate_from_sample("aaa bbb", 10))
    end

    should("calculate typed related tags for a tag") do
      posts = []
      posts << create(:post, tag_string: "aaa bbb art:ccc copy:ddd")
      posts << create(:post, tag_string: "aaa bbb art:ccc")
      posts << create(:post, tag_string: "aaa bbb")

      assert_equal({ "ccc" => 2 }, RelatedTagCalculator.calculate_from_sample("aaa", 10, TagCategory.artist))
      assert_equal({ "ddd" => 1 }, RelatedTagCalculator.calculate_from_sample("aaa", 10, TagCategory.copyright))
    end

    should("convert a hash into string format") do
      posts = []
      posts << create(:post, tag_string: "aaa bbb ccc ddd")
      posts << create(:post, tag_string: "aaa bbb ccc")
      posts << create(:post, tag_string: "aaa bbb")

      Tag.find_by(name: "aaa")
      counts = RelatedTagCalculator.calculate_from_sample("aaa", 10)
      assert_equal("aaa 3 bbb 3 ccc 2 ddd 1", RelatedTagCalculator.convert_hash_to_string(counts))
    end
  end
end
