require_relative '../../lib/davinci_crd_test_kit/routes/hook_request_endpoint'
require_relative '../../lib/davinci_crd_test_kit/tags'

RSpec.describe DaVinciCRDTestKit::HookRequestEndpoint, :request do
  let(:suite_id) { 'crd_client' }
  let(:test) { DaVinciCRDTestKit::OrderSignReceiveRequestTest }

  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:requests_repo) { Inferno::Repositories::Requests.new }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }
  let(:fhirpath_false_response_body) { [{ type: 'boolean', element: false }] }
  let(:fhirpath_true_response_body) { [{ type: 'boolean', element: true }] }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_sign_url) { "#{base_url}/cds-services/order-sign-service" }

  let(:server_endpoint) { '/custom/crd_client/cds-services/order-sign-service' }
  let(:instructions_card_template) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'card_responses', 'instructions.json'
                         )))
  end

  let(:order_sign_hook_request) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', 'fixtures', 'order_sign_hook_request.json'
                         )))
  end
  let(:fhir_server) { 'https://example/r4' }
  let(:patient_example_reference_relative) { 'Patient/example' }
  let(:patient_example_reference_absolute) { "#{fhir_server}/#{patient_example_reference_relative}" }
  let(:patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:practitioner_example_reference_relative) { 'Practitioner/example' }
  let(:practitioner_example_reference_absolute) { "#{fhir_server}/#{practitioner_example_reference_relative}" }
  let(:practitioner_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_practitioner_example.json')))
  end
  let(:crd_coverage) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', 'fixtures', 'crd_coverage_example.json'
                         )))
  end
  let(:crd_coverage_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: 'https://example.com/base/Coverage/coverage_example',
                          resource: FHIR.from_contents(crd_coverage.to_json)
                        ))
    bundle
  end
  let(:coverage_search_url) { "#{fhir_server}/Coverage?patient=example&status=active" }

  # from inferno core (spec/runnable_context.rb) since described class is not one that can receive requests
  let(:suite) { Inferno::Repositories::TestSuites.new.find(suite_id) }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:validation_url) { "#{ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')}/validate" }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }

  def run(runnable, inputs = {}, scratch = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |original_name, value|
      name = runnable.config.input_name(original_name).presence || original_name
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.available_inputs[name.to_sym]&.type
      )
    end

    Inferno::TestRunner.new(test_session:, test_run:).run(runnable, scratch)
  end

  describe 'When fetching data during a hook invocation' do
    it 'makes and tags requests for order-sign' do
      allow(test).to receive(:suite).and_return(suite)
      pat_request = stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      p_request = stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      cov_request = stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)

      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      hook_instance = order_sign_hook_request['hookInstance']

      run(test, cds_jwt_iss: example_client_url, order_sign_custom_response: instructions_card_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, order_sign_hook_request)

      expect(last_response).to be_ok
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(cov_request).to have_been_made.once
      tagged_requests = requests_repo.tagged_requests(test_session.id,
                                                      [hook_instance, DaVinciCRDTestKit::DATA_FETCH_TAG])
      expect(tagged_requests.length).to eq(3)
      expect(tagged_requests.one? { |request| request.url == patient_example_reference_absolute }).to be(true)
      expect(tagged_requests.one? { |request| request.url == practitioner_example_reference_absolute }).to be(true)
      expect(tagged_requests.one? { |request| request.url == coverage_search_url }).to be(true)
    end
  end
end
