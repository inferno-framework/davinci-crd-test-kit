RSpec.describe DaVinciCRDTestKit::V221::OrderDispatchCoverageInformationTest do
  let(:suite_id) { 'crd_server_v221' }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:runnable) { described_class }
  let(:service_request_hash) { { resourceType: 'ServiceRequest', id: 'abc123' } }
  let(:service_request) { FHIR::ServiceRequest.new(service_request_hash) }
  let(:service_request_with_coverage_info) do
    service_request_hash.merge(
      extension: [
        { url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information' }
      ]
    )
  end

  before do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-dispatch')
  end

  it 'passes if every successful response contains the coverage information system action' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: service_request
        }
      ]
    )

    request_body = { context: { dispatchedOrders: [service_request.to_reference.reference] } }.to_json
    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: service_request_with_coverage_info
        }
      ]
    }.to_json

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body:,
      tags: [DaVinciCRDTestKit::ORDER_DISPATCH_TAG],
      status: 200
    )
    result = run(runnable, { invoked_hook: 'appointment-book', mock_ehr_bundle: bundle.to_json })
    expect(result.result).to eq('pass'), result.result_message
  end

  it 'passes if a dispatchedOrder is in the prefetch' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: service_request
        }
      ]
    )

    medication_request = FHIR::MedicationRequest.new(id: 'def456')

    request_body = {
      context: {
        dispatchedOrders: [
          service_request.to_reference.reference,
          medication_request.to_reference.reference
        ]
      },
      prefetch: {
        bundle:,
        resource: medication_request
      }
    }.to_json

    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: service_request_with_coverage_info
        }
      ]
    }.to_json

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body:,
      tags: [DaVinciCRDTestKit::ORDER_DISPATCH_TAG],
      status: 200
    )

    result =
      run(
        runnable,
        {
          invoked_hook: 'appointment-book',
          mock_ehr_bundle: '{"resourceType":"Bundle","type":"collection"}'
        }
      )

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips if not all referenced orders can be found' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: service_request
        }
      ]
    )

    request_body =
      { context: { dispatchedOrders: [service_request.to_reference.reference, 'ServiceRequest/badid'] } }.to_json
    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: service_request_with_coverage_info
        }
      ]
    }.to_json

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body:,
      tags: [DaVinciCRDTestKit::ORDER_DISPATCH_TAG],
      status: 200
    )
    result = run(runnable, { invoked_hook: 'appointment-book', mock_ehr_bundle: bundle.to_json })

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/are not included in the Mock EHR Data input/)
  end
end
