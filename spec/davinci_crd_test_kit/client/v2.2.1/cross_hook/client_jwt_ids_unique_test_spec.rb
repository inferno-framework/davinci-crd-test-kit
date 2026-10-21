require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::ClientJwtIdsUniqueTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:test) { described_class }

  def jwt(jti, **claims)
    JWT.encode({ iss: 'https://cds.example.org', aud: 'https://inferno.example.org/cds-services/order-sign-service',
                 exp: 5.minutes.from_now.to_i, iat: Time.now.to_i, jti: }.merge(claims).compact,
               rsa_key, 'RS384', { kid: 'key-1', typ: 'JWT' })
  end

  def create_hook_request(authorization, tags: [DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG])
    repo_create(:request, direction: 'incoming', test_session_id: test_session.id, result:, status: 200,
                          url: 'https://inferno.example.org/cds-services/order-sign-service',
                          request_body: { hook: 'order-sign', hookInstance: SecureRandom.uuid }.to_json,
                          headers: [{ type: 'request', name: 'Authorization', value: authorization }], tags:)
  end

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test]).first.messages
  end

  it 'skips when no hook requests have been received' do
    expect(run(test).result).to eq('skip')
  end

  it 'passes when every JWT has its own jti' do
    create_hook_request("Bearer #{jwt('jti-one')}")
    create_hook_request("Bearer #{jwt('jti-two')}")

    expect(run(test).result).to eq('pass')
    expect(result_messages).to be_empty
  end

  it 'fails when different JWTs share a jti' do
    create_hook_request("Bearer #{jwt('shared-jti')}")
    create_hook_request("Bearer #{jwt('other-jti')}")
    create_hook_request("Bearer #{jwt('shared-jti', iat: 1.minute.ago.to_i)}")

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages.map { |message| [message.type, message.message] }).to contain_exactly(
      ['error', '`jti` "shared-jti" was used by 2 different JWTs, sent on requests 1 and 3. Each hook request ' \
                'must carry a new JWT with its own `jti`.']
    )
  end

  it 'fails when the same JWT is sent on more than one request' do
    token = jwt('reused-jti')
    create_hook_request("Bearer #{token}")
    create_hook_request("Bearer #{token}")

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages.map { |message| [message.type, message.message] }).to contain_exactly(
      ['error', 'The same JWT (`jti` "reused-jti") was sent on requests 1 and 2. Each hook request must carry ' \
                'a new JWT with its own `jti`.']
    )
  end

  it 'reports a jti once when it is both resent and reused in another JWT' do
    token = jwt('shared-jti')
    create_hook_request("Bearer #{token}")
    create_hook_request("Bearer #{jwt('shared-jti', iat: 1.minute.ago.to_i)}")
    create_hook_request("Bearer #{token}")

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to contain_exactly(
      '`jti` "shared-jti" was used by 2 different JWTs, sent on requests 1, 2, and 3. Each hook request must ' \
      'carry a new JWT with its own `jti`.'
    )
  end

  it 'reports each repeated jti separately' do
    create_hook_request("Bearer #{jwt('first-jti')}")
    create_hook_request("Bearer #{jwt('second-jti')}")
    create_hook_request("Bearer #{jwt('first-jti', iat: 1.minute.ago.to_i)}")
    create_hook_request("Bearer #{jwt('second-jti', iat: 1.minute.ago.to_i)}")

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to contain_exactly(
      a_string_including('"first-jti"', 'requests 1 and 3'),
      a_string_including('"second-jti"', 'requests 2 and 4')
    )
  end

  it 'ignores tokens that cannot be decoded or have no jti, and requests without a bearer token' do
    create_hook_request('Bearer not-a-jwt')
    create_hook_request('Bearer not-a-jwt')
    create_hook_request("Bearer #{jwt(nil)}")
    create_hook_request("Bearer #{jwt(nil)}")
    create_hook_request('')

    expect(run(test).result).to eq('pass')
    expect(result_messages).to be_empty
  end

  it 'only considers requests included in the cross hook analysis' do
    create_hook_request("Bearer #{jwt('shared-jti')}")
    create_hook_request("Bearer #{jwt('shared-jti', iat: 1.minute.ago.to_i)}", tags: ['scenario-group'])

    expect(run(test).result).to eq('pass')
  end
end
