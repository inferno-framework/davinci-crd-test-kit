require_relative '../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_user_access_level_group'

RSpec.describe DaVinciCRDTestKit::V221::ClientUserAccessLevelGroup do
  let(:suite_id) { 'crd_client_v221' }
  let(:group) { Inferno::Repositories::TestGroups.new.find('crd_v221_client_user_access_level') }

  def test_with_suffix(suffix)
    group.tests.find { |test| test.id.to_s.end_with?(suffix) }
  end

  it 'gives the two interaction tests distinct interaction groups' do
    expect(test_with_suffix('crd_v221_access_level_receive_request_full').config.options[:crd_interaction_group])
      .to eq(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG)
    expect(test_with_suffix('crd_v221_access_level_receive_request_limited').config.options[:crd_interaction_group])
      .to eq(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG)
  end

  # these are set once on the group, so confirm they still reach the tests that read them
  it 'accepts any hook and keeps the requests out of the cross-hook analyses' do
    ['crd_v221_access_level_receive_request_full', 'crd_v221_access_level_receive_request_limited'].each do |suffix|
      options = test_with_suffix(suffix).config.options

      expect(options[:hook_name]).to eq(DaVinciCRDTestKit::ANY_HOOK_TAG)
      expect(options[:include_in_cross_hook_analysis]).to be(false)
    end
  end

  it 'runs as a group so that both interaction tests are executed together' do
    expect(group.run_as_group?).to be(true)
  end
end
