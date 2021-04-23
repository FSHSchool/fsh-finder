require 'httparty'
require 'json'
require 'repo'

# Defines a source for FHIR Implementation Guide git repositories that may include FSH.
# For now, assume that all are hosted on GitHub.
class RepoSource
  # Get `Repo` objects for each possible FSH IG in the RepoSource
  #
  # @return [Array<Repo>]
  def self.repos
    raise 'not implemented'
  end

  private

  # Takes input from an external API and converts it to a Repo object
  #
  # @param input [Object] some sort of API input
  # @return [Repo]
  def self.create_repo_object_from(input)
    raise 'not implemented'
  end
end

# Find repos listed in CI build config
class RepoSourceFhirCiBuild < RepoSource
  def self.repos
    build_info = JSON.parse(HTTParty.get('https://build.fhir.org/ig/qas.json', verify: false).body)

    repos = build_info.filter_map { |r| create_repo_object_from(r) }

    # De-duplicate repos
    unique_repos = {}
    repos.each do |r|
      # Ignore if a repo with the same ci_build_url value is already discovered -- there are entries for multiple branches
      # for the same repo in some cases.
      #
      # Note that if a repo has been renamed on GitHub, it's possible to have two Repo objects that point to the same
      # GitHub repo but have different `ci_build_url` values. If this happens, there will be some duplicate requests
      # to the GitHub API, and these duplicates won't get caught until the dedupe step in RepoCollection.
      next if unique_repos.values.map{ |existing_unqiue_repo| existing_unqiue_repo.ci_build_url }.include? r.ci_build_url

      # Remove repos that aren't public on GitHub or don't exist
      next unless Util.github_repo_exists(r)

      unique_repos[r.identifier] ||= r
    end

    unique_repos.values
  end

  private

  def self.create_repo_object_from(input)
    owner = input['repo'].match(%r{([^/]*)}).to_s
    name = input['repo'].match(%r{[^/]*/([^/]*)})[1]

    repo = Repo.new(owner, name)

    repo.ci_build_url = "https://build.fhir.org/ig/#{repo.owner}/#{repo.name}"

    repo
  end
end

# Adds specific repos of interest
class RepoSourceStatic < RepoSource
  def self.repos
    # TODO: Move this to a YAML file
    [
        Repo.new('SaraAlert', 'saraalert-fhir-ig'),
    ].select { |r| Util.github_repo_exists(r)}
  end
end

# Crawls all repos for a given GitHub org
class RepoSourceGitHubOrgs < RepoSource
  def self.repos
    # TODO: Move this to a YAML file
    [
      'HL7',
      'hl7dk',
      'HL7NZ',
      'hl7-eu',
      'who-int'
    ].map do |org|
      Util.github_repos_for_user(org).map { |r| Repo.new(org, r) }
    end.flatten
  end
end
