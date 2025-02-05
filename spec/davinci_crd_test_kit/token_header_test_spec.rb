require_relative '../../lib/davinci_crd_test_kit/client_tests/token_header_test'

RSpec.describe DaVinciCRDTestKit::TokenHeaderTest do
  let(:test) { Inferno::Repositories::Tests.new.find('crd_token_header') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:suite_id) { 'crd_client' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_token_header') }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:jwks_hash_keys) { JSON.parse(DaVinciCRDTestKit::JWKS.jwks_json)['keys'] }
  let(:jwk) { jwks_hash_keys.find { |key| key['alg'] == 'RS384' } }

  let(:token_header) do
    {
      alg: 'RS384',
      kid: jwk['kid'],
      typ: 'JWT',
      jku: "#{example_client_url}/jwks.json"
    }
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

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  it 'passes if it receives a valid JWT Authorization header' do
    result = run(test, auth_token_headers_json: [token_header.to_json], crd_jwks_keys_json: [jwks_hash_keys.to_json])
    expect(result.result).to eq('pass')
  end

  it 'passes if it receives multiple requests with valid JWT Authorization headers' do
    result = run(test, auth_token_headers_json: [token_header.to_json, token_header.to_json],
                       crd_jwks_keys_json: [jwks_hash_keys.to_json, jwks_hash_keys.to_json])
    expect(result.result).to eq('pass')
  end

  it 'fails if it receives at least 1 request with invalid JWT Authorization headers' do
    invalid_token_header = token_header.except(:alg)
    result = run(test, auth_token_headers_json: [token_header.to_json, invalid_token_header.to_json],
                       crd_jwks_keys_json: [jwks_hash_keys.to_json, jwks_hash_keys.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Request 2: Token header must have the `alg` field/)
  end

  it 'fails if it receives a JWT header without the `alg` field' do
    invalid_token_header = token_header.except(:alg)

    result = run(test, auth_token_headers_json: [invalid_token_header.to_json],
                       crd_jwks_keys_json: [jwks_hash_keys.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Token header must have the `alg` field/)
  end

  it 'fails if it receives a JWT header without the `typ` field' do
    invalid_token_header = token_header.except(:typ)

    result = run(test, auth_token_headers_json: [invalid_token_header.to_json],
                       crd_jwks_keys_json: [jwks_hash_keys.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Token header must have the `typ` field/)
  end

  it 'fails if it receives a JWT header with the `typ` field not set to JWT' do
    token_header[:typ] = 'Bearer'

    result = run(test, auth_token_headers_json: [token_header.to_json], crd_jwks_keys_json: [jwks_hash_keys.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Token header `typ` field must be set to 'JWT', instead was/)
  end

  it 'fails if it receives a JWT header without the `kid` field' do
    invalid_token_header = token_header.except(:kid)

    result = run(test, auth_token_headers_json: [invalid_token_header.to_json],
                       crd_jwks_keys_json: [jwks_hash_keys.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Token header must have the `kid` field/)
  end

  it 'fails if it receives a JWT header that does not contain a kid found in the jwks' do
    token_header[:kid] = '12345'

    result = run(test, auth_token_headers_json: [token_header.to_json], crd_jwks_keys_json: [jwks_hash_keys.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/JWKS did not contain a public key with an id of `12345`/)
  end
end
