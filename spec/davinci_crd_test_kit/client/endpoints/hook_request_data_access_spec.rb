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

  describe 'when fetching a reference' do
    before do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
    end

    it 'reads a relative reference from the request fhirServer with the access token' do
      read = stub_request(:get, organization_example_reference_absolute)
        .with(headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.fetch_reference(organization_example_reference_relative)

      expect(read).to have_been_made.once
    end

    it 'reads a reference to another server without the access token, whatever the case of its scheme' do
      reference = 'HTTPS://elsewhere.example/r4/Organization/other'
      read = stub_request(:get, 'https://elsewhere.example/r4/Organization/other')
        .with { |request| request.headers.keys.none? { |name| name.casecmp?('Authorization') } }
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.fetch_reference(reference)

      expect(read).to have_been_made.once
      expect(module_instance).to have_received(:persist_query_request)
        .with(anything, anything, url: 'https://elsewhere.example/r4/Organization/other', request_headers: {})
    end

    it 'reads a reference to the request fhirServer written in an equivalent form with the access token' do
      read = stub_request(:get, organization_example_reference_absolute)
        .with(headers: { 'Authorization' => 'Bearer SAMPLE_TOKEN' })
        .to_return(status: 200, body: organization_example.to_json)

      module_instance.fetch_reference('HTTPS://EXAMPLE:443/r4/Organization/example')

      expect(read).to have_been_made.once
    end

    it 'records a reference with a scheme other than http(s) as not read, without making a request' do
      reference = 'urn:uuid:9f1c6a52-1d7b-4c9e-8a43-2f0e5b6d7c81'

      expect(module_instance.fetch_reference(reference)).to be_nil
      expect(module_instance).to have_received(:persist_query_request)
        .with(have_attributes(status: nil), anything, url: reference, request_headers: {})
    end

    it 'records a reference that is not a valid url without raising' do
      reference = 'https://elsewhere.example/r4/Organization/not valid'

      expect(module_instance.fetch_reference(reference)).to be_nil
      expect(module_instance).to have_received(:persist_query_request)
        .with(have_attributes(status: nil), anything, url: reference, request_headers: {})
    end
  end

  describe 'when normalizing a reference' do
    before do
      allow(module_instance).to receive(:request_body).and_return(order_sign_request)
    end

    it 'makes a reference to the request fhirServer relative' do
      expect(module_instance.normalize_reference(organization_example_reference_absolute))
        .to eq(organization_example_reference_relative)
    end

    it 'ignores the case of the scheme and host and an explicit default port' do
      expect(module_instance.normalize_reference('HTTPS://Example:443/r4/Organization/example'))
        .to eq(organization_example_reference_relative)
    end

    it 'keeps a query string' do
      expect(module_instance.normalize_reference("#{fhir_server}/Coverage?patient=example"))
        .to eq('Coverage?patient=example')
    end

    it 'leaves a reference to another server, port, or path unchanged' do
      ['https://elsewhere.example/r4/Organization/example', 'https://example:8443/r4/Organization/example',
       'http://example/r4/Organization/example', 'https://example/R4/Organization/example',
       'https://example/r4b/Organization/example'].each do |reference|
        expect(module_instance.normalize_reference(reference)).to eq(reference)
      end
    end

    it 'leaves a relative reference unchanged' do
      expect(module_instance.normalize_reference(organization_example_reference_relative))
        .to eq(organization_example_reference_relative)
    end
  end
end
