RSpec.describe DaVinciCRDTestKit::V221::HookRequestConformanceTest do
  let(:suite_id) { 'crd_client' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:hook_name) { 'order-sign' }
  let(:fhir_server) { 'https://example.com/fhir' }
  let(:access_token) { 'sample_token' }
  let(:request_body) do
    {
      hook: hook_name,
      fhirServer: fhir_server,
      fhirAuthorization: { access_token: },
      context: {
        userId: 'Practitioner/example',
        patientId: 'example',
        draftOrders: { resourceType: 'Bundle', entry: [] }
      }
    }.to_json
  end

  before do
    test.config(options: { hook_name:, crd_interaction_group: hook_name })
    allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
  end

  it 'skips if no requests are found' do
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No #{hook_name} hook requests received/)
  end

  it 'passes and sets outputs when the request is conformant' do
    repo_create(:request,
                test_session_id: test_session.id,
                request_body:,
                result:,
                tags: [hook_name])

    # Mock the logical model validation helper to return true
    # The test includes DaVinciCRDTestKit::RequestsLogicalModelValidation which calls conforms_to_logical_model?
    allow_any_instance_of(test).to receive(:conforms_to_logical_model?).and_return(true)

    result = run(test)

    expect(result.result).to eq('pass')

    # Verify expected outputs are captured
    url_output = result.outputs.find { |o| o['name'] == 'url' }
    auth_output = result.outputs.find { |o| o['name'] == 'smart_auth_info' }

    expect(url_output['value']).to eq(fhir_server)

    auth_json = JSON.parse(auth_output['value'])
    expect(auth_json['access_token']).to eq(access_token)
  end

  it 'fails when the request is not conformant to the logical model' do
    repo_create(:request,
                test_session_id: test_session.id,
                request_body:,
                result:,
                tags: [hook_name])

    # Mock a validation failure
    allow_any_instance_of(test).to receive(:conforms_to_logical_model?) do |instance|
      instance.add_message('error', 'Logical model validation failed')
      false
    end

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('Non-conformant hook request')
  end

  describe 'davinci-crd.configuration extension' do
    let(:results_messages) do
      results_repo.current_results_for_test_session_and_runnables(test_session.id, [test]).first.messages
    end

    before do
      allow_any_instance_of(test).to receive(:conforms_to_logical_model?).and_return(true)
    end

    def create_request_with_configuration(configuration, url: 'https://example.com/cds-services/order-sign-service')
      body = JSON.parse(request_body).merge('extension' => { 'davinci-crd.configuration' => configuration })
      repo_create(:request, test_session_id: test_session.id, request_body: body.to_json, result:, url:,
                            tags: [hook_name])
    end

    it 'passes when every property is an advertised option with the defined type' do
      create_request_with_configuration({ 'coverage-info' => false })
      expect(run(test).result).to eq('pass')
    end

    it 'checks the options of the subset prefetch service when it was invoked' do
      create_request_with_configuration({ 'coverage-info' => true },
                                        url: 'https://example.com/prefetch-subset/cds-services/order-sign-subset')
      expect(run(test).result).to eq('pass')
    end

    it 'fails when a property is not an advertised option' do
      create_request_with_configuration({ 'coverage-info' => false, 'made-up-option' => 7 })
      expect(run(test).result).to eq('fail')
      expect(results_messages.map(&:message)).to include(
        a_string_including('property `made-up-option` is not a configuration option advertised by the ' \
                           'invoked service (advertised: `coverage-info`)')
      )
    end

    it 'fails when a property does not have the type defined for the option' do
      create_request_with_configuration({ 'coverage-info' => 1 })
      expect(run(test).result).to eq('fail')
      expect(results_messages.map(&:message)).to include(
        a_string_including('property `coverage-info` must be a boolean, got 1')
      )
    end

    it 'leaves a configuration that is not an object to the logical model check' do
      create_request_with_configuration('coverage-info=false')
      expect(run(test).result).to eq('pass')
    end
  end
end
