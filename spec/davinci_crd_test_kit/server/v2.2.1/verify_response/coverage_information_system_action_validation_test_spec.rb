RSpec.describe DaVinciCRDTestKit::V221::CoverageInformationSystemActionValidationTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:request_result) { repo_create(:result, test_session_id: test_session.id) }
  let(:request_url) { 'http://example.com/cds-services/service' }
  let(:valid_coverage_info_system_action) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(json)['systemActions'].first
  end
  let(:coverage_information_extension) do
    valid_coverage_info_system_action.dig('resource', 'extension', 0).deep_dup
  end
  let(:order_sign_request_body) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:order_dispatch_request_body) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'order_dispatch_hook_request.json')))
  end
  let(:appointment_book_request_body) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json')))
  end
  let(:service_request_resource) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_service_request_example.json')))
  end

  before do
    allow_any_instance_of(runnable).to receive(:resource_is_valid?).and_return(true)
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  def create_hook_request(hook_name:, request_body:, actions:)
    repo_create(
      :request,
      result: request_result,
      direction: 'outgoing',
      url: request_url,
      request_body: request_body.to_json,
      response_body: { 'systemActions' => actions }.to_json,
      status: 200,
      tags: [hook_name]
    )
  end

  def stub_hook_requests(hook_name:, request_body:, actions:)
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return(hook_name)
    create_hook_request(hook_name:, request_body:, actions:)
  end

  def coverage_info_action(resource)
    {
      'type' => 'update',
      'description' => "Added coverage information to #{resource['resourceType']} resource.",
      'resource' => resource
    }
  end

  def mock_bundle_with(*resources)
    {
      'resourceType' => 'Bundle',
      'type' => 'collection',
      'entry' => resources.map { |resource| { 'resource' => resource } }
    }
  end

  it 'passes when only the coverage-information extension changes for order-sign' do
    original_resource = order_sign_request_body.dig('context', 'draftOrders', 'entry', 0, 'resource')
    updated_resource = original_resource.deep_dup
    updated_resource['extension'] << coverage_information_extension.deep_dup
    action = coverage_info_action(updated_resource)
    stub_hook_requests(hook_name: 'order-sign', request_body: order_sign_request_body, actions: [action])

    result = run(runnable, coverage_info: [action].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails when a non-coverage-information field changes' do
    original_resource = order_sign_request_body.dig('context', 'draftOrders', 'entry', 0, 'resource')
    updated_resource = original_resource.deep_dup
    updated_resource['status'] = 'active'
    updated_resource['extension'] << coverage_information_extension.deep_dup
    action = coverage_info_action(updated_resource)
    stub_hook_requests(hook_name: 'order-sign', request_body: order_sign_request_body, actions: [action])

    result = run(runnable, coverage_info: [action].to_json)

    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/changed outside the coverage-information extension/)
  end

  it 'fails when a non-coverage-information extension changes' do
    original_resource = order_sign_request_body.dig('context', 'draftOrders', 'entry', 0, 'resource')
    updated_resource = original_resource.deep_dup
    updated_resource['extension'].first['valueString'] = 'updated-value'
    updated_resource['extension'] << coverage_information_extension.deep_dup
    action = coverage_info_action(updated_resource)
    stub_hook_requests(hook_name: 'order-sign', request_body: order_sign_request_body, actions: [action])

    result = run(runnable, coverage_info: [action].to_json)

    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/changed outside the coverage-information extension/)
  end

  it 'passes when resolving the original order-dispatch resource from the mock EHR bundle' do
    updated_resource = service_request_resource.deep_dup
    updated_resource['extension'] = [coverage_information_extension.deep_dup]
    action = coverage_info_action(updated_resource)
    stub_hook_requests(hook_name: 'order-dispatch', request_body: order_dispatch_request_body, actions: [action])

    result = run(
      runnable,
      coverage_info: [action].to_json,
      mock_ehr_bundle: mock_bundle_with(service_request_resource).to_json
    )

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'passes when resolving the original order-dispatch resource from prefetch' do
    request_body = order_dispatch_request_body.deep_dup
    request_body['prefetch'] = { 'serviceRequest' => service_request_resource.deep_dup }
    updated_resource = service_request_resource.deep_dup
    updated_resource['extension'] = [coverage_information_extension.deep_dup]
    action = coverage_info_action(updated_resource)
    stub_hook_requests(hook_name: 'order-dispatch', request_body:, actions: [action])

    result = run(runnable, coverage_info: [action].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'passes when appointment-book updates the basedOn ServiceRequest instead of the Appointment' do
    appointment_request = appointment_book_request_body.deep_dup
    appointment_request.dig('context', 'appointments', 'entry', 0, 'resource')['basedOn'] = [
      { 'reference' => 'ServiceRequest/example' }
    ]
    updated_resource = service_request_resource.deep_dup
    updated_resource['extension'] = [coverage_information_extension.deep_dup]
    action = coverage_info_action(updated_resource)
    stub_hook_requests(hook_name: 'appointment-book', request_body: appointment_request, actions: [action])

    result = run(
      runnable,
      coverage_info: [action].to_json,
      mock_ehr_bundle: mock_bundle_with(service_request_resource).to_json
    )

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'warns when it cannot resolve the original source resource for comparison' do
    updated_resource = service_request_resource.deep_dup
    updated_resource['extension'] = [coverage_information_extension.deep_dup]
    action = coverage_info_action(updated_resource)
    stub_hook_requests(hook_name: 'order-dispatch', request_body: order_dispatch_request_body, actions: [action])

    result = run(runnable, coverage_info: [action].to_json)

    expect(result.result).to eq('pass'), result.result_message
    expect(entity_result_message.type).to eq('warning')
    expect(entity_result_message.message).to match(/could not resolve the original source resource/i)
  end
end
