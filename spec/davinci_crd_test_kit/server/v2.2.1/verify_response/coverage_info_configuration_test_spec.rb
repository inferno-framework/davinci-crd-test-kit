require_relative '../../../../../lib/davinci_crd_test_kit/server/v2.2.1/verify_response/coverage_info_configuration_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::CoverageInfoConfigurationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:service_endpoint) { 'http://example.com/cds-services/order-sign-service' }
  let(:hook_request) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', '..', 'fixtures', 'order_sign_hook_request.json'
                         )))
  end
  let(:coverage_info_card) do
    {
      'summary' => 'Coverage information',
      'indicator' => 'info',
      'source' => { 'type' => 'coverage-info' }
    }
  end
  let(:guideline_card) do
    {
      'summary' => 'Guideline',
      'indicator' => 'info',
      'source' => { 'topic' => { 'code' => 'guideline' } }
    }
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
  let(:original_response) do
    {
      'cards' => [coverage_info_card, guideline_card],
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
    request_body: hook_request,
    tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG]
  )
    repo_create(
      :request,
      direction: 'outgoing',
      url: service_endpoint,
      test_session_id: test_session.id,
      request_body: request_body.to_json,
      response_body: body.to_json,
      result:,
      status:,
      tags:,
      headers: nil
    )
  end

  def create_disabled_service_request(**args)
    create_service_request(
      **args,
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG, DaVinciCRDTestKit::COVERAGE_INFO_DISABLED_TAG]
    )
  end

  def coverage_info_disabled_request_body
    hook_request.deep_dup.tap do |request_body|
      request_body['hookInstance'] = SecureRandom.uuid
      request_body['extension'] = {
        'davinci-crd.configuration' => {
          'coverage-info' => false
        }
      }
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

  it 'passes when coverage-info disabled responses omit coverage-info content' do
    create_disabled_service_request(body: filtered_response, request_body: coverage_info_disabled_request_body)

    result = run(runnable)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails if the coverage-info disabled response still contains coverage-info content' do
    create_disabled_service_request(request_body: coverage_info_disabled_request_body)

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage-info configuration responses were not valid/)
    expect(entity_result_messages.map(&:message).join(' ')).to match(/included coverage-info content/)
  end

  it 'skips if no coverage-info disabled follow-up request was made for primary hooks' do
    create_service_request

    result = run(runnable)

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/response contained coverage-info content to suppress/)
  end

  it 'omits if no coverage-info disabled follow-up request was made for secondary hooks' do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-select')

    create_service_request

    result = run(runnable)

    expect(result.result).to eq('omit')
    expect(result.result_message).to match(/response contained coverage-info content to suppress/)
  end
end
