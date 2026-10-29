require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::ClientJwtIdsUniqueTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:test) { described_class }
  let(:hook_tags) { [DaVinciCRDTestKit::ORDER_SIGN_TAG, DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG] }

  def jwt(jti, **claims)
    JWT.encode({ iss: 'https://cds.example.org', aud: 'https://inferno.example.org/cds-services/order-sign-service',
                 exp: 5.minutes.from_now.to_i, iat: Time.now.to_i, jti: }.merge(claims).compact,
               rsa_key, 'RS384', { kid: 'key-1', typ: 'JWT' })
  end

  # tags the request by its `jti` as the hook endpoint does for a request it processed, adding the
  # duplicate tag when an earlier request in the session has the same `jti`
  def jwt_id_tags(authorization)
    payload, = JWT.decode(authorization.to_s.delete_prefix('Bearer '), nil, false)
    jti = payload['jti'] if payload.is_a?(Hash)
    return [] if jti.blank?

    tag = DaVinciCRDTestKit::TagMethods.jwt_id_tag(jti)
    used = Inferno::Repositories::Requests.new.tagged_requests(test_session.id, [tag]).present?
    [tag, (DaVinciCRDTestKit::DUPLICATED_JWT_ID_TAG if used)].compact
  rescue JWT::DecodeError
    []
  end

  def create_hook_request(authorization, hook_instance: SecureRandom.uuid, tags: hook_tags, hook: 'order-sign',
                          processed: true)
    repo_create(:request, direction: 'incoming', test_session_id: test_session.id, result:, status: 200,
                          url: "https://inferno.example.org/cds-services/#{hook}-service",
                          request_body: { hook:, hookInstance: hook_instance }.to_json,
                          headers: [{ type: 'request', name: 'Authorization', value: authorization }],
                          tags: processed ? tags + jwt_id_tags(authorization) : tags)
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

  it 'fails when different JWTs share a jti, naming the requests by hook and hookInstance' do
    create_hook_request("Bearer #{jwt('shared-jti')}", hook_instance: 'first')
    create_hook_request("Bearer #{jwt('other-jti')}", hook_instance: 'second')
    create_hook_request("Bearer #{jwt('shared-jti', iat: 1.minute.ago.to_i)}", hook_instance: 'third')

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages.map { |message| [message.type, message.message] }).to contain_exactly(
      ['error', '`jti` "shared-jti" was used by 2 different JWTs, sent on 2 hook requests: `order-sign` ' \
                '(hookInstance `first`) and `order-sign` (hookInstance `third`). Each hook request must carry ' \
                'a new JWT with its own `jti`.']
    )
  end

  it 'fails when the same JWT is sent on more than one request' do
    token = jwt('reused-jti')
    create_hook_request("Bearer #{token}", hook_instance: 'first')
    create_hook_request("Bearer #{token}", hook_instance: 'second')

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages.map { |message| [message.type, message.message] }).to contain_exactly(
      ['error', 'The same JWT (`jti` "reused-jti") was sent on 2 hook requests: `order-sign` (hookInstance ' \
                '`first`) and `order-sign` (hookInstance `second`). Each hook request must carry a new JWT ' \
                'with its own `jti`.']
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
      a_string_including('`jti` "shared-jti" was used by 2 different JWTs, sent on 3 hook requests')
    )
  end

  it 'reports each repeated jti separately' do
    create_hook_request("Bearer #{jwt('first-jti')}", hook_instance: 'one')
    create_hook_request("Bearer #{jwt('second-jti')}", hook_instance: 'two')
    create_hook_request("Bearer #{jwt('first-jti', iat: 1.minute.ago.to_i)}", hook_instance: 'three')
    create_hook_request("Bearer #{jwt('second-jti', iat: 1.minute.ago.to_i)}", hook_instance: 'four')

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message)).to contain_exactly(
      a_string_including('"first-jti"', '(hookInstance `one`) and `order-sign` (hookInstance `three`)'),
      a_string_including('"second-jti"', '(hookInstance `two`) and `order-sign` (hookInstance `four`)')
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

  it 'includes requests from scenario groups left out of the cross-invocation analysis' do
    create_hook_request("Bearer #{jwt('shared-jti')}")
    create_hook_request("Bearer #{jwt('shared-jti', iat: 1.minute.ago.to_i)}",
                        hook: 'encounter-start', hook_instance: 'scenario',
                        tags: [DaVinciCRDTestKit::ENCOUNTER_START_TAG, DaVinciCRDTestKit::LONG_RUNNING_GROUP_TAG])

    expect(run(test).result).to eq('fail')
    expect(result_messages.map(&:message)).to contain_exactly(
      a_string_including('sent on 2 hook requests', '`encounter-start` (hookInstance `scenario`)')
    )
  end

  it 'ignores requests Inferno rejected, which carry no jti tag' do
    token = jwt('resent-jti')
    create_hook_request("Bearer #{token}", hook: 'order-dispatch', tags: [], processed: false)
    create_hook_request("Bearer #{token}", hook_instance: 'resent')
    create_hook_request("Bearer #{token}", hook_instance: 'resent',
                                           tags: [DaVinciCRDTestKit::DUPLICATED_HOOK_INSTANCE_TAG], processed: false)

    expect(run(test).result).to eq('pass')
  end

  it 'adds the requests sharing a repeated jti to the result once each' do
    create_hook_request("Bearer #{jwt('shared-jti')}")
    create_hook_request("Bearer #{jwt('shared-jti', iat: 1.minute.ago.to_i)}")
    create_hook_request("Bearer #{jwt('shared-jti', iat: 2.minutes.ago.to_i)}")
    create_hook_request("Bearer #{jwt('other-jti')}")

    test_result = run(test)

    expect(Inferno::Repositories::Results::Model.find(id: test_result.id).requests.length).to eq(3)
  end
end
