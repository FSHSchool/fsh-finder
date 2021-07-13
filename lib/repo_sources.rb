require 'httparty'
require 'json'
require 'repo'
require 'yaml'
require 'concurrent'

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

    search_user_repos_for_fsh = {}

    # De-duplicate repos
    unique_repos = {}
    repos.each do |r|
      # Ignore if a repo with the same ci_build_url value is already discovered -- there are entries for multiple branches
      # for the same repo in some cases.
      #
      # Note that if a repo has been renamed on GitHub, it's possible to have two Repo objects that point to the same
      # GitHub repo but have different `ci_build_url` values. If this happens, there will be some duplicate requests
      # to the GitHub API, and these duplicates won't get caught until the dedupe step in RepoCollection.
      next if unique_repos.values.map(&:ci_build_url).include? r.ci_build_url

      # Search all user's repos for FSH. Cache results so we only do this once per user.
      search_user_repos_for_fsh[r.owner] ||= Util.github_repos_with_fsh_for_user(r.owner)
      next unless search_user_repos_for_fsh[r.owner].include? r.name

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

# Uses the GitHub Search API to find FSH in repos belonging to orgs who have repos registered with build.fhir.org,
# or who are in the manual list in settings.yml
class RepoSourceGitHubOrgs < RepoSource
  def self.repos
    crawl = YAML.load_file('settings.yml')['crawl_orgs']

    crawl << JSON.parse(HTTParty.get('https://build.fhir.org/ig/qas.json', verify: false).body)
                 .map {|r| r['repo'].split('/')[0] }
                 .uniq
    crawl.uniq.flatten.map do |org|
      Util.github_repos_with_fsh_for_user(org).map { |r| Repo.new(org, r) }
    end.flatten
  end
end

class RepoSourceGitHubOrgsWithClone < RepoSource
  def self.repos
    crawl = YAML.load_file('settings.yml')['crawl_orgs']

    crawl << JSON.parse(HTTParty.get('https://build.fhir.org/ig/qas.json', verify: false).body)
                 .map {|r| r['repo'].split('/')[0] }
                 .uniq
    crawl = crawl. uniq.flatten

    repos = Concurrent::Array.new()
    pool = Concurrent::FixedThreadPool.new(10)
    crawl.each do |org|
      pool.post do
        repos << Util.github_repos_for_user(org)
      end
    end

    pool.shutdown
    pool.wait_for_termination
    return repos.flatten
  end
end


class RepoSourceTest < RepoSource
  def self.repos
    [Util.github_repos_for_user('SaraAlert'), Util.github_repos_for_user('dvci')].flatten
  end
end
