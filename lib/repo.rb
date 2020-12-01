require 'logging'

require 'features'
require 'util'

# Object representing a git repository of an IG that may contain FSH.
class Repo
  include Comparable
  include Logging

  # @return [String]
  attr_reader :host, :owner, :name

  # @return [String]
  attr_accessor :primary_branch, :ci_build_url

  # Create Repo object
  # @param owner [String]
  # @param name [String]
  def initialize(owner, name)
    @host = 'github.com'
    @owner = owner
    @name = name
    @feature_assessments = {}
  end

  # Gets unique identifier for a given repository
  # @return [String]
  def identifier
    %(https://#{@host.to_s}/#{@owner.downcase}/#{name.downcase})
  end

  # Gets branches for a repo
  # @return [Array<String>] Array of branch names
  def branches
    @branches_cache ||= Util.github_list_branches(self)
  end

  # Gets the default branch for a repo
  # @return [String] Branch name
  def default_branch
    github_repo_info['default_branch']
  end

  # Gets time when repo was last updated on GitHub
  # @return [Time]
  def updated_at
    Time.parse(github_repo_info['updated_at'])
  end

  # Gets
  def github_repo_info
    @github_repo_info ||= Util.github_repo_info(self)
  end

  # Run a feature assessment against branches in the repo
  # @param feature_class [Class]
  def assess_feature(feature_class)
    if feature_class::APPLIES_TO_BRANCHES == :all
      branches_with_feature = branches.select { |b| feature_class.assess(self, b) }
    else
      branches_with_feature = feature_class.assess(self) ? [default_branch] : []
    end
    @feature_assessments[feature_class.name] = {
      any_branch: !branches_with_feature.empty?,
      branches_with_feature: branches_with_feature,
      title: feature_class::TITLE
    }
  end

  # Does repo have any FSH?
  # @return [Boolean]
  def any_fsh?
    sushi1? || sushiOld?
  end

  # Does repo support SUSHI >= 1.0?
  # @return [Boolean]
  def sushi1?
    ensure_feature_has_been_assessed(FeatureSushiOne)

    @feature_assessments[FeatureSushiOne.name][:any_branch]
  end

  # Does repo support SUSHI < 1.0?
  # @return [Boolean]
  def sushiOld?
    ensure_feature_has_been_assessed(FeatureSushiOld)

    @feature_assessments[FeatureSushiOld.name][:any_branch]
  end

  # Get the title of the implementation guide
  # @return [String]
  def ig_title
    return @ig_title if @ig_title

    if any_fsh?
      if sushi1?
        response_body = Util.github_get_raw(self, default_branch, 'sushi-config.yaml')
      elsif sushiOld?
        response_body = Util.github_get_raw(self, default_branch, 'fsh/config.yaml')
      end

      if response_body
        yaml = YAML.load(response_body.strip) # Call to `strip()` addresses https://github.com/HL7/fhir-med-list-guidance/pull/1
        @ig_title = yaml['title'] || yaml['name']
      end
    end

    @ig_title ||= name

    @ig_title
  end

  # Generate Ruby object appropriate for converting to JSON
  # @return [Hash]
  def as_json
    {
      identifier: identifier,
      ci_build_url: ci_build_url,
      feature_assessments: @feature_assessments.inject({}) { |out, (k, v)| out[k] = v.transform_keys(&:to_s); out},
      ig_title: ig_title,
      repo_host: @host,
      repo_name: @name,
      repo_owner: @owner,
      updated_at: updated_at.strftime('%Y-%m-%dT%H:%M:%S %z'),
    }.transform_keys(&:to_s)
  end

  # Compare Repo objects for sorting
  # @param other [Repo]
  # @return [Integer]
  def <=>(other)
    # First search criteria: implements any version of SUSHI
    if any_fsh? != other.any_fsh?
      return -1 if any_fsh?
      return 1
    end

    # Second criteria: implements Sushi >=1
    if sushi1? != other.sushi1?
      return -1 if sushi1?
      return 1
    end

    # Fallback: updated date, descending
    other.updated_at <=> updated_at
  end

  private

  # Ensures that the passed Feature classes have been assessed
  # @param required_features [Array<FeatureBase>]
  # @return [void]
  def ensure_feature_has_been_assessed(*required_features)
    required_features.each do |required_feature|
      @feature_assessments[required_feature.name] ||= assess_feature(required_feature)
    end
  end
end