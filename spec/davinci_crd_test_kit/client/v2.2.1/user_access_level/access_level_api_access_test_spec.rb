require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/user_access_level/access_level_api_access_test'
require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::AccessLevelApiAccessTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:target_reference) { 'Observation/123' }
  let(:full_instance) { 'full-instance' }
  let(:limited_instance) { 'limited-instance' }
  let(:matching_resource) { { 'resourceType' => 'Observation', 'id' => '123' } }
  let(:different_resource) { { 'resourceType' => 'Observation', 'id' => '456' } }

  def create_hook_request(tag, instance)
    repo_create(
      :request,
      direction: 'incoming',
      url: 'https://example.com/cds-services/order-sign-service',
      result:,
      test_session_id: test_session.id,
      request_body: { 'hook' => 'order-sign', 'hookInstance' => instance }.to_json,
      status: 200,
      headers: [],
      tags: [tag]
    )
  end

  def create_target_fetch(instance, status:, response_body: nil)
    repo_create(
      :request,
      direction: 'outgoing',
      url: "https://example.com/fhir/#{target_reference}",
      result:,
      test_session_id: test_session.id,
      response_body: response_body&.to_json,
      status:,
      headers: [],
      tags: [DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag(instance),
             DaVinciCRDTestKit::ACCESS_LEVEL_TARGET_FETCH_TAG]
    )
  end

  it 'skips when no full-access hook request has been received' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No full-access hook request/)
  end

  it 'skips when no limited-access hook request has been received' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No limited-access hook request/)
  end

  [401, 403, 404].each do |denial_status|
    it "passes when the full-access read succeeds and the limited-access read is denied with #{denial_status}" do
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
      create_target_fetch(full_instance, status: 200, response_body: matching_resource)
      create_target_fetch(limited_instance, status: denial_status)

      expect(run(test, access_level_target_reference: target_reference).result).to eq('pass')
    end
  end

  it 'fails when Inferno never attempted a full-access read of the target resource' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not attempt to read.*full-access/)
  end

  it 'fails when Inferno never attempted a limited-access read of the target resource' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: matching_resource)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not attempt to read.*limited-access/)
  end

  it 'fails when the full-access read itself failed' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 404)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/full-access read.*failed/)
  end

  it 'fails when the full-access read succeeded but returned a different resource than requested' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: different_resource)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not return the expected resource/)
  end

  it 'fails when the full-access read returns the correct id but the wrong resource type' do
    wrong_type_resource = { 'resourceType' => 'Patient', 'id' => '123' }
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: wrong_type_resource)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not return the expected resource/)
  end

  it 'fails when the limited-access read succeeded instead of being denied' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: matching_resource)
    create_target_fetch(limited_instance, status: 200, response_body: matching_resource)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/access should have been denied/)
  end

  [301, 500].each do |unexpected_status|
    it "fails when the limited-access read returns an unexpected status of #{unexpected_status}" do
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
      create_target_fetch(full_instance, status: 200, response_body: matching_resource)
      create_target_fetch(limited_instance, status: unexpected_status)

      result = run(test, access_level_target_reference: target_reference)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/access should have been denied/)
    end
  end
end
