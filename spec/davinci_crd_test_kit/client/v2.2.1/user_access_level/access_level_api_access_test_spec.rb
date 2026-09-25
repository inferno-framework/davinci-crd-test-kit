require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/user_access_level/access_level_api_access_test'
require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::AccessLevelApiAccessTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:target_reference) { 'Observation/123' }
  let(:full_instance) { 'full-instance' }
  let(:limited_instance) { 'limited-instance' }
  let(:matching_resource) { { 'resourceType' => 'Observation', 'id' => '123' } }
  let(:different_resource) { { 'resourceType' => 'Observation', 'id' => '456' } }
  let(:denial_outcome) do
    { 'resourceType' => 'OperationOutcome',
      'issue' => [{ 'severity' => 'error', 'code' => 'forbidden' }] }
  end

  def hook_body(instance, fhir_server: 'https://example.com/fhir', access_token: 'token-abc')
    body = { 'hook' => 'order-sign', 'hookInstance' => instance }
    body['fhirServer'] = fhir_server if fhir_server
    body['fhirAuthorization'] = { 'access_token' => access_token } if access_token
    body
  end

  def create_hook_request(tag, instance, body: nil)
    repo_create(
      :request,
      direction: 'incoming',
      url: 'https://example.com/cds-services/order-sign-service',
      result:,
      test_session_id: test_session.id,
      request_body: (body || hook_body(instance)).to_json,
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

  def error_messages(result)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .find { |r| r.id == result.id }
      .messages.map(&:message).join("\n")
  end

  it 'skips when the full-access hook request was not successful' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('skip')
    expect(result.result_message).to include('Full-access hook request was not successful')
  end

  it 'skips when the limited-access hook request was not successful' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('skip')
    expect(result.result_message).to include('Limited-access hook request was not successful')
  end

  it 'fails when the target resource reference is not a relative reference' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)

    result = run(test, access_level_target_reference: 'https://example.com/fhir/Observation/123')
    expect(result.result).to eq('fail')
    expect(result.result_message).to include('is not a relative reference')
  end

  it 'fails when a hook request did not provide a fhirServer' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance,
                        body: hook_body(full_instance, fhir_server: nil))
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('full-access hook request did not include `fhirServer`')
  end

  it 'fails when a hook request did not provide an access token' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance,
                        body: hook_body(limited_instance, access_token: nil))

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('`fhirAuthorization.access_token`')
  end

  [401, 403, 404, 500].each do |denial_status|
    it "passes when the limited-access read withholds the resource with a #{denial_status}" do
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
      create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
      create_target_fetch(full_instance, status: 200, response_body: matching_resource)
      create_target_fetch(limited_instance, status: denial_status)

      expect(run(test, access_level_target_reference: target_reference).result).to eq('pass')
    end
  end

  it 'passes when the limited-access read returns an OperationOutcome with a 200' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: matching_resource)
    create_target_fetch(limited_instance, status: 200, response_body: denial_outcome)

    expect(run(test, access_level_target_reference: target_reference).result).to eq('pass')
  end

  it 'passes when the limited-access read returns a different resource' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: matching_resource)
    create_target_fetch(limited_instance, status: 200, response_body: different_resource)

    expect(run(test, access_level_target_reference: target_reference).result).to eq('pass')
  end

  it 'errors when Inferno never attempted a full-access read of the target resource' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('error')
    expect(result.result_message).to include('not performed during the full-access hook request')
  end

  it 'errors when Inferno never attempted a limited-access read of the target resource' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: matching_resource)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('error')
    expect(result.result_message).to include('not performed during the limited-access hook request')
  end

  it 'fails when the full-access read was itself denied' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 404)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('did not return that resource')
  end

  it 'fails when the full-access read succeeded but returned a different resource than requested' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: different_resource)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('did not return that resource')
  end

  it 'fails when the full-access read returns the correct id but the wrong resource type' do
    wrong_type_resource = { 'resourceType' => 'Patient', 'id' => '123' }
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: wrong_type_resource)
    create_target_fetch(limited_instance, status: 403)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('did not return that resource')
  end

  it 'fails when the limited-access read succeeded instead of being denied' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 200, response_body: matching_resource)
    create_target_fetch(limited_instance, status: 200, response_body: matching_resource)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('returned that resource')
  end

  it 'reports both problems when neither read is scoped as expected' do
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_FULL_GROUP_TAG, full_instance)
    create_hook_request(DaVinciCRDTestKit::ACCESS_LEVEL_LIMITED_GROUP_TAG, limited_instance)
    create_target_fetch(full_instance, status: 403)
    create_target_fetch(limited_instance, status: 200, response_body: matching_resource)

    result = run(test, access_level_target_reference: target_reference)
    expect(result.result).to eq('fail')
    expect(error_messages(result)).to include('did not return that resource')
    expect(error_messages(result)).to include('returned that resource')
  end
end
