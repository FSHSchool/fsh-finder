require 'concurrent'
require 'logging'

# Holds a collection of Repo objects
class RepoCollection
  include Logging

  MAX_THREADS = 100

  # Collect, de-duplicate, and filter to FSH-only Repo objects
  # @param repos [Array<Repo>]
  # @return [void]
  def initialize(*repos)
    deduplicated_repos = {}

    repos.flatten.compact.each do |r|
      deduplicated_repos[r.identifier.downcase
      ] ||= r
    end

    # Threaded assessment of any_fsh?
    pool = Concurrent::FixedThreadPool.new(MAX_THREADS)
    deduplicated_repos.values.each do |r|
      pool.post do
        # Include features that will be assessed for every single repo here
        r.ensure_feature_has_been_assessed(FeatureSushiOne, FeatureSushiOneConfig, FeatureSushiOld)
      end
    end

    pool.shutdown
    pool.wait_for_termination

    pool = Concurrent::FixedThreadPool.new(MAX_THREADS)
    deduplicated_repos.values.select(&:any_fsh?).each do |r|
      pool.post do
        r.ig_title
      end
    end

    pool.shutdown
    pool.wait_for_termination

    @deduplicated_repos = deduplicated_repos.values.select(&:any_fsh?)
  end

  # Assesses each Repo for each Feature
  # @param features [Array<FeatureBase>]
  # @return [void]
  def assess_repos(*features)
    # Assess each repo for the features defined above
    @deduplicated_repos.each do |r|
      features.each do |f|
        r.ensure_feature_has_been_assessed(f)
      end
    end
  end

  def assess_repos_thread_pool(*features)
    pool = Concurrent::FixedThreadPool.new(MAX_THREADS)
    @deduplicated_repos.each do |r|
      pool.post do
        r.ensure_feature_has_been_assessed(features)
      end
    end

    pool.shutdown
    pool.wait_for_termination
  end

  def assess_repos_ractor(cores, *features)
    queue = Ractor.new do
      loop do
        Ractor.yield(Ractor.recv)
      end
    end

    workers = cores.times.map do
      Ractor.new(queue) do |queue|
        loop do
          repo = queue.take
          features.each do |f|
            repo.ensure_feature_has_been_assessed(f)
          end
        end
      end
    end

    @deduplicated_repos.each do |r|
      queue.send(r)
    end

  end

  # Get context object for populating Liquid template
  # @return [Hash]
  def context
    @context = nil
    @context ||= {
      repos: @deduplicated_repos.sort,
      updated: Time.now,
      fshy_repos: @deduplicated_repos.select(&:any_fsh?).map(&:identifier)
    }.transform_keys(&:to_s)
  end

  # Get version of RepoCollection object appropriate for converting to JSON
  # @return [Hash]
  def as_json()
    context.inject({}) do |out, (k, v)|
      if k == 'repos'
        out[k] = v.map { |r| r.as_json }
      else
        out[k] = v
      end

      out
    end
  end

  # Convert RepoCollection object to JSON
  # @return [String]
  def to_json(*a)
    JSON.pretty_generate(as_json)
  end
end
