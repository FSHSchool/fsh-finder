require 'repo_sources'
require 'repo'
require 'json'
require 'support/git_support'

RSpec.describe RepoSourceFhirCiBuild do
  include_context :git_objects

  # context RepoSourceGitHubOrgs do
  #   it 'should give us the mCODE IG inside HL7' do
  #     repos = RepoSourceGitHubOrgs.repos.select { |r| r.identifier == @repo_mcode.identifier }
  #     expect(repos.length).to be > 0
  #   end
  # end

  context RepoSourceGitHubOrgsWithClone do
    it 'should give us the mCODE IG inside HL7' do
      repos = RepoSourceGitHubOrgsWithClone.repos.select { |r| r.identifier == @repo_mcode.identifier }
      expect(repos.length).to be > 0
    end
  end

  # context RepoSourceFhirCiBuild do
  #   it 'should give us the mCODE IG' do
  #     repos = RepoSourceFhirCiBuild.repos.select { |r| r.identifier == @repo_mcode.identifier }
  #     expect(repos.length).to be > 0
  #   end
  # end
end
