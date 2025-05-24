# frozen_string_literal: true

class GitHelper
  include Singleton

  attr_accessor :enabled, :upstream_enabled, :git_exists, :repo_exists, :origin, :upstream, :local
  alias enabled? enabled
  alias upstream_enabled? upstream_enabled

  def initialize
    @enabled = false
    @git_exists = system("type git > /dev/null")
    unless @git_exists
      Rails.logger.error("git is not installed")
      return
    end
    @repo_exists = system("git rev-parse --show-toplevel > /dev/null")
    unless @repo_exists
      Rails.logger.error("not in a git repo")
      return
    end

    @enabled = true
    @local = LocalRef.new
    if Rails.env.production?
      @origin = Ref.new("internal", "master", FemboyFans.config.local_source_code_url)
      @upstream = Ref.new("upstream", "master", FemboyFans.config.source_code_url)
    else
      branch = `git rev-parse --abbrev-ref HEAD`.strip
      remote = `git config branch.#{branch}.remote`.strip
      @origin = Ref.new(remote, branch, FemboyFans.config.source_code_url)
      @upstream = nil
    end
  end

  class Ref
    attr_accessor :remote, :branch, :url, :exists, :commit, :tag

    def initialize(remote, branch, url)
      @remote = remote
      @branch = branch
      @url = url

      @exists = system("git show-ref --quiet #{remote}/#{branch}")
      raise(StandardError, "#{remote}/#{branch} does not exist") unless @exists
      return unless @exists
      @commit = `git rev-parse #{remote}/#{branch}`.strip
      raise("Could not get commit for #{remote}/#{branch}") if @commit.blank?
      @tag = `git tag --points-at #{commit}`.strip.presence
    end

    def short_commit
      @commit&.[](0..7)
    end

    def latest
      return @latest if instance_variable_defined?(:@latest)
      system("git fetch #{remote} #{branch}")
      @latest = `git rev-parse #{remote}/#{branch}`.strip.presence
    end

    def reset_latest
      remove_instance_variable(:@latest)
    end

    def commit_url(commit)
      "#{url}/commit/#{commit}"
    end

    def tag_url(tag)
      "#{url}/releases/tag/#{tag}"
    end

    def latest_commit_url
      commit_url(latest)
    end

    def current_commit_url
      commit_url(commit)
    end

    def current_tag_url
      tag.present? ? tag_url(tag) : nil
    end

    def compare(ref)
      Comparison.new(self, ref)
    end
    alias diff compare

    def ==(other)
      other.is_a?(Ref) && remote == other.remote && branch == other.branch
    end
  end

  class LocalRef < Ref
    def initialize
      @remote = nil
      @branch = nil
      @url = nil
      @exists = true
      @commit = `git rev-parse HEAD`.strip
      @tag = `git tag --points-at #{commit}`.strip.presence
    end

    alias latest commit

    def noop(*)
      nil
    end

    alias commit_url noop
    alias tag_url noop
    alias latest_commit_url noop
    alias current_commit_url noop
    alias current_tag_url noop
  end

  class Comparison
    attr_accessor :a, :b

    def initialize(a, b) # rubocop:disable Naming/MethodParameterName
      @a = a
      @b = b
    end

    def common
      @common ||= `git merge-base #{a.commit} #{b.commit}`.strip
    end

    def behind
      @behind ||= `git rev-list --count #{a.commit}..#{b.commit}`.strip.to_i
    end

    def behind?
      behind > 0
    end

    def ahead
      @ahead ||= `git rev-list --count #{b.commit}..#{a.commit}`.strip.to_i
    end

    def ahead?
      ahead > 0
    end

    def ==(other)
      other.is_a?(Comparison) && a == other.a && b == other.b
    end
  end

  def public_ref
    upstream || origin
  end

  def common_commit
    upstream.present? ? origin.compare(upstream).common : origin.commit
  end

  def commit_url(commit)
    "#{origin.url}/commit/#{commit}"
  end

  def public_commit_url
    public_ref.commit_url(common_commit)
  end
end
