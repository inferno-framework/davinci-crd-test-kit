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

  let(:draft_order) do
    {
      'resourceType' => 'ServiceRequest',
      'id' => 'service-request-1',
      'status' => 'draft',
      'intent' => 'order'
    }
  end

  let(:request_body) do
    {
      'hook' => 'order-sign',
      'context' => {
        'draftOrders' => {
          'resourceType' => 'Bundle',
          'type' => 'collection',
          'entry' => [
            {
              'resource' => draft_order
            }
          ]
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

  let(:coverage_information_card_action) do
    coverage_information_action.deep_dup
  end

  let(:partial_coverage_information_card_action) do
    coverage_information_card_action.tap do |action|
      action['resource'] = action['resource'].slice('resourceType', 'id', 'extension')
    end
  end

  let(:coverage_information_suggestion_card) do
    guideline_card.deep_merge(
      'summary' => 'Apply coverage information',
      'uuid' => 'a8f8a2ff-f2bf-41de-bb99-9ee20a990cca',
      'suggestions' => [
        {
          'label' => 'Apply coverage information',
          'uuid' => '7ca7d0b4-a6e2-4bd1-814e-5223d5bfa07a',
          'actions' => [coverage_information_card_action]
        }
      ]
    )
  end

  let(:partial_coverage_information_suggestion_card) do
    guideline_card.deep_merge(
      'summary' => 'Apply coverage information partial update',
      'uuid' => 'be75e450-3df3-4d89-8e0b-573af74ed701',
      'suggestions' => [
        {
          'label' => 'Apply coverage information',
          'uuid' => '89df7221-0e86-451c-9853-5e245f0d4479',
          'actions' => [partial_coverage_information_card_action]
        }
      ]
    )
  end

  let(:alternate_request_card) do
    coverage_information_card_action['resource']['status'] = 'active'

    guideline_card.deep_merge(
      'summary' => 'Change order status',
      'suggestions' => [
        {
          'label' => 'Change order status',
          'uuid' => '1b50c0f1-e8cf-4ce1-8e20-70bd0ce3ed1b',
          'actions' => [coverage_information_card_action]
        }
      ]
    )
  end

  def create_service_request(body:, status: 200)
    repo_create(
      :request,
      direction: 'outgoing',
      url: service_endpoint,
      test_session_id: test_session.id,
      request_body: request_body.to_json,
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

  it 'passes when a card suggestion updates the order in ways other than the coverage-information extension' do
    create_service_request(
      body: {
        'cards' => [alternate_request_card],
        'systemActions' => [coverage_information_action]
      }
    )

    result = run(runnable)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails when a successful response includes a card suggestion that only adds coverage information' do
    create_service_request(
      body: {
        'cards' => [coverage_information_suggestion_card],
        'systemActions' => [coverage_information_action]
      }
    )

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage Information cards/)
    expect(entity_result_messages.map(&:message).join(' ')).to match(/suggestion action/)
  end

  it 'fails when a card suggestion only contains a partial coverage-information extension update' do
    create_service_request(
      body: {
        'cards' => [partial_coverage_information_suggestion_card],
        'systemActions' => [coverage_information_action]
      }
    )

    result = run(runnable)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Coverage Information cards/)
  end

  it 'skips when all responses are unsuccessful' do
    create_service_request(
      body: {
        'cards' => [coverage_information_suggestion_card]
      },
      status: 400
    )

    result = run(runnable)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/All service requests were unsuccessful/)
  end
end
