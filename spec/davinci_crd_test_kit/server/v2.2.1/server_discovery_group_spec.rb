RSpec.describe DaVinciCRDTestKit::V221::ServerDiscoveryGroup do
  let(:suite_id) { 'crd_server_v221' }
  let(:group) { Inferno::Repositories::TestGroups.new.find('crd_v221_server_discovery_group') }
  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:workspace_bearer) { 'workspace-token' }
  let(:cds_services) { { 'services' => [] } }

  describe 'discovery endpoint test' do
    let(:runnable) { group.tests[1] }

    it 'sends the workspace bearer' do
      discovery_request = stub_request(:get, discovery_url)
        .with(headers: { 'Authorization' => "Bearer #{workspace_bearer}" })
        .to_return(status: 200, body: cds_services.to_json)

      result = run(runnable, base_url:, workspace_bearer:)

      expect(result.result).to eq('pass')
      expect(discovery_request).to have_been_made.once
    end

    it 'sends the localhost origin when the base URL is host.docker.internal' do
      docker_base = 'http://host.docker.internal:22041/auth/fhir'
      discovery_request = stub_request(:get, "#{docker_base}/cds-services")
        .with(headers: {
                'Authorization' => "Bearer #{workspace_bearer}",
                'X-Forwarded-Host' => 'localhost',
                'X-Forwarded-Proto' => 'http',
                'X-Forwarded-Port' => '22041'
              })
        .to_return(status: 200, body: cds_services.to_json)

      result = run(runnable, base_url: docker_base, workspace_bearer:)

      expect(result.result).to eq('pass')
      expect(discovery_request).to have_been_made.once
    end
  end
end
