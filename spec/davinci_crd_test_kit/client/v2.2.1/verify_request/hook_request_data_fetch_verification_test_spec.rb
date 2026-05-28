require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::HookRequestDataFetchVerificationTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:hook_name) { 'order-sign' }
  let(:hook_instance) { 'd1577c69-dfbe-44ad-ba6d-3e05e953b2ea' }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:test) do
    Class.new(described_class) do
      config(options: { hook_name: 'order-sign' })
    end
  end

  let(:hook_request_body) do
    { 'hookInstance' => hook_instance, 'hook' => hook_name }
  end

  let(:organization_resource) do
    { 'resourceType' => 'Organization', 'id' => 'example-payer' }
  end

  def create_hook_request(body: hook_request_body, tags: [hook_name])
    repo_create(
      :request,
      direction: 'incoming',
      url: "https://example.com/cds-services/#{hook_name}-service",
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status: 200,
      headers: [],
      tags:
    )
  end

  def create_data_fetch_request(response_body:, status: 200, instance: hook_instance)
    repo_create(
      :request,
      direction: 'outgoing',
      url: 'https://example.com/fhir/Organization/example-payer',
      result:,
      test_session_id: test_session.id,
      response_body: response_body.is_a?(Hash) ? response_body.to_json : response_body,
      status:,
      headers: [],
      tags: [DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag(instance), DaVinciCRDTestKit::DATA_FETCH_TAG]
    )
  end

  it 'skips when no hook requests received' do
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No #{hook_name} hook requests received/)
  end

  it 'passes when an additional data request returned a FHIR resource' do
    create_hook_request
    create_data_fetch_request(response_body: organization_resource)
    expect(run(test).result).to eq('pass')
  end

  it 'passes when an additional data request returned a non-empty Bundle' do
    bundle = {
      'resourceType' => 'Bundle',
      'entry' => [{ 'resource' => organization_resource }]
    }
    create_hook_request
    create_data_fetch_request(response_body: bundle)
    expect(run(test).result).to eq('pass')
  end

  it 'fails when no additional data requests were made for any hook request' do
    create_hook_request
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/never able to successfully obtain additional FHIR data/)
  end

  it 'fails when all additional data requests returned a non-2xx status' do
    create_hook_request
    create_data_fetch_request(response_body: organization_resource, status: 404)
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/never able to successfully obtain additional FHIR data/)
  end

  it 'fails when all additional data requests returned an empty Bundle' do
    create_hook_request
    create_data_fetch_request(response_body: { 'resourceType' => 'Bundle', 'entry' => [] })
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/never able to successfully obtain additional FHIR data/)
  end

  it 'fails when all additional data requests returned non-FHIR response bodies' do
    create_hook_request
    create_data_fetch_request(response_body: 'not valid json or fhir')
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/never able to successfully obtain additional FHIR data/)
  end

  it 'passes when at least one of multiple hook requests has successful additional data' do
    second_instance = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    create_hook_request
    # First request has no data fetch — no additional requests stored
    create_hook_request(body: { 'hookInstance' => second_instance, 'hook' => hook_name })
    create_data_fetch_request(response_body: organization_resource, instance: second_instance)
    expect(run(test).result).to eq('pass')
  end

  describe 'when a crd_test_group is configured' do
    let(:test) do
      Class.new(described_class) do
        config(options: { hook_name: 'order-sign', crd_test_group: 'some-group' })
      end
    end

    it 'only loads hook requests that have both the hook tag and the group tag' do
      second_instance = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
      # This request lacks the group tag; its data would make the test pass if loaded
      create_hook_request(body: { 'hookInstance' => second_instance, 'hook' => hook_name },
                          tags: [hook_name])
      create_data_fetch_request(response_body: organization_resource, instance: second_instance)
      # This request has both tags but no successful data fetch
      create_hook_request(tags: [hook_name, 'some-group'])
      result = run(test)
      expect(result.result).to eq('fail')
    end
  end
end
