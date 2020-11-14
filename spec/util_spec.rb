require 'util'
require 'repo'
require 'support/git_support'

RSpec.describe Util do
  include_context :git_objects
  context 'when checking for GitHub path existence' do
    it 'returns true for a path that exists' do
      expect(Util.github_path_exists(@repo_mcode, 'master', 'README.md')).to be true
    end
    it "returns false for a path that doesn't exist" do
      expect(Util.github_path_exists(@repo_mcode, 'master', 'this_file_does_not_exist.txt')).to be false
    end
  end

  context 'when listing repo branches on GitHub' do
    it 'returns a list of branches' do
      branches = Util.github_list_branches(@repo_mcode)
      expect(branches).to include @ref_mcode_default_branch
      expect(branches.length).to be >= 1
    end
  end

  context 'when getting default branch on GitHub' do
    it 'should return main when using a test repo' do
      expect(Util.github_repo_info(Repo.new('masnick', 'test-repo'))['default_branch']).to eq 'main'
    end
  end

  context 'when searching repo' do
    it 'should return at least one result when the search string exists in the repo' do
      expect(Util.github_search_fsh_in_repo(@repo_mcode, 'id')).to be true
    end

    it 'should return at least no results when the search string does not exist in the repo' do
      expect(Util.github_search_fsh_in_repo(@repo_mcode, 'this_string_is_definitely_not_in_the_repo')).to be false
    end
  end

  context 'when getting repos for a user' do
    it 'should return some repos' do
      expect(Util.github_repos_for_user('masnick')).to include @repo_fsh_positive.name
    end
  end

  context 'when making a request to GitHub' do
    it 'should be authorized' do
      expect( Util.github_check_auth.code).to be 200
    end
  end
end
