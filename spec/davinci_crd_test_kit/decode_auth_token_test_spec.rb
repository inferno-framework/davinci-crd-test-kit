require_relative '../../lib/davinci_crd_test_kit/client_tests/decode_auth_token_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::DecodeAuthTokenTest do
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_decode_auth_token') }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }

  let(:appointment_book_hook_request) do
    File.read(File.join(
                __dir__, '..', 'fixtures', 'appointment_book_hook_request.json'
              ))
  end

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

  describe 'Appointment Book Decode Auth Token Test' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::DecodeAuthTokenTest) do
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
        /Request 2: Authorization token must be a JWT presented as a `Bearer` token/
      )
    end

    it 'skips if no authorization header included in request' do
      create_appointment_hook_request(body: appointment_book_hook_request, auth_header: nil)

      result = run(test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No appointment-book requests contained the Authorization header')
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
    end
  end
end
