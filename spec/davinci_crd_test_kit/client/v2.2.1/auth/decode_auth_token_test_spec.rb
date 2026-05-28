require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/auth/decode_auth_token_test'
require_relative '../../../../../lib/davinci_crd_test_kit/server/jwt_helper'

RSpec.describe DaVinciCRDTestKit::V221::DecodeAuthTokenTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_v221_decode_auth_token') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }

  let(:appointment_book_hook_request) do
    File.read(File.join(
                __dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'
              ))
  end

  def create_appointment_hook_request(body: nil, status: 200, headers: nil, auth_header: nil)
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
      url: 'http://example.com/custom/crd_client/cds-services/appointment-book-service',
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      result:,
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

  def session_output(name)
    JSON.parse(session_data_repo.load(test_session_id: test_session.id, name:))
  end

  describe 'Appointment Book Decode Auth Token Test' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::V221::DecodeAuthTokenTest) do
        config(
          options: { hook_name: 'appointment-book' }
        )
      end
    end

    it 'passes if valid authorization header included in request' do
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

    it 'passes if multiple requests have valid authorization headers' do
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

    it 'fails if one of many requests has an invalid authorization headers' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: "Bearer #{token}")
      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: token)

      result = run(test)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(
        /\(Request 2\) Authorization token must be a JWT presented as a `Bearer` token/
      )
      expect(session_output(:auth_tokens)).to eq([token, nil])
      expect(session_output(:auth_token_payloads_json).length).to eq(2)
      expect(session_output(:auth_token_payloads_json).last).to be_nil
      expect(session_output(:auth_token_headers_json).length).to eq(2)
      expect(session_output(:auth_token_headers_json).last).to be_nil
    end

    it 'fails if authorization header does not present the JWT as a `Bearer` token' do
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: token)

      result = run(test)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Authorization token must be a JWT presented as a `Bearer` token/)
      expect(session_output(:auth_tokens)).to eq([nil])
      expect(session_output(:auth_token_payloads_json)).to eq([nil])
      expect(session_output(:auth_token_headers_json)).to eq([nil])
    end

    it 'fails if one request has a malformed JWT and outputs nil for payload and header entries' do
      create_appointment_hook_request(body: appointment_book_hook_request,
                                      auth_header: 'Bearer not.a.valid.jwt')

      result = run(test)
      expect(result.result).to eq('fail')
      expect(session_output(:auth_tokens)).to eq(['not.a.valid.jwt'])
      expect(session_output(:auth_token_payloads_json)).to eq([nil])
      expect(session_output(:auth_token_headers_json)).to eq([nil])
    end
  end
end
