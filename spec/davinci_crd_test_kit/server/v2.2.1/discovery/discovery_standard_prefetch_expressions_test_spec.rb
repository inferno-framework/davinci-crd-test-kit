RSpec.describe DaVinciCRDTestKit::V221::DiscoveryStandardPrefetchExpressionsTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:standard_appointment_book_service) do
    {
      'hook' => 'appointment-book',
      'title' => 'Appointment Booking CDS Service',
      'description' => 'An example of a CDS Service that is invoked when user of a CRD Client books an appointment',
      'id' => 'appointment-book-service',
      'prefetch' => {
        'member' => 'Patient/{{context.patientId}}',
        'activeCoverage' => 'Coverage?patient={{context.patientId}}&status=active'
      }
    }
  end

  def warning_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .select { |message| message.type == 'warning' }
  end

  def info_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .select { |message| message.type == 'info' }
  end

  it 'passes without warnings when advertised prefetch expressions match standard expressions for the hook' do
    cds_services = { 'services' => [standard_appointment_book_service] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('pass'), result.result_message
    expect(warning_messages).to be_empty
  end

  it 'passes with a warning when an advertised prefetch expression is not standard for the hook' do
    service = standard_appointment_book_service.merge(
      'prefetch' => standard_appointment_book_service['prefetch'].merge(
        'customCoverage' => 'Coverage?beneficiary={{context.patientId}}&status=active'
      )
    )

    result = run(runnable, cds_services: { 'services' => [service] }.to_json)

    expect(result.result).to eq('pass'), result.result_message
    expect(warning_messages.length).to eq(1)
    expect(warning_messages.first.message)
      .to include('Service `appointment-book-service` advertises prefetch expression')
    expect(warning_messages.first.message)
      .to include('prefetch field `customCoverage`')
  end

  it 'does not warn about ignored services' do
    ignored_service = standard_appointment_book_service.merge(
      'id' => 'ignored-service',
      'prefetch' => {
        'customCoverage' => 'Coverage?beneficiary={{context.patientId}}&status=active'
      }
    )

    result = run(
      runnable,
      cds_services: { 'services' => [standard_appointment_book_service, ignored_service] }.to_json,
      crd_discovery_service_ignore_list: 'ignored-service'
    )

    expect(result.result).to eq('pass'), result.result_message
    expect(warning_messages).to be_empty
    expect(info_messages.first&.message).to match(/Ignoring service `ignored-service`/)
  end

  it 'skips if no services advertise prefetch support' do
    service = standard_appointment_book_service.dup
    service.delete('prefetch')

    result = run(runnable, cds_services: { 'services' => [service] }.to_json)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/No CRD services advertised prefetch support/)
  end
end
