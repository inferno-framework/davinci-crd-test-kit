require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_required_fields_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestRequiredFieldsTest do
  let(:suite_id) { 'crd_client' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { described_class }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }

  let(:appointment_book_hook_request) do
    File.read(File.join(
                __dir__, '..', 'fixtures', 'appointment_book_hook_request.json'
              ))
  end

  let(:appointment_book_hook_request_hash) { JSON.parse(appointment_book_hook_request) }

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
      name: 'appointment_book',
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags: ['appointment-book']
    )
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  describe 'Appointment Book Hook Request Required Fields' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestRequiredFieldsTest) do
        config(
          options: { hook_path: '/cds-services/appointment-book-service', hook_name: 'appointment-book' }
        )
      end
    end

    it 'passes if valid hook request with all required fields included in request' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: "Bearer #{token}")
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes if multiple valid hook request with all required fields included in request' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: "Bearer #{token}")
      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: "Bearer #{token}")
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'fails if one of multiple hook requests are invalid' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: "Bearer #{token}")
      invalid_hook_request = appointment_book_hook_request_hash.except('context')
      create_appointment_hook_request(body: invalid_hook_request, auth_header: "Bearer #{token}")
      result = run(test)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(
        /Request 2: Hook request did not contain required field: `context`/
      )
    end

    it 'skips if no appointment-book request can be found' do
      allow(test).to receive(:suite).and_return(suite)

      result = run(test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No appointment-book requests were made in a previous test as expected.')
    end

    it 'fails if hook request body is not a valid json' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(body: 'request_body', auth_header: "Bearer #{token}")

      result = run(test)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Request 1: Invalid JSON./)
    end

    it 'fails if hook request is missing a required field' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      invalid_hook_request = appointment_book_hook_request_hash.except('context')

      create_appointment_hook_request(body: invalid_hook_request, auth_header: "Bearer #{token}")

      result = run(test)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(
        /Request 1: Hook request did not contain required field: `context`/
      )
    end

    it 'fails if hook request contains fhirAuthorization field but not fhirServer field' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      invalid_hook_request = appointment_book_hook_request_hash.except('fhirServer')

      create_appointment_hook_request(body: invalid_hook_request, auth_header: "Bearer #{token}")

      result = run(test)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(
        /Missing `fhirServer` field: If `fhirAuthorization` is provided, this field is/
      )
    end
  end
end
