# Holds a collection of Repo objects
class RepoCollection
  # Collect, de-duplicate, and filter to FSH-only Repo objects
  # @param repos [Array<Repo>]
  # @return [void]
  def initialize(*repos)
    deduplicated_repos = {}

    repos.flatten.compact.each do |r|
      deduplicated_repos[r.identifier] ||= r
    end

    @deduplicated_repos = deduplicated_repos.values.select(&:any_fsh?)
  end

  # Assesses each Repo for each Feature
  # @param features [Array<FeatureBase>]
  # @return [void]
  def assess_repos(*features)
    # Assess each repo for the features defined above
    @deduplicated_repos.each do |r|
      features.each do |f|
        r.assess_feature(f)
      end
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
