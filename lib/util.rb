require 'httparty'
require 'dotenv'
require 'json'
require 'logging'
require 'digest/md5'
require 'tmpdir'
require 'fileutils'
require 'securerandom'

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
  def self.github_search_fsh_in_repo(repo, search_string, in_path = nil)
    url = 'https://api.github.com/search/code'
    query = { q: %(repo:#{repo.owner}/#{repo.name}#{' path:' + in_path if in_path} extension:fsh "#{search_string}") }
    response = github_get(url, {query: query})

    return false if response.code == 422 # appears when repo isn't public

    parsed_response = JSON.parse(response.body)

    parsed_response['total_count'] > 0
  end

  def self.github_repos_with_fsh_for_user(user)
    url = 'https://api.github.com/search/code'
    query = %(extension:fsh path:/input/fsh/ user:#{user})

    page = 1
    repos = []
    loop do
      response = github_get(url, { query: {q: query, per_page: 100, page: page } })
      parsed = JSON.parse(response.body)
      break if response.code != 200
      break if parsed['total_count'] == 0
      break if parsed['items'].length == 0

      repos << parsed['items'].map {|m| m['repository']['name']}.uniq
      page += 1
    end

    repos.flatten.uniq
  end

  def self.github_repos_for_user(user)
    url = "https://api.github.com/users/#{user}/repos"
    repos = []
    loop do
      begin
        response = github_get(url, { query: { per_page: 100, page: repos.length + 1 } })
      rescue GitHub404Error
        logger.info("GitHub user <#{user}> not found")
        return []
      end
      parsed = JSON.parse(response.body)
      # Ignore forks, ignore empty repos (size = 0)
      parsed.select! { |p| p['fork'] == false && p['size'] > 0 }
      repos << parsed.map { |r| Repo.new(user, r['name'], default_branch: r['default_branch'], updated_at: r['updated_at']) }

      break if parsed.length < 100
    end
    return repos
  end

  def self.github_check_auth
    # Make sure authentication ENV vars are actually set
    raise ".env not set" if !ENV['GITHUB_USERNAME'] || !ENV['GITHUB_TOKEN']

    # `github_get` will have a 200 code if authenticated, 401 if auth is bad
    github_get('https://api.github.com/repos/fshschool/fsh-finder')
  end

  private

  def self.github_auth
    # Loads in config info in the `.env` file into the `ENV` global variable
    { username: ENV['GITHUB_USERNAME'], password: ENV['GITHUB_TOKEN'] }
  end

  class GitHub404Error < StandardError
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
        raise GitHub404Error, "404 for #{url}" if response.code == 404
        raise "401 (requires authentication) for #{url}" if response.code == 401
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

  class GitCloneError < StandardError
    attr_reader :git_command_output, :git_exit_code

    def initialize(message, git_command_output: nil, git_exit_code: nil)
      super(message)
      @git_command_output = git_command_output
      @git_exit_code = git_exit_code
    end
  end

  def self.git_clone(user, repo)
    # Sanitize inputs
    regex = /[^0-9A-Za-z_\-.]/
    user.gsub!(regex, '')
    repo.gsub!(regex, '')

    # Get a temp folder to clone into
    folder = File.join(Dir.pwd, 'clones', user, repo)

    retries = 0
    loop do
      begin
        if File.exist?(folder)
          # FileUtils.remove_dir(folder)
          # Git pull doesn't appear to work well on a shallow clone.
          # It's possible `git fetch` first would resolve this problem, but we aren't setting a remote
          cmd = "cd #{folder} && git pull https://#{ENV['GITHUB_TOKEN']}:x-oauth-basic@github.com/#{user}/#{repo}.git 2>&1"
          logger.info "Running: #{cmd}"
          git_output = %x(#{cmd})
          status = $?.exitstatus
          raise GitCloneError.new("Could not pull #{user}/#{repo}", git_output, status) unless status == 0
        else
          FileUtils.mkdir_p folder
          # Clone the repo
          cmd = "cd #{folder} && git init && git pull --depth 1 https://#{ENV['GITHUB_TOKEN']}:x-oauth-basic@github.com/#{user}/#{repo}.git 2>&1"
          logger.info "Running: #{cmd}"
          git_output = %x(#{cmd})
          status = $?.exitstatus
          raise GitCloneError.new("Could not clone #{user}/#{repo}", git_output, status) unless status == 0
        end

        return folder
      rescue GitCloneError => e
        if e.git_command_output.include?("Couldn't find remote ref HEAD")
          # This means the repo is empty
          logger.info("#{user}/#{repo} is empty: #{git_output}")
          break
        end
        logger.info "Failure running #{cmd}"
        logger.info git_output
      end
      if retries < 4
        logger.info "Retrying #{user}/#{repo} in 30 seconds."
        sleep 30
        retries += 1
      else
        logger.info "Too many retries. Quitting."
        raise GitCloneError, "Could not clone/pull #{user}/#{repo}"
      end
    end
  end

  # @param [Repo] repo
  # @param [String] glob
  def self.git_file_exists?(repo, glob)
    !Dir.glob(File.join(repo.folder, glob)).empty?
  end
end
