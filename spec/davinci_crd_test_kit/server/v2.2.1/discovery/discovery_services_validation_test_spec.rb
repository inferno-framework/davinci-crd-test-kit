RSpec.describe DaVinciCRDTestKit::V221::DiscoveryServicesValidationTest do
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
  let(:non_crd_service) do
    cds_service.merge(
      'id' => 'non-crd-appointment-book-service',
      'extension' => nil
    )
  end

  def entity_result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  it 'succeeds when all services contain a valid davinci-crd.version extension' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2'] })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails when the davinci-crd.version extension is not present' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.x' => ['2.2'] })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/does not contain/)
  end

  it 'fails when the davinci-crd.version extension is not an Array' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => '2.2' })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/is not of type Array/)
  end

  it 'fails when the davinci-crd.version extension is empty' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => [] })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/is empty/)
  end

  it 'fails when the davinci-crd.version extension contains non-string values' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', 2.2] })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/contains non-string values/)
  end

  it 'fails when the davinci-crd.version extension contains in improperly formatted version' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2.1'] })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/invalid version strings/)
  end

  it 'does not apply CRD-specific discovery requirements to ignored services' do
    crd_service = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2'] })

    result = run(
      runnable,
      cds_services: { 'services' => [crd_service, non_crd_service] }.to_json,
      crd_discovery_service_ignore_list: 'non-crd-appointment-book-service'
    )

    expect(result.result).to eq('pass'), result.result_message
    expect(session_data_repo.load(test_session_id: test_session.id, name: 'appointment_book_service_ids'))
      .to eq('appointment-book-service')
    expect(entity_result_messages.find { |message| message.type == 'info' }&.message)
      .to match(/Ignoring service `non-crd-appointment-book-service`/)
  end

  it 'accepts comma separated ignored service ids' do
    crd_service = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2'] })

    result = run(
      runnable,
      cds_services: { 'services' => [crd_service, non_crd_service] }.to_json,
      crd_discovery_service_ignore_list: 'other-service, non-crd-appointment-book-service'
    )

    expect(result.result).to eq('pass'), result.result_message
    expect(session_data_repo.load(test_session_id: test_session.id, name: 'appointment_book_service_ids'))
      .to eq('appointment-book-service')
  end

  it 'does not validate ignored services against CDS Hooks discovery requirements' do
    crd_service = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2'] })
    invalid_service = non_crd_service.merge('description' => nil)

    result = run(
      runnable,
      cds_services: { 'services' => [crd_service, invalid_service] }.to_json,
      crd_discovery_service_ignore_list: 'non-crd-appointment-book-service'
    )

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'persists blank service id outputs if no services are discovered' do
    session_data_repo.save(test_session_id: test_session.id, name: 'appointment_book_service_ids',
                           value: 'stale-service-id', type: 'text')

    result = run(
      runnable,
      cds_services: { 'services' => [] }.to_json
    )

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to eq('Server hosts no CDS Services.')
    expect(session_data_repo.load(test_session_id: test_session.id, name: 'appointment_book_service_ids')).to be_nil
  end

  it 'skips if all discovered services are ignored for CRD validation' do
    session_data_repo.save(test_session_id: test_session.id, name: 'appointment_book_service_ids',
                           value: 'stale-service-id', type: 'text')

    result = run(
      runnable,
      cds_services: { 'services' => [non_crd_service] }.to_json,
      crd_discovery_service_ignore_list: 'non-crd-appointment-book-service'
    )

    expect(result.result).to eq('skip'), result.result_message
    expect(result.result_message).to eq('Ignore list excludes all CDS Services from validation.')
    expect(session_data_repo.load(test_session_id: test_session.id, name: 'appointment_book_service_ids')).to be_nil
  end
end
