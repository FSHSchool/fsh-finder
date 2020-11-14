require 'repo_collection'
require 'support/git_support'


RSpec.describe RepoCollection do
  include_context :git_objects

  context 'initializer' do
    it 'removes duplicates' do
      repos = RepoCollection.new([@repo_mcode, @repo_fsh_positive], [@repo_mcode])
      expect(repos.as_json['repos'].length).to eq 2
    end
  end

  context 'output' do
    it 'generates context' do
      repos = RepoCollection.new([@repo_fsh_positive])
      expect(repos.context).to be_a Hash
      expect(repos.context['repos'].first).to be @repo_fsh_positive
      expect(repos.context['fshy_repos'].first).to be == @repo_fsh_positive.identifier
    end

    it 'generates json' do
      repos = RepoCollection.new([@repo_fsh_positive])
      json = repos.to_json
      expect(json).to be_a String
    end
  end
end
