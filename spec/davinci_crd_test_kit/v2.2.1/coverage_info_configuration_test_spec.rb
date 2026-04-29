require_relative '../../../lib/davinci_crd_test_kit/server/v2.2.1/verify_response/coverage_info_configuration_test'

RSpec.describe DaVinciCRDTestKit::V221::CoverageInfoConfigurationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:service_endpoint) { 'http://example.com/cds-services/order-sign-service' }
  let(:hook_request) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', 'fixtures', 'order_sign_hook_request.json'
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

  def create_service_request(body: original_response, status: 200, request_body: hook_request)
    repo_create(
      :request,
      direction: 'outgoing',
      url: service_endpoint,
      test_session_id: test_session.id,
      request_body: request_body.to_json,
      response_body: body.to_json,
      status:,
      headers: nil
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

  def mock_previous_requests(*requests)
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-sign')
    allow_any_instance_of(runnable).to receive(:requests).and_return(requests)
  end

  it 'passes when coverage-info disabled responses omit coverage-info content' do
    original_request = create_service_request
    disabled_request =
      create_service_request(body: filtered_response, request_body: coverage_info_disabled_request_body)
    mock_previous_requests(original_request, disabled_request)

    result = run(runnable)

    expect(result.result).to eq('pass')
  end

  it 'fails if the coverage-info disabled response still contains coverage-info content' do
    original_request = create_service_request
    disabled_request = create_service_request(request_body: coverage_info_disabled_request_body)
    mock_previous_requests(original_request, disabled_request)

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage-info configuration responses were not valid/)
    expect(entity_result_messages.map(&:message).join(' ')).to match(/included coverage-info content/)
  end

  it 'fails if no coverage-info disabled follow-up request was made after coverage-info content was returned' do
    request = create_service_request
    mock_previous_requests(request)

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(entity_result_messages.map(&:message).join(' '))
      .to match(/No order-sign request was made with `coverage-info` set to `false`/)
  end

  it 'skips when prior responses did not include coverage-info content' do
    request = create_service_request(body: filtered_response)
    mock_previous_requests(request)

    result = run(runnable)

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No successful order-sign response contained coverage-info/)
  end
end
