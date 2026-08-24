require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/user_access_level/access_level_prefetch_scope_test' # rubocop:disable Layout/LineLength
require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::AccessLevelPrefetchScopeTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:target_reference) { 'Observation/123' }
  let(:target_resource) { { 'resourceType' => 'Observation', 'id' => '123' } }
  let(:other_resource) { { 'resourceType' => 'Observation', 'id' => '999' } }

  def create_hook_request(tag, body)
    repo_create(
      :request,
      direction: 'incoming',
      url: 'https://example.com/cds-services/order-sign-service',
      result:,
      test_session_id: test_session.id,
      request_body: body.to_json,
      status: 200,
      headers: [],
      tags: [tag]
    )
  end

  def hook_body(hook_instance:, prefetch: {})
    { 'hook' => 'order-sign', 'hookInstance' => hook_instance, 'prefetch' => prefetch }
  end

  it 'skips when no full-access hook request has been received' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG,
                        hook_body(hook_instance: 'limited-instance'))
    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No full-access hook request/)
  end

  it 'skips when no limited-access hook request has been received' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG,
                        hook_body(hook_instance: 'full-instance'))
    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No limited-access hook request/)
  end

  it 'passes when the target resource is present in the full prefetch and absent from the limited prefetch' do
    full_body = hook_body(hook_instance: 'full-instance', prefetch: { 'observation' => target_resource })
    limited_body = hook_body(hook_instance: 'limited-instance', prefetch: { 'observation' => other_resource })
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)

    expect(run(test, access_level_target_reference: target_reference).result).to eq('pass')
  end

  it 'passes when the target resource is present within a prefetched Bundle for the full run only' do
    bundle = { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => target_resource }] }
    full_body = hook_body(hook_instance: 'full-instance', prefetch: { 'observations' => bundle })
    limited_body = hook_body(hook_instance: 'limited-instance',
                             prefetch: { 'observations' => { 'resourceType' => 'Bundle', 'entry' => [] } })
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)

    expect(run(test, access_level_target_reference: target_reference).result).to eq('pass')
  end

  it 'fails when the target resource is present in both the full and limited prefetch' do
    full_body = hook_body(hook_instance: 'full-instance', prefetch: { 'observation' => target_resource })
    limited_body = hook_body(hook_instance: 'limited-instance', prefetch: { 'observation' => target_resource })
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/present in both/)
  end

  it 'does not match a prefetched resource with the same type but a merely similar id' do
    similar_resource = { 'resourceType' => 'Observation', 'id' => '1234' }
    full_body = hook_body(hook_instance: 'full-instance', prefetch: { 'observation' => target_resource })
    limited_body = hook_body(hook_instance: 'limited-instance', prefetch: { 'observation' => similar_resource })
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)

    # Observation/1234 must not be treated as a match for Observation/123 in the limited prefetch,
    # so the strict presence/absence check should still pass.
    expect(run(test, access_level_target_reference: target_reference).result).to eq('pass')
  end

  context 'when the target resource is not present in the full-access prefetch' do
    let(:full_body) { hook_body(hook_instance: 'full-instance', prefetch: { 'observation' => other_resource }) }
    let(:limited_body) { hook_body(hook_instance: 'limited-instance', prefetch: { 'observation' => other_resource }) }

    before do
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_body)
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_body)
    end

    it 'passes when the tester attests that prefetch data is scoped by user access' do
      result = run(test, access_level_target_reference: target_reference,
                         access_level_prefetch_attestation: 'true')
      expect(result.result).to eq('pass')
    end

    it 'fails when the tester attests that prefetch data is not scoped by user access' do
      result = run(test, access_level_target_reference: target_reference,
                         access_level_prefetch_attestation: 'false')
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/could not demonstrate/)
    end

    it 'fails when the tester does not answer the attestation' do
      result = run(test, access_level_target_reference: target_reference)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/could not demonstrate/)
    end

    it 'still uses the attestation fallback even if the target is present only in the limited prefetch' do
      limited_body['prefetch'] = { 'observation' => target_resource }
      result = run(test, access_level_target_reference: target_reference,
                         access_level_prefetch_attestation: 'true')
      expect(result.result).to eq('pass')
    end

    it 'still requires the attestation (rather than failing on a "present in both" check) when the target ' \
       'is present only in the limited prefetch' do
      limited_body['prefetch'] = { 'observation' => target_resource }
      result = run(test, access_level_target_reference: target_reference)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/could not demonstrate/)
      expect(result.result_message).to_not match(/present in both/)
    end
  end

  it 'fails when a hook request body is not valid JSON' do
    repo_create(
      :request,
      direction: 'incoming',
      url: 'https://example.com/cds-services/order-sign-service',
      result:,
      test_session_id: test_session.id,
      request_body: 'not valid json',
      status: 200,
      headers: [],
      tags: [DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG]
    )
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG,
                        hook_body(hook_instance: 'limited-instance'))

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Unable to parse/)
  end
end
