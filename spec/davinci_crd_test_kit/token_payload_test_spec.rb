require_relative '../../lib/davinci_crd_test_kit/client_tests/token_payload_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::TokenPayloadTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_token_payload') }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }

  let(:jwks_hash) { JSON.parse(DaVinciCRDTestKit::JWKS.jwks_json) }
  let(:jwk) { jwks_hash['keys'].find { |key| key['alg'] == 'RS384' } }

  let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:rsa_jwk) { JWT::JWK.new(rsa_key) }
  let(:rsa_jwk_hash) { JSON.parse(rsa_jwk.to_json)['parameters'] }

  let(:token_header) do
    {
      alg: 'RS384',
      kid: rsa_jwk['kid'],
      typ: 'JWT',
      jku: "#{example_client_url}/jwks.json"
    }
  end

  let(:token_payload) do
    {
      aud: appointment_book_url,
      iss: example_client_url,
      iat: Time.now.to_i,
      exp: 5.minutes.from_now.to_i,
      jti: SecureRandom.hex(32)
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

  describe 'CRD Appointment Book Token Payload' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::TokenPayloadTest) do
        config(
          options: { hook_path: '/cds-services/appointment-book-service' }
        )
      end
    end

    it 'passes if it receives a valid JWT payload' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], iss: example_client_url)
      expect(result.result).to eq('pass')
    end

    it 'passes if it receives multiple valid JWT payloads' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      result = run(test, auth_tokens: [token, token], auth_tokens_jwk_json: [jwk.to_json, jwk.to_json],
                         iss: example_client_url)
      expect(result.result).to eq('pass')
    end

    it 'fails if it receives at least 1 invalid JWT payload' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      invalid_token = jwt_helper.build(
        aud: appointment_book_url,
        iss: 'incorrect_iss.com',
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      result = run(test, auth_tokens: [token, invalid_token], auth_tokens_jwk_json: [jwk.to_json, jwk.to_json],
                         iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Request 2: Token validation error: Invalid issuer./)
    end

    it 'fails if it receives a JWT payload with an invalid `iss` field' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: 'incorrect_iss.com',
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Token validation error: Invalid issuer./)
    end

    it 'fails if it receives a JWT payload with an invalid `aud` field' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: 'incorrect_aud.com',
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(
        'Token validation error: Invalid audience. Expected http://localhost:4567/custom/crd_client/cds-services/appointment-book-service'
      )
    end

    it 'fails if it receives a JWT Authorization header with invalid signature' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384'
      )

      payload, header = jwt_helper.decode_jwt(token, jwks_hash)
      token_invalid_key = JWT.encode payload, OpenSSL::PKey::RSA.new(2048), 'RS384', header

      result = run(test, auth_tokens: [token_invalid_key], auth_tokens_jwk_json: [jwk.to_json], iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/Token validation error: Signature verification failed/)
    end

    it 'fails if it receives a JWT Authorization header with missing claims' do
      allow(test).to receive(:suite).and_return(suite)

      rsa_jwk_hash['alg'] = 'RS384'
      invalid_payload = token_payload.except(:exp).except(:exp)

      token_invalid_key = JWT.encode invalid_payload, rsa_key, 'RS384', token_header

      result = run(test,
                   auth_tokens: [token_invalid_key],
                   auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
                   iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/JWT payload missing required claims: `exp`/)
    end
  end
end
