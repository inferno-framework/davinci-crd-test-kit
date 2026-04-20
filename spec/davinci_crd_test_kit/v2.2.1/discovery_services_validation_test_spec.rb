RSpec.describe DaVinciCRDTestKit::V221::DiscoveryServicesValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
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

  it 'fails when the davinci-crd.version extension contains in improperly formatted version' do
    service1 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.1', '2.2'] })
    service2 = cds_service.merge('extension' => { 'davinci-crd.version' => ['2.2.1'] })

    cds_services = { 'services' => [service1, service2] }.to_json

    result = run(runnable, cds_services:)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/invalid version strings/)
  end
end
