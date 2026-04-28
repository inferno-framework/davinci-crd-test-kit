require_relative '../../../lib/davinci_crd_test_kit/server/v2.2.0/verify_response/coverage_info_configuration_test'

RSpec.describe DaVinciCRDTestKit::V220::CoverageInfoConfigurationTest do
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

  def mock_previous_request(request)
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-sign')
    allow_any_instance_of(runnable).to receive(:requests).and_return([request])
  end

  it 'repeats prior coverage-info responses with coverage-info disabled' do
    request = create_service_request
    mock_previous_request(request)
    repeated_request = stub_request(:post, service_endpoint)
      .with do |webmock_request|
        repeated_body = JSON.parse(webmock_request.body)
        repeated_body.dig('extension', 'davinci-crd.configuration', 'coverage-info') == false &&
          repeated_body['hookInstance'] != hook_request['hookInstance']
      end
      .to_return(status: 200, body: filtered_response.to_json)

    result = run(runnable, encryption_method: 'RS384')

    expect(result.result).to eq('pass')
    expect(repeated_request).to have_been_made.once
  end

  it 'fails if the repeated response still contains coverage-info content' do
    request = create_service_request
    mock_previous_request(request)
    stub_request(:post, service_endpoint)
      .to_return(status: 200, body: original_response.to_json)

    result = run(runnable, encryption_method: 'RS384')

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/included coverage-info content/)
  end

  it 'skips when prior responses did not include coverage-info content' do
    request = create_service_request(body: filtered_response)
    mock_previous_request(request)

    result = run(runnable, encryption_method: 'RS384')

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No successful order-sign response contained coverage-info/)
  end
end
