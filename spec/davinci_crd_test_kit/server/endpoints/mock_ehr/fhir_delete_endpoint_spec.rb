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
  let(:not_a_bundle) { FHIR::Patient.new.to_json }

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

  describe 'FHIRDeleteEndpoint - DELETE /fhir/:resource_type/:resource_id' do
    it 'returns 204 after deleting an existing resource' do
      wait_and_auth
      delete "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(204)
    end

    it 'returns no body after a successful delete' do
      wait_and_auth
      delete "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.body).to be_empty
    end

    it 'returns 204 when the resource does not exist (idempotent)' do
      wait_and_auth
      delete "/custom/#{suite_id}/fhir/Patient/nonexistent-id"
      expect(last_response.status).to eq(204)
    end

    it 'removes the resource from the bundle in session data' do
      wait_and_auth
      delete "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(204)

      saved_json = session_data_repo.load(test_session_id: test_session.id, name: 'mock_ehr_bundle')
      saved_bundle = FHIR.from_contents(saved_json)
      expect(saved_bundle.entry).to be_empty
    end

    it 'sets Access-Control-Allow-Origin to *' do
      wait_and_auth
      delete "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
    end

    it 'returns an error when the Authorization header is missing' do
      run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                    service_request_bodies:, mock_ehr_bundle:)
      delete "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to be >= 400
    end

    it 'deleted resource cannot be read back via GET' do
      wait_and_auth
      delete "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(204)

      get "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(404)
    end
  end
end
