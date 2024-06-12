require_relative '../../lib/davinci_crd_test_kit/client_tests/retrieve_jwks_test'

RSpec.describe DaVinciCRDTestKit::RetrieveJWKSTest do
  let(:test) { Inferno::Repositories::Tests.new.find('crd_retrieve_jwks') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_retrieve_jwks') }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:jwks_hash) { JSON.parse(DaVinciCRDTestKit::JWKS.jwks_json) }
  let(:jwk) { jwks_hash['keys'].find { |key| key['alg'] == 'RS384' } }
  let(:token_header) do
    {
      alg: 'RS384',
      kid: jwk['kid'],
      typ: 'JWT',
      jku: "#{example_client_url}/jwks.json"
    }
  end

  let(:jwks_hash_no_keys) { { keys: [] } }
  let(:invalid_jwks_hash) do
    {
      keys: jwks_hash['keys'].each { |key| key['kid'] = 1234 }
    }
  end
  let(:jwks_hash_dup_kids) do
    {
      keys: jwks_hash['keys'].each { |key| key['kid'] = jwk['kid'] }
    }
  end
  let(:jwks_hash_no_kids) { { keys: jwks_hash['keys'].map { |key| key.except('kid') } } }

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

  it 'passes if it receives a valid JWT Authorization header with jku field populated' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_tokens_header_json: [token_header.to_json])
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made
  end

  it 'passes if it receives multiple valid JWT Authorization headers with jku field populated' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_tokens_header_json: [token_header.to_json, token_header.to_json])
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made.times(2)
  end

  it 'fails if it receives at least 1 invalid JWT Authorization headers' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash.to_json).then
      .to_return(status: 404, body: jwks_hash.to_json)

    result = run(test, auth_tokens_header_json: [token_header.to_json, token_header.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(
      /Request 2: Unexpected response status: expected 200, but received/
    )
    expect(jwks_request).to have_been_made.times(2)
  end

  it 'passes if it receives a valid jwk_set input' do
    token_header_no_jku = token_header.except(:jku)

    result = run(test, auth_tokens_header_json: [token_header_no_jku.to_json], jwk_set: jwks_hash.to_json)
    expect(result.result).to eq('pass')
  end

  it 'skips if jku field is not set, and no jwk_set is provided' do
    token_header_no_jku = token_header.except(:jku)

    result = run(test, auth_tokens_header_json: [token_header_no_jku.to_json])
    expect(result.result).to eq('skip')
    expect(result.result_message).to match("JWK Set must be inputted if Client's JWK Set is not available")
  end

  it 'fails if it receives non 200 response' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 404, body: jwks_hash.to_json)

    result = run(test, auth_tokens_header_json: [token_header.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Unexpected response status: expected 200, but received/)
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned is not a valid json' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: nil)

    result = run(test, auth_tokens_header_json: [token_header.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/Invalid JSON./)
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned is not an array' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwk.to_json)

    result = run(test, auth_tokens_header_json: [token_header.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/JWKS `keys` field must be an array/)
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned has no keys' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash_no_keys.to_json)

    result = run(test, auth_tokens_header_json: [token_header.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/The JWK set returned contains no public keys/)
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned does not contain kid field' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash_no_kids.to_json)

    result = run(test, auth_tokens_header_json: [token_header.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(
      /`kid` field must be present in each key if JWKS contains multiple keys/
    )
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned contains duplicate kid fields' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash_dup_kids.to_json)
    result = run(test, auth_tokens_header_json: [token_header.to_json])
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/`kid` must be unique within the client's JWK Set./)
    expect(jwks_request).to have_been_made
  end
end
