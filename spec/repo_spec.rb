require 'repo'
require 'features'
require 'support/git_support'

RSpec.describe Repo do
  include_context :git_objects

  context 'when reading properties from a Repo object' do
    it 'has the expected identifier' do
      repo = Repo.new('fshschool', 'fsh-finder')
      expect(repo.identifier).to eq 'https://github.com/FSHSchool/fsh-finder'
    end
  end

  context 'when retrieving branches' do
    it 'returns at least one branch' do
      expect(@repo_mcode.branches.length).to be > 0
    end
  end

  context 'when sorting repos' do
    it '<=> works as expected' do
      expect(@repo_empty <=> @repo_fsh_positive).to eq 1
    end

    it 'sorts with FSH repos first' do
      expect([@repo_empty, @repo_fsh_positive].sort.first).to eq @repo_fsh_positive
    end
  end

  context 'when getting object for json conversion' do
    it 'should not have symbols for keys' do
      @repo_fsh_positive.assess_feature(FeatureSushiOne)
      as_json = @repo_fsh_positive.as_json

      expect(as_json).to include 'feature_assessments'
      expect(as_json['feature_assessments'][FeatureSushiOne.name]).to include 'any_branch'
    end
  end

  context 'when repo names differ only by capitalization' do
    it 'should give the same identifier for both repos' do
      repo_1 = Repo.new('hl7', 'us-core')
      repo_2 = Repo.new('HL7', 'US-CORE')

      expect(repo_1.identifier).to eq repo_2.identifier
    end
  end

  context 'when a repo is renamed on GitHub' do
    it 'should be properly de-duplicated' do
      repo_1 = Repo.new('HL7', 'US-Core')
      repo_2 = Repo.new('HL7', 'US-Core-R4')

      expect(repo_1.identifier).to eq repo_2.identifier
    end
  end
end
