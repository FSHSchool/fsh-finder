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
  def initialize(owner, name, default_branch: nil, updated_at: nil)
    @host = 'github.com'
    @owner = owner
    @name = name
    @default_branch = default_branch
    @updated_at = Time.parse(updated_at) if updated_at
    @feature_assessments = {}
  end

  def folder
    @folder ||= Util.git_clone(@owner, @name)
  end

  # Gets unique identifier for a given repository
  # @return [String]
  def identifier
    @identifier ||= %(https://#{@host.to_s}/#{owner}/#{name})
  end

  # Gets branches for a repo
  # @return [Array<String>] Array of branch names
  def branches
    # This uses all branches
    # @branches_cache ||= Util.github_list_branches(self)

    # This uses just the default branch
    @branches_cache ||= [default_branch]
  end

  # Gets the default branch for a repo
  # @return [String] Branch name
  def default_branch
    @default_branch ||= github_repo_info['default_branch']
  end

  # Gets time when repo was last updated on GitHub
  # @return [Time]
  def updated_at
    @updated_at ||= Time.parse(github_repo_info['updated_at'])
  end

  # Gets
  def github_repo_info
    @github_repo_info ||= Util.github_repo_info(self)
  end

  # Run a feature assessment against branches in the repo
  # @param feature_class [Class]
  def assess_feature(feature_class)
    # Attempt to load from cache if allowed
    cache_file = File.join(Dir.pwd, 'generated', 'repo_data', owner, "#{name}.json")
    if feature_class.cacheable? != false && File.exist?(cache_file)
      begin
        cache = JSON.parse(File.read(cache_file))
        if cache.is_a?(Hash) \
          && cache.include?('feature_assessments') \
          && cache['feature_assessments'].include?(feature_class.name)
          feature_assessment = cache['feature_assessments'][feature_class.name]
          if Time.parse(feature_assessment['last_updated']) > feature_class.cacheable?.ago
            logger.info(
              "Reading cache for #{owner}/#{name}/#{feature_class.name}, last updated #{feature_assessment['last_updated']}"
            )
            # Only use cache if feature appears on a branch
            return feature_assessment.transform_keys(&:to_sym) if feature_assessment['any_branch']
          end
        end
      rescue JSON::ParserError
      end
      end

    if feature_class::APPLIES_TO_BRANCHES == :all
      branches_with_feature = branches.select { |b| feature_class.assess(self, b) }
    else
      branches_with_feature = feature_class.assess(self) ? [default_branch] : []
    end

    # Sets the instance variable to make `as_json()` work for caching
    @feature_assessments[feature_class.name] = {
      any_branch: !branches_with_feature.empty?,
      branches_with_feature: branches_with_feature,
      default_branch: branches_with_feature.include?(default_branch),
      title: feature_class::TITLE,
      last_updated: DateTime.now.iso8601
    }
    # Cache
    cache_folder = File.dirname(cache_file)
    FileUtils.mkdir_p(cache_folder) unless File.exist?(cache_folder)
    cache_contents = {
      'feature_assessments' => @feature_assessments.inject({}) { |out, (k, v)| out[k] = v.transform_keys(&:to_s); out}
    }
    File.open(cache_file,"w") do |f|
      f.write(JSON.pretty_generate(cache_contents))
    end
    
    return @feature_assessments[feature_class.name]
  end

  # Does repo have any FSH?
  # @return [Boolean]
  def any_fsh?
    sushi1? || sushiOld?
  end

  # Does repo support SUSHI >= 1.0?
  # @return [Boolean]
  def sushi1?
    return sushi1fsh? || sushi1config?
  end

  # Does repo support SUSHI < 1.0?
  # @return [Boolean]
  def sushiOld?
    ensure_feature_has_been_assessed(FeatureSushiOld)
    @feature_assessments[FeatureSushiOld.name][:any_branch]
  end

  def sushi1fsh?
    ensure_feature_has_been_assessed(FeatureSushiOne)
    return true if @feature_assessments[FeatureSushiOne.name][:any_branch]
  end

  def sushi1config?
    ensure_feature_has_been_assessed(FeatureSushiOneConfig)
    return true if @feature_assessments[FeatureSushiOneConfig.name][:any_branch]
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
        begin
          yaml = YAML.load(response_body.strip) # Call to `strip()` addresses https://github.com/HL7/fhir-med-list-guidance/pull/1
          @ig_title = yaml['title'] || yaml['name']
        rescue
          @ig_title = name
        end
      end
    end

    @ig_title ||= name
  end

  # Generate Ruby object appropriate for converting to JSON
  # @return [Hash]
  def as_json
    {
      identifier: identifier,
      ci_build_url: ci_build_url,
      feature_assessments: @feature_assessments.inject({}) { |out, (k, v)| out[k] = v.transform_keys(&:to_s); out},
      ig_title: ig_title,
      repo_host: host,
      # Use the GitHub API info to get proper capitalization for the repo name and owner
      repo_name: name,
      repo_owner: owner,
      updated_at: updated_at.strftime('%Y-%m-%dT%H:%M:%S %z'),
    }.transform_keys(&:to_s)
  end

  # Compare Repo objects for sorting
  # @param other [Repo]
  # @return [Integer]
  def <=>(other)
    # Changing to sort just by updated_at -- but leaving the old sort criteria in case we want it later.
    # First search criteria: implements any version of SUSHI
    # if any_fsh? != other.any_fsh?
    #   return -1 if any_fsh?
    #   return 1
    # end

    # Second criteria: implements Sushi >=1
    # if sushi1? != other.sushi1?
    #   return -1 if sushi1?
    #   return 1
    # end

    # Fallback: updated date, descending
    other.updated_at <=> updated_at
  end

  # Ensures that the passed Feature classes have been assessed
  # @param required_features [Array<FeatureBase>]
  # @return [void]
  def ensure_feature_has_been_assessed(*required_features)
    logger.info "Assessing #{owner}/#{name}"
    required_features.each do |required_feature|
      @feature_assessments[required_feature.name] ||= assess_feature(required_feature)
    end
  end
end