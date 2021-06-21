# Base class for defining a FSH language feature
class FeatureBase
  # Assess branch for feature
  # @param repo [Repo]
  # @param branch [String]
  # @return [Boolean]
  def self.assess(repo, branch)
    raise 'not implemented'
  end
end

# Does branch have a FSH folder for pre-1.0 SUSHI? (Would be at `/fsh`.)
class FeatureSushiOld < FeatureBase
  APPLIES_TO_BRANCHES = :all
  TITLE = 'Uses SUSHI < 1.0'.freeze

  def self.assess(repo, branch)
    Util.github_path_exists(repo, branch, 'fsh')
  end
end

# Does branch have a FSH folder for >=1.0 SUSHI? (Would be at `/input/fsh`.)
class FeatureSushiOne < FeatureBase
  APPLIES_TO_BRANCHES = :all
  TITLE = 'Uses SUSHI >= 1.0'.freeze

  def self.assess(repo, branch)
    Util.github_path_exists(repo, branch, 'input/fsh')
  end
end

# Assumes default branch has SUSHI >= 1.0. Useful when relying on the GitHub search API to identify repos with
# FSH rather than manually checking.
class AssumeFeatureSushiOneDefaultBranch < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'Uses SUSHI >= 1.0'.freeze

  def self.assess(repo)
    true
  end
end

# Defines Profiles in FSH?
class FeaturesProfile < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'Profile defined in FSH'.freeze

  def self.assess(repo)
    Util.github_search_fsh_in_repo(repo, 'Profile: ', repo.sushi1? ? 'input/fsh' : 'fsh')
  end
end

# Defines Instances in FSH?
class FeaturesInstance < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'Instances defined in FSH'.freeze

  def self.assess(repo)
    Util.github_search_fsh_in_repo(repo, 'Instance: ', repo.sushi1? ? 'input/fsh' : 'fsh')
  end
end

# Defines OperationDefinitions in FSH?
class FeaturesOperationDefinition < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'OperationDefinition instance defined in FSH'.freeze

  def self.assess(repo)
    Util.github_search_fsh_in_repo(repo, 'InstanceOf: OperationDefinition', repo.sushi1? ? 'input/fsh' : 'fsh')
  end
end

# Defines SearchParameter in FSH?
class FeaturesSearchParameter < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'SearchParameter instance defined in FSH'.freeze

  def self.assess(repo)
    Util.github_search_fsh_in_repo(repo, 'InstanceOf: SearchParameter', repo.sushi1? ? 'input/fsh' : 'fsh')
  end
end

# Defines Extension in FSH?
class FeaturesExtension < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'Extension defined in FSH'.freeze

  def self.assess(repo)
    Util.github_search_fsh_in_repo(repo, 'Extension: ', repo.sushi1? ? 'input/fsh' : 'fsh')
  end
end

# Defines ValueSet in FSH?
class FeaturesValueSet < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'ValueSet defined in FSH'.freeze

  def self.assess(repo)
    Util.github_search_fsh_in_repo(repo, 'ValueSet: ', repo.sushi1? ? 'input/fsh' : 'fsh')
  end
end

# Defines CodeSystem in FSH?
class FeaturesCodeSystem < FeatureBase
  APPLIES_TO_BRANCHES = :default
  TITLE = 'ValueSet defined in FSH'.freeze

  def self.assess(repo)
    Util.github_search_fsh_in_repo(repo, 'CodeSystem: ', repo.sushi1? ? 'input/fsh' : 'fsh')
  end
end