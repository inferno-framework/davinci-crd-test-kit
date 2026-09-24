RSpec.describe DaVinciCRDTestKit::V221::ServerDiscoveryGroup do
  let(:suite_id) { 'crd_server_v221' }
  let(:group) { Inferno::Repositories::TestGroups.new.find('crd_v221_server_discovery_group') }
  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:cds_services) { { 'services' => [] } }

  describe 'discovery endpoint test' do
    let(:runnable) { group.tests[1] }

    it 'sends the workspace bearer when discovery requires authentication' do
      allow(DaVinciCRDTestKit::AnteriorWorkspaceToken)
        .to receive(:authorization_header)
        .with(discovery_url)
        .and_return('Bearer workspace-token')
      discovery_request = stub_request(:get, discovery_url)
        .with(headers: { 'Authorization' => 'Bearer workspace-token' })
        .to_return(status: 200, body: cds_services.to_json)

      result = run(runnable, base_url:, authentication_required: 'yes')

      expect(result.result).to eq('pass')
      expect(discovery_request).to have_been_made.once
    end
  end
end
