RSpec.describe DaVinciCRDTestKit::V221::AllResponsesIncludeCoverageInformationTest do
  let(:suite_id) { 'crd_server_v221' }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:runnable) { described_class }
  let(:appointment) { { resourceType: 'Appointment' } }
  let(:appointment_with_coverage_info) do
    appointment.merge(
      extension: [
        { url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information' }
      ]
    )
  end

  before do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('appointment-book')
  end

  it 'passes if every successful response contains the coverage information system action' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: FHIR::Appointment.new(appointment)
        }
      ]
    )

    request_body = { context: { appointments: bundle.to_hash } }.to_json
    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: appointment_with_coverage_info
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
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )
    result = run(runnable, { invoked_hook: 'appointment-book' })
    expect(result.result).to eq('pass'), result.result_message
  end

  it 'passes if every requests are configured to exclude the coverage information system action' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: FHIR::Appointment.new(appointment)
        }
      ]
    )

    request_body = { context: { appointments: bundle.to_hash } }.to_json
    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: appointment_with_coverage_info
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
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )

    request_body =
      {
        context: {
          appointments: bundle.to_hash
        },
        extension: {
          'davinci-crd.configuration': {
            'coverage-info': false
          }
        }
      }.to_json
    response_body = { systemActions: [] }.to_json

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body:,
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )
    result = run(runnable, { invoked_hook: 'appointment-book' })
    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails if not all responses contain the coverage information system action' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: FHIR::Appointment.new(appointment)
        }
      ]
    )

    request_body = { context: { appointments: bundle.to_hash } }.to_json
    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: appointment
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
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )
    result = run(runnable, { invoked_hook: 'appointment-book' })

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/1 successful hook calls/)
  end

  it 'ignores calls which already contain a coverage information extension' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: FHIR::Appointment.new(appointment)
        }
      ]
    )

    request_body = { context: { appointments: bundle.to_hash } }.to_json
    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: appointment_with_coverage_info
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
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )

    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: FHIR::Appointment.new(appointment_with_coverage_info)
        }
      ]
    )

    request_body = { context: { appointments: bundle.to_hash } }.to_json
    response_body = '{}'

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body:,
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )
    result = run(runnable, { invoked_hook: 'appointment-book' })

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips if no calls have a resource without a coverage-information extension' do
    bundle = FHIR::Bundle.new(
      entry: [
        {
          resource: FHIR::Appointment.new(appointment_with_coverage_info)
        }
      ]
    )

    request_body = { context: { appointments: bundle.to_hash } }.to_json
    response_body = {
      systemActions: [
        {
          type: 'update',
          resource: appointment_with_coverage_info
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
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )
    result = run(runnable, { invoked_hook: 'appointment-book' })

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/No successful hook calls/)
  end
end
