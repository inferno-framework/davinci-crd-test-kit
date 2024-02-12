require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_optional_fields_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestOptionalFieldsTest do
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:test) { Inferno::Repositories::Tests.new.find('crd_hook_request_optional_fields') }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:client_fhir_server_output) { 'https://example/r4' }
  let(:client_access_token_output) { 'SAMPLE_TOKEN' }

  let(:appointment_book_hook_request) do
    File.read(File.join(
                __dir__, '..', 'fixtures', 'appointment_book_hook_request.json'
              ))
  end
  let(:appointment_book_hook_request_hash) { JSON.parse(appointment_book_hook_request) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  def create_appointment_hook_request(url: appointment_book_url, body: nil, status: 200, headers: nil, auth_header: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: auth_header
      }
    ]
    repo_create(
      :request,
      name: 'hook_request',
      direction: 'incoming',
      url:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:
    )
  end

  it 'passes without all optional fields and produces output if it contains `fhirAuthorization` field' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    create_appointment_hook_request(body: appointment_book_hook_request, auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('pass')

    outputs_hash = JSON.parse(result.output_json)

    fhir_server_output = outputs_hash.any? do |output|
      output['name'] == 'client_fhir_server' && output['value'] == client_fhir_server_output
    end

    access_token_output = outputs_hash.any? do |output|
      output['name'] == 'client_access_token' && output['value'] == client_access_token_output
    end

    expect(fhir_server_output).to be true
    expect(access_token_output).to be true
  end

  it 'passes and produces fhir server but not bearer token output when no `fhirAuthorization` field' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    hook_request_no_fhir_auth = appointment_book_hook_request_hash.except('fhirAuthorization')

    create_appointment_hook_request(body: hook_request_no_fhir_auth, auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('pass')

    outputs_hash = JSON.parse(result.output_json)

    fhir_server_output = outputs_hash.any? do |output|
      output['name'] == 'client_fhir_server' && output['value'] == client_fhir_server_output
    end

    access_token_output = outputs_hash.any? do |output|
      output['name'] == 'client_access_token' && output['value'].blank?
    end

    expect(fhir_server_output).to be true
    expect(access_token_output).to be true
  end

  it 'passes and produces no output when no `fhirServer` or `fhirAuthorization` field' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    hook_request_no_fhir_auth = appointment_book_hook_request_hash
      .except('fhirAuthorization')
      .except('fhirServer')

    create_appointment_hook_request(body: hook_request_no_fhir_auth, auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('pass')

    outputs_hash = JSON.parse(result.output_json)

    fhir_server_output = outputs_hash.any? do |output|
      output['name'] == 'client_fhir_server' && output['value'].blank?
    end

    access_token_output = outputs_hash.any? do |output|
      output['name'] == 'client_access_token' && output['value'].blank?
    end

    expect(fhir_server_output).to be true
    expect(access_token_output).to be true
  end

  it 'skips if no appointment-book request can be found' do
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to eq('Request `hook_request` was not made in a previous test as expected.')
  end

  it 'fails if hook request body is not a valid json' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    create_appointment_hook_request(body: 'request_body', auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('Invalid JSON. ')
  end

  it 'fails if an optional field is not of the correct type' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    invalid_hook_request = appointment_book_hook_request_hash
    invalid_hook_request['prefetch'] = 'Prefetch String'

    create_appointment_hook_request(body: invalid_hook_request, auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('Hook request field prefetch is not of type Hash')
  end

  it 'fails if hook request missing required field in fhirAuthorization' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    invalid_hook_request = appointment_book_hook_request_hash
    invalid_hook_request['fhirAuthorization'] = invalid_hook_request['fhirAuthorization'].except('access_token')

    create_appointment_hook_request(body: invalid_hook_request, auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('`fhirAuthorization` did not contain required field: `access_token`')
  end

  it 'fails if hook request fhirAuthorization `token_type` is not `Bearer`' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    invalid_hook_request = appointment_book_hook_request_hash
    invalid_hook_request['fhirAuthorization']['token_type'] = 'Token'

    create_appointment_hook_request(body: invalid_hook_request, auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq("`fhirAuthorization` `token_type` field is not set to 'Bearer'")
  end

  it 'passes if patient scope included but `patient` field is omitted' do
    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    patient_scope_hook_request = appointment_book_hook_request_hash
    patient_scope_hook_request['fhirAuthorization']['scope'] += ' patient/Patient.read'

    create_appointment_hook_request(body: patient_scope_hook_request, auth_header: "Bearer #{token}")

    result = run(test)
    expect(result.result).to eq('pass')
  end
end
