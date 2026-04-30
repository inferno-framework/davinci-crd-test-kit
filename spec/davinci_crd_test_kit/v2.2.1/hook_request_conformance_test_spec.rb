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
      fhirAuthorization: { access_token: }
    }.to_json
  end

  before do
    # Set the configuration options that the test expects
    test.config(options: { hook_name: })
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
    expect(result.result_message).to match(/Non-conformant hook requests detected/)
  end
end
