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

  describe 'FHIRUpdateEndpoint - PUT /fhir/:resource_type/:resource_id' do
    it 'returns 200 when updating an existing resource' do
      updated = FHIR::Patient.new(id: patient.id, gender: 'unknown')
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", updated.to_json
      expect(last_response.status).to eq(200)
      resource = FHIR.from_contents(last_response.body)
      expect(resource.id).to eq(patient.id)
    end

    it 'returns 201 when upserting a resource that does not exist' do
      new_patient = FHIR::Patient.new(id: 'brand-new-id')
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/brand-new-id", new_patient.to_json
      expect(last_response.status).to eq(201)
    end

    it 'sets Content-Type to application/fhir+json' do
      updated = FHIR::Patient.new(id: patient.id)
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", updated.to_json
      expect(last_response.headers['Content-Type']).to include('application/fhir+json')
    end

    it 'returns 400 when the body resource type does not match the URL resource type' do
      mismatched = FHIR::Patient.new(id: patient.id)
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Observation/#{patient.id}", mismatched.to_json
      expect(last_response.status).to eq(400)
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome.resourceType).to eq('OperationOutcome')
    end

    it 'updates the resource in the bundle in session data' do
      updated = FHIR::Patient.new(id: patient.id, gender: 'unknown')
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", updated.to_json
      expect(last_response.status).to eq(200)

      saved_json = session_data_repo.load(test_session_id: test_session.id, name: 'mock_ehr_bundle')
      saved_bundle = FHIR.from_contents(saved_json)
      saved_patient = saved_bundle.entry.map(&:resource).find { |r| r.id == patient.id }
      expect(saved_patient).to_not be_nil
      expect(saved_patient.gender).to eq('unknown')
    end

    it 'adds the upserted resource to the bundle in session data' do
      new_patient = FHIR::Patient.new(id: 'brand-new-id')
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/brand-new-id", new_patient.to_json
      expect(last_response.status).to eq(201)

      saved_json = session_data_repo.load(test_session_id: test_session.id, name: 'mock_ehr_bundle')
      saved_bundle = FHIR.from_contents(saved_json)
      expect(saved_bundle.entry.length).to eq(2)
      expect(saved_bundle.entry.map { |e| e.resource.id }).to include('brand-new-id')
    end

    it 'uses the URL resource_id when body id differs' do
      mismatched = FHIR::Patient.new(id: 'different-id')
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", mismatched.to_json
      expect(last_response.status).to eq(200)
      resource = FHIR.from_contents(last_response.body)
      expect(resource.id).to eq(patient.id)
    end

    it 'sets Access-Control-Allow-Origin to *' do
      updated = FHIR::Patient.new(id: patient.id)
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", updated.to_json
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
    end

    it 'returns an error when the Authorization header is missing' do
      run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                    service_request_bodies:, mock_ehr_bundle:)
      updated = FHIR::Patient.new(id: patient.id)
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", updated.to_json
      expect(last_response.status).to be >= 400
    end

    it 'updated resource can be read back via GET' do
      updated = FHIR::Patient.new(id: patient.id, gender: 'unknown')
      wait_and_auth
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", updated.to_json
      expect(last_response.status).to eq(200)

      get "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(200)
      expect(FHIR.from_contents(last_response.body).gender).to eq('unknown')
    end
  end
end
