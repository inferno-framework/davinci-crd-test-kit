require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/auth/retrieve_jwks_test'

RSpec.describe DaVinciCRDTestKit::V221::RetrieveJWKSTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:example_client_jwks_url) { "#{example_client_url}/jwks.json" }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:jwks_hash) { JSON.parse(DaVinciCRDTestKit::JWKS.jwks_json) }
  let(:jwk) { jwks_hash['keys'].find { |key| key['alg'] == 'RS384' } }
  let(:token_header) do
    {
      alg: 'RS384',
      kid: jwk['kid'],
      typ: 'JWT',
      jku: example_client_jwks_url
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

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .first
      .messages
      .first
  end

  def session_output(name)
    JSON.parse(session_data_repo.load(test_session_id: test_session.id, name:))
  end

  it 'passes if it receives a valid JWT Authorization header with jku field populated' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json).length).to eq(1)
    expect(session_output(:crd_jwks_keys_json).first).to_not be_nil
  end

  it 'passes if it receives multiple valid JWT Authorization headers with jku field populated' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json, token_header.to_json],
                       cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made.times(2)
    expect(session_output(:crd_jwks_keys_json).length).to eq(2)
  end

  it 'passes and skips nil entries in auth_token_headers_json' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [nil, token_header.to_json].to_json,
                       cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made.once
    expect(session_output(:crd_jwks_keys_json)).to eq([nil, JSON.parse(jwks_hash.to_json)['keys'].to_json])
  end

  it 'fails if it receives at least 1 invalid JWT Authorization headers' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash.to_json).then
      .to_return(status: 404, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json, token_header.to_json],
                       cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message)
      .to include('(Request 2) Unexpected response status: expected 200, but received')
    expect(jwks_request).to have_been_made.times(2)
    expect(session_output(:crd_jwks_keys_json).length).to eq(2)
    expect(session_output(:crd_jwks_keys_json).last).to be_nil
  end

  it 'fails, rather than errors, and checks the other requests if retrieving the jku times out' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_raise(Net::ReadTimeout).then
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json, token_header.to_json],
                       cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message)
      .to eq("(Request 1) Timed out waiting for a response from JWKS URL `#{example_client_jwks_url}`.")
    expect(jwks_request).to have_been_made.times(2)
    expect(session_output(:crd_jwks_keys_json).first).to be_nil
    expect(session_output(:crd_jwks_keys_json).last).to_not be_nil
  end

  it 'limits how long it waits for the jku' do
    jwks_request = stub_request(:get, example_client_jwks_url).to_return(status: 200, body: jwks_hash.to_json)
    allow(Faraday).to receive(:new).and_call_original

    run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(Faraday).to have_received(:new).with(request: { open_timeout: 10, timeout: 10 })
    expect(jwks_request).to have_been_made.once
  end

  it 'reports a TLS handshake that times out as a timeout' do
    # Net::HTTP raises this without the 'Failed to open TCP' message, so Inferno passes it through
    stub_request(:get, example_client_jwks_url).to_raise(Net::OpenTimeout.new('execution expired'))

    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message)
      .to eq("(Request 1) Timed out waiting for a response from JWKS URL `#{example_client_jwks_url}`.")
  end

  context 'when the connection to the jku cannot be opened' do
    # Net::HTTP gives a connection failure this message, which Inferno looks for
    let(:open_failure_message) { 'Failed to open TCP connection to cds.example.org:443' }

    it 'reports a timeout and checks the other requests if opening the connection times out' do
      jwks_request = stub_request(:get, example_client_jwks_url)
        .to_raise(Net::OpenTimeout.new("#{open_failure_message} (execution expired)")).then
        .to_return(status: 200, body: jwks_hash.to_json)

      result = run(test, auth_token_headers_json: [token_header.to_json, token_header.to_json],
                         cds_jwk_set: example_client_jwks_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message)
        .to eq("(Request 1) Timed out waiting for a response from JWKS URL `#{example_client_jwks_url}`.")
      expect(jwks_request).to have_been_made.times(2)
      expect(session_output(:crd_jwks_keys_json).last).to_not be_nil
    end
  end

  it 'passes if it receives a valid jwk_set input' do
    token_header_no_jku = token_header.except(:jku)

    result = run(test, auth_token_headers_json: [token_header_no_jku.to_json], cds_jwk_set: jwks_hash.to_json)
    expect(result.result).to eq('pass')
  end

  it 'passes if it receives a valid jwk_set input provided as a url and no jku header is present' do
    token_header_no_jku = token_header.except(:jku)
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header_no_jku.to_json],
                       cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json).first).to_not be_nil
  end

  it 'fails if the jwk_set url input returns a non 200 response and no jku header is present' do
    token_header_no_jku = token_header.except(:jku)
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 404, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header_no_jku.to_json],
                       cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to include('Unexpected response status: expected 200, but received')
    expect(jwks_request).to have_been_made
  end

  it 'skips and outputs an empty key list when no token headers were produced' do
    result = run(test)

    expect(result.result).to eq('skip')
    expect(result.result_message).to eq('No Authorization tokens produced from the previous test.')
    expect(session_output(:crd_jwks_keys_json)).to eq([])
  end

  it 'skips if jku field is not set, and no jwk_set is provided' do
    token_header_no_jku = token_header.except(:jku)

    result = run(test, auth_token_headers_json: [token_header_no_jku.to_json])
    expect(result.result).to eq('skip')
    expect(result.result_message)
      .to include("the CRD client's JWKS must be provided in the **CRD JSON Web Key Set (JWKS)** input")
  end

  it 'does not skip when all headers have jku even if no jwk_set is provided' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json])
    expect(result.result).to eq('pass')
    expect(jwks_request).to have_been_made
  end

  it 'fails if it receives non 200 response' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 404, body: jwks_hash.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to include('Unexpected response status: expected 200, but received')
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json)).to eq([nil])
  end

  it 'fails if jwks returned is not a valid json' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: nil)

    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to include('Fetched jku url response contains invalid JSON.')
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json)).to eq([nil])
  end

  it 'fails if jwks returned is not an array' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwk.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to include('JWKS `keys` field must be an array')
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json)).to eq([nil])
  end

  it 'fails if jwks returned has no keys' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash_no_keys.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to include('The JWK set returned contains no public keys')
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json)).to eq([nil])
  end

  it 'fails if jwks returned does not contain kid field' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash_no_kids.to_json)

    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message)
      .to include('`kid` field must be present in each key if JWKS contains multiple keys')
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json)).to eq([nil])
  end

  it 'fails if jwks returned contains duplicate kid fields' do
    jwks_request = stub_request(:get, example_client_jwks_url)
      .to_return(status: 200, body: jwks_hash_dup_kids.to_json)
    result = run(test, auth_token_headers_json: [token_header.to_json], cds_jwk_set: example_client_jwks_url)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to include("`kid` must be unique within the CRD client's JWK Set.")
    expect(jwks_request).to have_been_made
    expect(session_output(:crd_jwks_keys_json)).to eq([nil])
  end
end
