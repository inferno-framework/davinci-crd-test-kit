require_relative '../../../../lib/davinci_crd_test_kit/client/endpoints/hook_request_data_access'
require_relative 'hook_request_data_fixtures'

RSpec.describe DaVinciCRDTestKit::HookRequestDataAccess do
  include_context 'with hook request data fixtures'

  describe 'when fetching coverage resources' do
    it 'queries if no prefetch data present' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      coverage = module_instance.request_coverage
      expect(coverage.is_a?(FHIR::Coverage)).to be(true)
      expect(coverage.id).to eq('coverage_example')
      expect(cov_request).to have_been_made.once
    end

    it 'queries if no prefetch data present but can handle finding nothing' do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      crd_coverage_bundle.entry.pop
      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      coverage = module_instance.request_coverage
      expect(coverage).to be_nil
      expect(cov_request).to have_been_made.once
    end

    it 'does not query if prefetch data present' do
      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      crd_coverage_bundle.entry.first.resource.id = 'prefetch_coverage'
      order_sign_request['prefetch'] = {
        'coverage' => JSON.parse(crd_coverage_bundle.to_json)
      }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      coverage = module_instance.request_coverage
      expect(coverage.is_a?(FHIR::Coverage)).to be(true)
      expect(coverage.id).to eq('prefetch_coverage')
      expect(cov_request).to_not have_been_made
    end

    it 'finds no coverage if the prefetch data is bad' do
      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      order_sign_request['prefetch'] = {
        'coverage' => JSON.parse(crd_coverage.to_json)
      }
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)

      coverage = module_instance.request_coverage
      expect(coverage).to be_nil
      expect(cov_request).to_not have_been_made
    end
  end
end
