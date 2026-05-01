require_relative '../../lib/davinci_crd_test_kit/client/endpoints/hook_request_endpoint'
require_relative '../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::HookRequestEndpoint, :request do
  let(:suite_id) { 'crd_client' }
  let(:test) { DaVinciCRDTestKit::V201::OrderSignReceiveRequestTest }

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
                           __dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'client', 'endpoints',
                           'mocked_card_responses', 'instructions.json'
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

  def hook_instance_tag(hook_instance)
    "#{DaVinciCRDTestKit::HOOK_INSTANCE_TAG_PREFIX}#{hook_instance}"
  end

  describe 'When responding' do
    it 'returns 400 when the hookInstance has already been used' do
      allow(test).to receive(:suite).and_return(suite)
      stub_request(:get, patient_example_reference_absolute)
        .to_return(status: 200, body: patient_example.to_json)
      stub_request(:get, practitioner_example_reference_absolute)
        .to_return(status: 200, body: practitioner_example.to_json)
      stub_request(:get, coverage_search_url)
        .to_return(status: 200, body: crd_coverage_bundle.to_json)
      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      run(test, cds_jwt_iss: example_client_url,
                order_sign_custom_response_template: instructions_card_template.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, order_sign_hook_request)
      post_json(server_endpoint, order_sign_hook_request)

      expect(last_response).to be_client_error
      expect(last_response.body)
        .to match(/Hook instance `#{order_sign_hook_request['hookInstance']}` has already been used in this session./)
    end

    it 'returns 500 when the hook is not supported since cannot find session' do
      allow(test).to receive(:suite).and_return(suite)
      token = jwt_helper.build(
        aud: order_sign_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      run(test, cds_jwt_iss: example_client_url,
                order_sign_custom_response_template: instructions_card_template.to_json)

      order_sign_hook_request['hook'] = 'not_a_hook'
      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, order_sign_hook_request)

      expect(last_response).to be_server_error
      expect(last_response.body)
        .to match(/Unable to find test run with identifier 'not_a_hook #{example_client_url}'./)
    end
  end

  describe '#apply_hook_configuration' do
    let(:endpoint) { described_class.allocate }
    let(:coverage_info_card) { { 'summary' => 'Coverage', 'source' => { 'type' => 'coverage-info' } } }
    let(:coverage_info_topic_card) do
      { 'summary' => 'Coverage topic', 'source' => { 'topic' => { 'code' => 'coverage-info' } } }
    end
    let(:guideline_card) { { 'summary' => 'Guideline', 'source' => { 'topic' => { 'code' => 'guideline' } } } }
    let(:coverage_info_action) do
      {
        'type' => 'update',
        'resource' => {
          'resourceType' => 'ServiceRequest',
          'extension' => [{ 'url' => DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFO_EXT_URL }]
        }
      }
    end
    let(:form_completion_action) do
      {
        'type' => 'create',
        'resource' => {
          'resourceType' => 'Task',
          'code' => { 'coding' => [{ 'code' => 'complete-questionnaire' }] },
          'input' => [
            {
              'type' => { 'text' => 'questionnaire' },
              'valueCanonical' => 'http://example.com/Questionnaire/example'
            }
          ]
        }
      }
    end
    let(:other_action) { { 'type' => 'delete', 'resource' => { 'resourceType' => 'ServiceRequest' } } }

    it 'filters coverage-info cards and actions when the coverage-info configuration option is false' do
      allow(endpoint).to receive(:request_body).and_return(
        'extension' => {
          'davinci-crd.configuration' => {
            'coverage-info' => false
          }
        }
      )

      response_body = {
        'cards' => [coverage_info_card, coverage_info_topic_card, guideline_card],
        'systemActions' => [coverage_info_action, form_completion_action, other_action]
      }

      filtered_response = endpoint.apply_hook_configuration(response_body)

      expect(filtered_response['cards']).to eq([guideline_card])
      expect(filtered_response['systemActions']).to eq([other_action])
    end
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

      run(test, cds_jwt_iss: example_client_url,
                order_sign_custom_response_template: { cards: [instructions_card_template] }.to_json)

      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, order_sign_hook_request)

      expect(last_response).to be_ok
      expect(p_request).to have_been_made.once
      expect(pat_request).to have_been_made.once
      expect(cov_request).to have_been_made.once
      tagged_requests = requests_repo.tagged_requests(test_session.id,
                                                      [hook_instance_tag(hook_instance),
                                                       DaVinciCRDTestKit::DATA_FETCH_TAG])
      expect(tagged_requests.length).to eq(3)
      expect(tagged_requests.one? { |request| request.url == patient_example_reference_absolute }).to be(true)
      expect(tagged_requests.one? { |request| request.url == practitioner_example_reference_absolute }).to be(true)
      expect(tagged_requests.one? { |request| request.url == coverage_search_url }).to be(true)
    end
  end

  describe 'ig_version inference' do
    describe 'when posting to the v221 endpoint path' do
      let(:suite_id) { 'crd_client_v221' }
      let(:test) { DaVinciCRDTestKit::V221::OrderSignReceiveRequestTest }
      let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
      let(:server_endpoint) { '/custom/crd_client_v221/cds-services/order-sign-service' }

      it 'does not make FHIR data-fetch requests when version inferred from path' do
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

        run(test, cds_jwt_iss: example_client_url,
                  order_sign_custom_response_template: { cards: [instructions_card_template] }.to_json)

        header('Authorization', "Bearer #{token}")
        post_json(server_endpoint, order_sign_hook_request)

        expect(last_response).to be_ok
        expect(pat_request).to_not have_been_made
        expect(p_request).to_not have_been_made
        expect(cov_request).to_not have_been_made
      end

      it 'fetches the coverage payer when coverage with a payer reference is in the prefetch' do
        allow(test).to receive(:suite).and_return(suite)
        payer_org_url = "#{fhir_server}/Organization/example-payer"
        payer_request = stub_request(:get, payer_org_url)
          .to_return(status: 200, body: { 'resourceType' => 'Organization', 'id' => 'example-payer' }.to_json)

        token = jwt_helper.build(
          aud: order_sign_url,
          iss: example_client_url,
          jku: "#{example_client_url}/jwks.json",
          encryption_method: 'RS384'
        )

        run(test, cds_jwt_iss: example_client_url,
                  order_sign_custom_response_template: { cards: [instructions_card_template] }.to_json)

        hook_instance = order_sign_hook_request['hookInstance']
        request_with_coverage = order_sign_hook_request.merge(
          'prefetch' => {
            'coverage' => {
              'resourceType' => 'Bundle',
              'type' => 'searchset',
              'entry' => [{ 'resource' => {
                'resourceType' => 'Coverage',
                'payor' => [{ 'reference' => 'Organization/example-payer' }]
              } }]
            }
          }
        )

        header('Authorization', "Bearer #{token}")
        post_json(server_endpoint, request_with_coverage)

        expect(last_response).to be_ok
        expect(payer_request).to have_been_made.once
        tagged_requests = requests_repo.tagged_requests(
          test_session.id,
          ['payer', hook_instance_tag(hook_instance), DaVinciCRDTestKit::DATA_FETCH_TAG]
        )
        expect(tagged_requests.length).to eq(1)
        expect(tagged_requests.first.url).to eq(payer_org_url)
      end

      it 'makes FHIR data-fetch requests when requestedVersion extension overrides path to v201' do
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

        run(test, cds_jwt_iss: example_client_url,
                  order_sign_custom_response_template: { cards: [instructions_card_template] }.to_json)

        request_with_v201_extension = order_sign_hook_request.merge(
          'extension' => { 'davinci-crd.requestedVersion' => '2.0' }
        )
        header('Authorization', "Bearer #{token}")
        post_json(server_endpoint, request_with_v201_extension)

        expect(last_response).to be_ok
        expect(pat_request).to have_been_made.once
        expect(p_request).to have_been_made.once
        expect(cov_request).to have_been_made.once
      end
    end

    it 'does not make FHIR data-fetch requests when requestedVersion extension specifies 2.2' do
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

      run(test, cds_jwt_iss: example_client_url,
                order_sign_custom_response_template: { cards: [instructions_card_template] }.to_json)

      request_with_v221_extension = order_sign_hook_request.merge(
        'extension' => { 'davinci-crd.requestedVersion' => '2.2' }
      )
      header('Authorization', "Bearer #{token}")
      post_json(server_endpoint, request_with_v221_extension)

      expect(last_response).to be_ok
      expect(pat_request).to_not have_been_made
      expect(p_request).to_not have_been_made
      expect(cov_request).to_not have_been_made
    end
  end
end
