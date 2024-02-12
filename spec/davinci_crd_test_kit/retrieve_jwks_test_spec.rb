require_relative '../../lib/davinci_crd_test_kit/client_tests/retrieve_jwks_test'

RSpec.describe DaVinciCRDTestKit::RetrieveJWKSTest do
  let(:test) { Inferno::Repositories::Tests.new.find('crd_retrieve_jwks') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }

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

  it 'passes if it receives a valid JWT Authorization header with jku field populated' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_token_header_json: token_header.to_json)
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made
  end

  it 'passes if it receives a valid jwk_set input' do
    token_header_no_jku = token_header.except(:jku)

    result = run(test, auth_token_header_json: token_header_no_jku.to_json, jwk_set: jwks_hash.to_json)
    expect(result.result).to eq('pass')
  end

  it 'skips if jku field is not set, and no jwk_set is provided' do
    token_header_no_jku = token_header.except(:jku)

    result = run(test, auth_token_header_json: token_header_no_jku.to_json)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match("JWK Set must be inputted if Client's JWK Set is not available")
  end

  it 'fails if it receives non 200 response' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 404, body: jwks_hash.to_json)

    result = run(test, auth_token_header_json: token_header.to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('Unexpected response status: expected 200, but received 404')
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned is not a valid json' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: nil)

    result = run(test, auth_token_header_json: token_header.to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('Invalid JSON. ')
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned is not an array' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwk.to_json)

    result = run(test, auth_token_header_json: token_header.to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('JWKS `keys` field must be an array')
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned has no keys' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash_no_keys.to_json)

    result = run(test, auth_token_header_json: token_header.to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('The JWK set returned contains no public keys')
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned does not contain kid field' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash_no_kids.to_json)

    result = run(test, auth_token_header_json: token_header.to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('`kid` field must be present in each key if JWKS contains multiple keys')
    expect(jwks_request).to have_been_made
  end

  it 'fails if jwks returned contains duplicate kid fields' do
    jwks_request = stub_request(:get, "#{example_client_url}/jwks.json")
      .to_return(status: 200, body: jwks_hash_dup_kids.to_json)
    result = run(test, auth_token_header_json: token_header.to_json)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq("`kid` must be unique within the client' JWK Set.")
    expect(jwks_request).to have_been_made
  end
end
