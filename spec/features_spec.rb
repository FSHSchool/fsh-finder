require 'features'
require 'support/git_support'

RSpec.describe FeatureBase do
  include_context :git_objects

  context FeatureSushiOne do
    it 'check positive' do
      expect(FeatureSushiOne.assess(@repo_mcode, @ref_mcode_default_branch)).to be true
    end

    it 'check negative with old SUSHI' do
      expect(FeatureSushiOne.assess(@repo_mcode, @ref_mcode_old_fsh)).to be false
    end

    it 'check negative with no sushi' do
      expect(FeatureSushiOne.assess(@repo_empty, @ref_empty_repo_default_branch)).to be false
    end
  end

  context FeatureSushiOld do
    it 'check positive' do
      expect(FeatureSushiOld.assess(@repo_mcode, @ref_mcode_old_fsh)).to be true
    end

    it 'check negative with new SUSHI' do
      expect(FeatureSushiOld.assess(@repo_mcode, @ref_mcode_default_branch)).to be false
    end

    it 'check negative with no sushi' do
      expect(FeatureSushiOld.assess(@repo_empty, @ref_empty_repo_default_branch)).to be false
    end
  end

  context FeaturesInstance do
    it 'check positive' do
      expect(FeaturesInstance.assess(@repo_fsh_positive)).to be true
    end

    it 'check negative' do
      expect(FeaturesInstance.assess(@repo_empty)).to be false
    end
  end

  context FeaturesProfile do
    it 'check positive' do
      expect(FeaturesProfile.assess(@repo_fsh_positive)).to be true
    end

    it 'check negative' do
      expect(FeaturesProfile.assess(@repo_empty)).to be false
    end
  end

  context FeaturesOperationDefinition do
    it 'check positive' do
      expect(FeaturesOperationDefinition.assess(@repo_fsh_positive)).to be true
    end

    it 'check negative' do
      expect(FeaturesOperationDefinition.assess(@repo_empty)).to be false
    end
  end

  context FeaturesOperationDefinition do
    it 'check positive' do
      expect(FeaturesOperationDefinition.assess(@repo_fsh_positive)).to be true
    end

    it 'check negative' do
      expect(FeaturesOperationDefinition.assess(@repo_empty)).to be false
    end
  end
end
