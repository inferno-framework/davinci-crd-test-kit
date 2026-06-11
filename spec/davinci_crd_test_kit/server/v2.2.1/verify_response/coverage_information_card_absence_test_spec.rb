require_relative '../../../../../lib/davinci_crd_test_kit/server/v2.2.1/verify_response/coverage_information_card_absence_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::CoverageInformationCardAbsenceTest do
  let(:suite_id) { 'crd_server_v221' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:service_endpoint) { 'http://example.com/cds-services/order-sign-service' }

  let(:guideline_card) do
    {
      'summary' => 'Coverage guideline',
      'indicator' => 'info',
      'source' => {
        'label' => 'Inferno',
        'topic' => {
          'system' => 'http://terminology.hl7.org/CodeSystem/cdshooks-card-type',
          'code' => 'guideline',
          'display' => 'Guideline'
        }
      }
    }
  end

  let(:coverage_information_card) do
    {
      'summary' => 'Coverage information',
      'indicator' => 'info',
      'source' => {
        'label' => 'Inferno',
        'topic' => {
          'system' => 'http://terminology.hl7.org/CodeSystem/cdshooks-card-type',
          'code' => 'coverage-info',
          'display' => 'Coverage Information'
        }
      }
    }
  end

  let(:coverage_information_action) do
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

  def create_service_request(body:, status: 200)
    repo_create(
      :request,
      direction: 'outgoing',
      url: service_endpoint,
      test_session_id: test_session.id,
      request_body: {}.to_json,
      response_body: body.to_json,
      result:,
      status:,
      tags: [DaVinciCRDTestKit::ORDER_SIGN_TAG],
      headers: nil
    )
  end

  def entity_result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  before do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-sign')
  end

  it 'passes when successful responses include non-Coverage Information cards' do
    create_service_request(
      body: {
        'cards' => [guideline_card],
        'systemActions' => [coverage_information_action]
      }
    )

    result = run(runnable)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails when a successful response includes a Coverage Information card' do
    create_service_request(
      body: {
        'cards' => [coverage_information_card],
        'systemActions' => [coverage_information_action]
      }
    )

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage Information cards/)
    expect(entity_result_messages.map(&:message).join(' ')).to match(/must be returned as a systemAction/)
  end

  it 'ignores unsuccessful responses' do
    create_service_request(
      body: {
        'cards' => [coverage_information_card]
      },
      status: 400
    )

    result = run(runnable)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/All service requests were unsuccessful/)
  end
end
