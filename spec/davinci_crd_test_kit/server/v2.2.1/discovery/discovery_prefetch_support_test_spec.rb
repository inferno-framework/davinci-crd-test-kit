RSpec.describe DaVinciCRDTestKit::V221::DiscoveryPrefetchSupportTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:cds_service) do
    {
      'hook' => 'appointment-book',
      'title' => 'Appointment Booking CDS Service',
      'description' => 'An example of a CDS Service that is invoked when user of a CRD Client books an appointment',
      'id' => 'appointment-book-service',
      'prefetch' => {
        'user' => '{{context.userId}}',
        'patient' => 'Patient/{{context.patientId}}'
      }
    }
  end

  def entity_result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  it 'succeeds when a service contains a prefetch query' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2'] })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips if no services advertise prefetch support' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2'] })

    service1.delete 'prefetch'
    service2.delete 'prefetch'

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to match(/No CRD services advertised prefetch support/)
  end
end
