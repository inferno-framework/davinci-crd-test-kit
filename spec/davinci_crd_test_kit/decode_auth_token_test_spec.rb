require_relative '../../lib/davinci_crd_test_kit/client_tests/decode_auth_token_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::DecodeAuthTokenTest do
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:test) { Inferno::Repositories::Tests.new.find('crd_decode_auth_token') }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

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
      name: 'hook_request',
      direction: 'incoming',
      url: 'http://example.com/custom/crd_client/cds-services/appointment-book-service',
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:
    )
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

  it 'skips if no authorization header included in request' do
    create_appointment_hook_request(body: appointment_book_hook_request, auth_header: nil)

    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to eq('Request does not include an Authorization header')
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
    expect(result.result_message).to eq('Authorization token must be a JWT presented as a `Bearer` token')
  end
end
