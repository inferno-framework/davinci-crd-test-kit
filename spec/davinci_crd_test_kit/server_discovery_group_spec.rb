RSpec.describe DaVinciCRDTestKit::ServerDiscoveryGroup do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_server') }
  let(:group) { Inferno::Repositories::TestGroups.new.find('crd_server_discovery_group') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_server') }
  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:cds_services) do
    {
      'services' => [
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
      ]
    }
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'discovery endpoint test' do
    let(:runnable) { group.tests[1] }
    let(:authentication_required) { 'no' }
    let(:encryption_method) { 'ES384' }

    it 'passes when a 200 response is received' do
      stub_request(:get, discovery_url)
        .to_return(status: 200, body: cds_services.to_json)
      result = run(runnable, base_url:, authentication_required:, encryption_method:)

      expect(result.result).to eq('pass')
    end

    it 'persists cds_services output' do
      stub_request(:get, discovery_url)
        .to_return(status: 200, body: cds_services.to_json)
      run(runnable, base_url:, authentication_required:, encryption_method:)

      expect(session_data_repo.load(test_session_id: test_session.id, name: 'cds_services'))
        .to eq(cds_services.to_json)
    end

    it 'fails when a non-200 response is received' do
      stub_request(:get, discovery_url)
        .to_return(status: 201, body: cds_services.to_json)
      result = run(runnable, base_url:, authentication_required:, encryption_method:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Unexpected response status:/)
    end

    it 'fails when the response body is an invalid json' do
      stub_request(:get, discovery_url)
        .to_return(status: 200, body: 'wd')
      result = run(runnable, base_url:, authentication_required:, encryption_method:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Invalid JSON/)
    end
  end

  describe 'discovery services validation test' do
    let(:runnable) { group.tests[2] }

    it 'passes when the all cds services contain all required fields' do
      result = run(runnable, cds_services: cds_services.to_json)

      expect(result.result).to eq('pass')
    end

    it 'fails if CDS services object does not contain a "services" attribute' do
      result = run(runnable, cds_services: {}.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Discovery response did not contain `services`')
    end

    it 'fails if "services" attribute of CDS services object is not an array' do
      result = run(runnable, cds_services: { services: {} }.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Services field of the CDS Discovery response object is not an array.')
    end

    it 'fails if a required field is missing from at least one service' do
      invalid_services = {
        'services' => [
          {
            'title' => 'Appointment Booking CDS Service',
            'id' => 'appointment-book-service',
            'prefetch' => {
              'user' => '{{context.userId}}',
              'patient' => 'Patient/{{context.patientId}}'
            }
          }
        ]
      }
      result = run(runnable, cds_services: invalid_services.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/did not contain required field/)
    end

    it 'fails if a required service field is present but does not have the correct data type' do
      invalid_services = {
        'services' => [
          {
            'hook' => ['appointment-book'],
            'title' => 'Appointment Booking CDS Service',
            'description' => 'An example of a CDS Service that is invoked when user of a CRD Client books an appt.',
            'id' => 'appointment-book-service',
            'prefetch' => {
              'user' => '{{context.userId}}',
              'patient' => 'Patient/{{context.patientId}}'
            }
          }
        ]
      }
      result = run(runnable, cds_services: invalid_services.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/is not of type/)
    end

    it 'skips if "cds_services" input is missing' do
      result = run(runnable, cds_services: nil)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/'cds_services' is nil, skipping test/)
    end

    it 'skips if "services" attribute of cds services object is an empty array' do
      result = run(runnable, cds_services: { services: [] }.to_json)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('Server hosts no CDS Services.')
    end
  end
end
