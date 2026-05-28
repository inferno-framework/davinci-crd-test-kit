require_relative '../../../../../lib/davinci_crd_test_kit/server/v2.2.1/verify_response/unknown_cds_hooks_elements_test'

RSpec.describe DaVinciCRDTestKit::V221::UnknownCDSHooksElementsTest do
  let(:suite_id) { 'crd_server_v221' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:service_endpoint) { 'http://example.com/cds-services/order-sign-service' }
  let(:hook_request) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', '..', 'fixtures', 'order_sign_hook_request.json'
                         )))
  end
  let(:coverage_info_action) do
    {
      'type' => 'update',
      'description' => 'Added coverage information',
      'resource' => {
        'resourceType' => 'ServiceRequest',
        'id' => 'service-request-1',
        'status' => 'draft',
        'intent' => 'order',
        'extension' => [
          {
            'url' => DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFO_EXT_URL
          }
        ]
      }
    }
  end
  let(:guideline_card) do
    {
      'summary' => 'Guideline',
      'indicator' => 'info',
      'source' => { 'topic' => { 'code' => 'guideline' } }
    }
  end
  let(:original_response) do
    {
      'cards' => [guideline_card],
      'systemActions' => [coverage_info_action]
    }
  end
  let(:filtered_response) do
    {
      'cards' => [guideline_card],
      'systemActions' => []
    }
  end

  def create_service_request(
    body: original_response,
    status: 200,
    tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG]
  )
    repo_create(
      :request,
      direction: 'outgoing',
      url: service_endpoint,
      test_session_id: test_session.id,
      request_body: unknown_cds_hooks_element_request_body.to_json,
      response_body: body.to_json,
      result:,
      status:,
      tags:,
      headers: nil
    )
  end

  def create_unknown_cds_hooks_element_request(**args)
    create_service_request(
      **args,
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG, DaVinciCRDTestKit::UNKNOWN_ELEMENT_TAG]
    )
  end

  def unknown_cds_hooks_element_request_body
    hook_request.deep_dup.tap do |request_body|
      request_body['hookInstance'] = SecureRandom.uuid
      request_body['RANDOM_KEY'] = 'RANDOM_KEY'
    end
  end

  def entity_result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  before do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-sign')
  end

  it 'passes when unknown cds hooks element responses include coverage-info' do
    create_unknown_cds_hooks_element_request(body: original_response)

    result = run(runnable)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails if the unknown response does not contain coverage-info' do
    create_unknown_cds_hooks_element_request(body: filtered_response)

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/unknown CDS Hooks element were not valid/)
    expect(
      entity_result_messages.map(&:message).join(' ')
    ).to match(/did not contain a coverage information system action/)
  end

  it 'skips if no unknown cds hooks element follow-up request was made for primary hooks' do
    create_service_request

    result = run(runnable)

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/response contained a coverage-info action/)
  end

  it 'omits if no unknown cds hooks element follow-up request was made for secondary hooks' do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-select')

    create_service_request

    result = run(runnable)

    expect(result.result).to eq('omit')
    expect(result.result_message).to match(/response contained a coverage-info action/)
  end
end
