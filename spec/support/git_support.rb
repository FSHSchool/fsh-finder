require 'repo'

RSpec.shared_context :git_objects do
  before do
    @repo_mcode = Repo.new('HL7', 'fhir-mCODE-ig')
    @ref_mcode_default_branch = 'master'
    @ref_mcode_old_fsh = '3e9ae7f42adb535495c0951d7a1aad61e9b1437f'

    @repo_empty = Repo.new('masnick', 'test-repo')
    @ref_empty_repo_default_branch = 'main'

    @repo_fsh_positive = Repo.new('masnick', 'fsh-finder-test-positive')
    @ref_fsh_positive_default_branch = 'main'
  end
end