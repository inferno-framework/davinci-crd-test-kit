require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.0.1/auth/token_payload_test'
require_relative '../../../../../lib/davinci_crd_test_kit/server/jwt_helper'

RSpec.describe DaVinciCRDTestKit::V201::TokenPayloadTest do
  let(:suite_id) { 'crd_client' }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_v201_token_payload') }
  # one result for all the hook requests, as when they arrive during a single run of the wait test
  let(:hook_request_result) { repo_create(:result, test_session_id: test_session.id) }

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

  def create_appointment_hook_request(created_at:)
    repo_create(
      :request,
      name: 'appointment_book',
      direction: 'incoming',
      url: appointment_book_url,
      test_session_id: test_session.id,
      result: hook_request_result,
      status: 200,
      tags: ['appointment-book'],
      created_at:
    )
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  describe 'CRD Appointment Book Token Payload' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::V201::TokenPayloadTest) do
        config(
          options: { hook_name: 'appointment-book', hook_path: '/cds-services/appointment-book-service' }
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

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], cds_jwt_iss: example_client_url)
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
                         cds_jwt_iss: example_client_url)
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
                         cds_jwt_iss: example_client_url)
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

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], cds_jwt_iss: example_client_url)
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

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], cds_jwt_iss: example_client_url)
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

      payload, header = JWT.decode(token, nil, false)
      token_invalid_key = JWT.encode payload, OpenSSL::PKey::RSA.new(2048), 'RS384', header

      result = run(test, auth_tokens: [token_invalid_key], auth_tokens_jwk_json: [jwk.to_json],
                         cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to include('Token validation error: Signature verification failed')
    end

    it 'passes when JWK has no alg field but JWT header specifies alg' do
      allow(test).to receive(:suite).and_return(suite)

      token = JWT.encode token_payload, rsa_key, 'RS384', token_header

      result = run(test,
                   auth_tokens: [token],
                   auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
                   cds_jwt_iss: example_client_url)
      expect(result.result).to eq('pass')
    end

    it 'fails when JWK omits alg and the JWT header declares a fake algorithm' do
      allow(test).to receive(:suite).and_return(suite)

      # No alg on the JWK -> falls back to the (fake) header alg, which JWT.decode rejects.
      token = JWT.encode token_payload, rsa_key, 'RS384', token_header.merge(alg: 'RS111')

      result = run(test,
                   auth_tokens: [token],
                   auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
                   cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to include('Token validation error')
    end

    it 'fails if the token uses an unsupported algorithm such as HS256' do
      allow(test).to receive(:suite).and_return(suite)

      hs256_header = token_header.merge(alg: 'HS256')
      token = JWT.encode token_payload, 'shared_secret', 'HS256', hs256_header

      result = run(test,
                   auth_tokens: [token],
                   auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
                   cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to include('CDS Hooks prohibits')
    end

    it 'fails if the token uses the `none` algorithm' do
      allow(test).to receive(:suite).and_return(suite)

      none_header = { alg: 'none', kid: rsa_jwk['kid'], typ: 'JWT' }
      token = JWT.encode token_payload, nil, 'none', none_header

      result = run(test,
                   auth_tokens: [token],
                   auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
                   cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to include('CDS Hooks prohibits')
    end

    it 'reports every problem at once rather than stopping at the first failed check' do
      allow(test).to receive(:suite).and_return(suite)

      # One token with two independent problems: a disallowed alg AND a missing `exp` claim.
      token = JWT.encode token_payload.except(:exp), 'shared_secret', 'HS256', token_header.merge(alg: 'HS256')

      result = run(test,
                   auth_tokens: [token],
                   auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
                   cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')

      messages = results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
        .first.messages.map(&:message)
      expect(messages).to include(a_string_matching(/CDS Hooks prohibits/))
      expect(messages).to include(a_string_matching(/missing required claims: `exp`/))
    end

    it 'fails if it receives a JWT Authorization header with missing claims' do
      allow(test).to receive(:suite).and_return(suite)

      rsa_jwk_hash['alg'] = 'RS384'
      invalid_payload = token_payload.except(:exp).except(:exp)

      token_invalid_key = JWT.encode invalid_payload, rsa_key, 'RS384', token_header

      result = run(test,
                   auth_tokens: [token_invalid_key],
                   auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
                   cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to include('JWT payload missing required claims: `exp`')
    end

    it 'passes when exp has since elapsed but was still valid when the request was received' do
      allow(test).to receive(:suite).and_return(suite)
      create_appointment_hook_request(created_at: 5.minutes.ago)

      # Expired 2 minutes ago by wall-clock time, but was still unexpired when the request came in.
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384',
        exp: 2.minutes.ago.to_i
      )

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], cds_jwt_iss: example_client_url)
      expect(result.result).to eq('pass')
    end

    it 'fails when the token was already expired when the request was received' do
      allow(test).to receive(:suite).and_return(suite)
      create_appointment_hook_request(created_at: 5.minutes.ago)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384',
        exp: 10.minutes.ago.to_i
      )

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to include('Token had expired when the request was received')
    end

    it 'judges each token against when its own request was received' do
      allow(test).to receive(:suite).and_return(suite)
      create_appointment_hook_request(created_at: 10.minutes.ago)
      create_appointment_hook_request(created_at: 2.minutes.ago)

      # Valid when the first request came in 10 minutes ago, but expired before the second one 2 minutes ago.
      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384',
        exp: 5.minutes.ago.to_i
      )

      result = run(test, auth_tokens: [token, token], auth_tokens_jwk_json: [jwk.to_json, jwk.to_json],
                         cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')

      messages = results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
        .first.messages.map(&:message)
      expect(messages.length).to eq(1)
      expect(messages.first).to match(/\ARequest 2: Token had expired when the request was received/)
    end

    it 'fails when exp has passed and no request was recorded' do
      allow(test).to receive(:suite).and_return(suite)

      token = jwt_helper.build(
        aud: appointment_book_url,
        iss: example_client_url,
        jku: "#{example_client_url}/jwks.json",
        encryption_method: 'RS384',
        exp: 2.minutes.ago.to_i
      )

      result = run(test, auth_tokens: [token], auth_tokens_jwk_json: [jwk.to_json], cds_jwt_iss: example_client_url)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to include('Token had expired when the request was received')
    end

    describe 'claim types' do
      # JWT.encode refuses non-numeric `exp` and `iat`, so tokens with them are signed as given
      def sign_as_given(payload)
        header = Base64.urlsafe_encode64(token_header.merge(alg: 'RS384').to_json, padding: false)
        body = Base64.urlsafe_encode64(payload.to_json, padding: false)
        signature = rsa_key.sign(OpenSSL::Digest.new('SHA384'), "#{header}.#{body}")
        "#{header}.#{body}.#{Base64.urlsafe_encode64(signature, padding: false)}"
      end

      def run_with_payload(payload)
        allow(test).to receive(:suite).and_return(suite)
        rsa_jwk_hash['alg'] = 'RS384'
        run(test,
            auth_tokens: [sign_as_given(payload)],
            auth_tokens_jwk_json: [rsa_jwk_hash.to_json],
            cds_jwt_iss: example_client_url)
      end

      def messages
        results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
          .first.messages.map(&:message)
      end

      it 'passes when every claim has the required type, including an array `aud`' do
        result = run_with_payload(token_payload.merge(aud: [appointment_book_url]))

        expect(result.result).to eq('pass')
      end

      it 'fails when `exp` is a numeric string, which JWT.decode accepts' do
        result = run_with_payload(token_payload.merge(exp: 5.minutes.from_now.to_i.to_s))

        expect(result.result).to eq('fail')
        expect(messages).to include(a_string_including('claim `exp` must be a number, got "'))
      end

      it 'fails when `iat` is not a number' do
        result = run_with_payload(token_payload.merge(iat: 'yesterday'))

        expect(result.result).to eq('fail')
        expect(messages).to include(a_string_including('claim `iat` must be a number, got "yesterday"'))
      end

      it 'fails when `jti` is not a string' do
        result = run_with_payload(token_payload.merge(jti: 12_345))

        expect(result.result).to eq('fail')
        expect(messages).to include(a_string_including('claim `jti` must be a string, got 12345'))
      end

      it 'fails when `aud` is an array containing a non-string' do
        result = run_with_payload(token_payload.merge(aud: [appointment_book_url, 7]))

        expect(result.result).to eq('fail')
        expect(messages).to include(
          a_string_including('claim `aud` must be a string or an array of strings')
        )
      end

      it 'reports every wrongly typed claim' do
        result = run_with_payload(token_payload.merge(iat: 'yesterday', jti: 12_345))

        expect(result.result).to eq('fail')
        expect(messages).to include(a_string_including('claim `iat`'), a_string_including('claim `jti`'))
      end
    end
  end
end
