require 'httparty'
require 'dotenv'
require 'json'
require 'logging'
require 'digest/md5'

Dotenv.load(File.expand_path('../.env', File.dirname(__FILE__)))

# Utility methods
class Util
  include Logging

  # Tells us whether a GitHub path exists on a given branch
  # @param repo [Repo]
  # @param ref [String] like a branch name or commit hash
  # @param path [String] like `foo/bar/baz` (without leading slash)
  def self.github_path_exists(repo, ref, path)
    url = "https://github.com/#{repo.owner}/#{repo.name}/tree/#{ref}/#{path}"
    github_head(url)
  end

  def self.github_repo_exists(repo)
    url = "https://github.com/#{repo.owner}/#{repo.name}"
    github_head(url)
  end

  def self.github_get_raw(repo, ref, path)
    url = "https://raw.githubusercontent.com/#{repo.owner}/#{repo.name}/#{ref}/#{path}"
    logger.info "GET #{url}"
    response = HTTParty.get(url, basic_auth: github_auth, verify: false)

    return response.body if response.code == 200

    return nil
  end

  # Get branches in repo
  # @param repo [Repo]
  # @return [Array<String>] Branches
  def self.github_list_branches(repo)
    # GET /repos/:owner/:repo/branches
    url = "https://api.github.com/repos/#{repo.owner}/#{repo.name}/branches"
    response = github_get(url)
    JSON.parse(response.body).map { |b| b['name'] }
  end

  def self.github_repo_info(repo)
    url = "https://api.github.com/repos/#{repo.owner}/#{repo.name}"
    response = github_get(url)
    JSON.parse(response.body)
  end

  # Query GitHub search API for .fsh files within a repo
  # @param repo [Repo]
  # @param search_string [String] String to search for
  # @return [Integer] Number of search results found
  def self.github_search_fsh_in_repo(repo, search_string)
    url = 'https://api.github.com/search/code'
    query = { q: %(repo:#{repo.owner}/#{repo.name} extension:fsh "#{search_string}") }
    response = github_get(url, {query: query})

    return false if response.code == 422 # appears when repo isn't public

    parsed_response = JSON.parse(response.body)

    parsed_response['total_count'] > 0
  end

  def self.github_repos_for_user(user)
    url = "https://api.github.com/users/#{user}/repos"
    repos = []
    loop do
      response = github_get(url, { query: { per_page: 100, page: repos.length + 1 } })
      parsed = JSON.parse(response.body)
      break if parsed.length == 0

      repos << parsed.map{ |r| r['name'] }
    end

    repos.flatten
  end

  def self.github_check_auth
    github_get('https://api.github.com/user')
  end

  private

  def self.github_auth
    # Loads in config info in the `.env` file into the `ENV` global variable
    { username: ENV['GITHUB_USERNAME'], password: ENV['GITHUB_TOKEN'] }
  end

  def self.github_get(url, options = {})
    logger.info("GET #{url} #{options[:query] || ''}")
    response = nil
    loop do
      begin
        response = HTTParty.get(
            url,
            query: options[:query],
            headers: { 'Accept' => 'application/vnd.github.v3+json' },
            basic_auth: github_auth,
            verify: false # Ignore SSL errors - sometimes a problem inside the MITRE firewall
        )
        raise "404 for #{url}" if response.code == 404
        break if response.code == 200 || response.code == 422

        logger.info "GitHub error: #{response.code} #{response.body}" if response.code != 200
      rescue Net::OpenTimeout
        logger.info "HTTP timeout, retrying."
      end
      logger.info "Retrying #{url} in 30 seconds."
      sleep 30
    end
    response
  end

  def self.github_head(url)
    logger.info("HEAD #{url}")
    response = nil
    loop do
      begin
        response = HTTParty.head(
            url,
            basic_auth: github_auth,
            verify: false # Ignore SSL errors - sometimes a problem inside the MITRE firewall
        )
        return true if response.code == 200

        return false if response.code == 404
        logger.info "GitHub error: #{response.code} #{response.body}"
      rescue Net::OpenTimeout
        logger.info "HTTP timeout, retrying."
      end
      logger.info "Retrying #{url} in 30 seconds."
      sleep 30
    end
    response
  end
end
