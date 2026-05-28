RSpec.describe DaVinciCRDTestKit::V221::VerifyResponseWithoutConfigurationTest do
  let(:suite_id) { 'crd_server_v221' }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:runnable) { described_class }
  let(:appointment) { { resourceType: 'Appointment' } }
  let(:bundle) do
    FHIR::Bundle.new(
      entry: [
        {
          resource: FHIR::Appointment.new(appointment)
        }
      ]
    )
  end

  it 'passes if a successful request without configuration options has been made' do
    request_body = { context: { appointments: bundle.to_hash } }.to_json

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body: '',
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )

    result = run(runnable)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips if no requests could be found' do
    result = run(runnable)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/No requests were made/)
  end

  it 'skips if no successful requests were made' do
    request_body = { context: { appointments: bundle.to_hash } }.to_json

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body: '',
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 500
    )

    result = run(runnable)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/were unsuccessful/)
  end

  it 'skips if all successful requests contain configuration options' do
    request_body =
      {
        context: { appointments: bundle.to_hash },
        extension: {
          'davinci-crd.configuration': {
            cost: false
          }
        }
      }.to_json

    repo_create(
      :request,
      direction: 'outgoing',
      test_session_id: test_session.id,
      result:,
      request_body:,
      response_body: '',
      tags: [DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG],
      status: 200
    )

    result = run(runnable)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/All successful requests included configuration options/)
  end
end
