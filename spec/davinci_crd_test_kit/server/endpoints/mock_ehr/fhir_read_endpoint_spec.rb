require_relative '../../../../../lib/davinci_crd_test_kit/server/endpoints/mock_ehr/fhir_request_handler'

RSpec.describe DaVinciCRDTestKit::V201::ServerInvokeHookTest, :request do
  let(:suite_id) { 'crd_server' }
  let(:runnable) do
    Class.new(described_class) do
      input :inferno_base_url
    end
  end
  let(:test_session_id) { '12345' }
  let(:token) do
    DaVinciCRDTestKit::MockEHR::FHIRRequestHandler.session_id_to_token(test_session_id)
  end
  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:inferno_base_url) { 'http://inferno.com' }
  let(:service_ids) { 'appointment-book-service' }
  let(:service_request_body) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'))
    JSON.parse(json)
  end
  let(:service_request_bodies) { [service_request_body].to_json }
  let(:encryption_method) { 'ES384' }
  let(:patient) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:mock_ehr_bundle) do
    bundle = FHIR::Bundle.new
    bundle.entry << FHIR::Bundle::Entry.new({ resource: patient })
    bundle.to_json
  end

  def wait_and_auth(bundle_input = mock_ehr_bundle)
    result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:, service_request_bodies:,
                           mock_ehr_bundle: bundle_input)
    expect(result.result).to eq('wait')
    header 'Authorization', "Bearer #{token}"
  end

  before do
    allow_any_instance_of(DaVinciCRDTestKit::Jobs::InvokeHook) # hook invocations
      .to receive(:perform).and_return(nil)
    allow_any_instance_of(runnable).to receive(:test_session_id).and_return(test_session_id)
  end

  describe 'FHIRReadEndpoint - GET /fhir/:resource_type/:resource_id' do
    it 'returns 200 with the matching resource' do
      wait_and_auth
      get "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(200)
      resource = FHIR.from_contents(last_response.body)
      expect(resource.resourceType).to eq('Patient')
      expect(resource.id).to eq(patient.id)
    end

    it 'sets Content-Type to application/fhir+json' do
      wait_and_auth
      get "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.headers['Content-Type']).to include('application/fhir+json')
    end

    it 'returns 404 with an OperationOutcome when the resource is not found' do
      wait_and_auth
      get "/custom/#{suite_id}/fhir/Patient/nonexistent-id"
      expect(last_response.status).to eq(404)
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome.resourceType).to eq('OperationOutcome')
    end

    it 'sets Access-Control-Allow-Origin to *' do
      wait_and_auth
      get "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
    end

    it 'returns an error when the Authorization header is missing' do
      run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                    service_request_bodies:, mock_ehr_bundle:)
      get "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to be >= 400
    end
  end
end
