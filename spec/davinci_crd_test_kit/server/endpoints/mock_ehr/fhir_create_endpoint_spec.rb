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
  let(:mock_ehr_bundle) { FHIR::Bundle.new.to_json }
  let(:new_patient) { FHIR::Patient.new(name: [FHIR::HumanName.new(family: 'Test')]) }
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

  describe 'FHIRCreateEndpoint - POST /fhir/:resource_type' do
    it 'returns 201 with the created resource' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
      expect(last_response.status).to eq(201)
      resource = FHIR.from_contents(last_response.body)
      expect(resource.resourceType).to eq('Patient')
    end

    it 'assigns a generated id to the created resource' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
      resource = FHIR.from_contents(last_response.body)
      expect(resource.id).to_not be_nil
    end

    it 'sets Content-Type to application/fhir+json' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
      expect(last_response.headers['Content-Type']).to include('application/fhir+json')
    end

    it 'returns 400 when the body resource type does not match the URL resource type' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Observation", new_patient.to_json
      expect(last_response.status).to eq(400)
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome.resourceType).to eq('OperationOutcome')
    end

    it 'returns 400 when the body is not valid FHIR' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Patient", '{"not":"fhir"}'
      expect(last_response.status).to eq(400)
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome.resourceType).to eq('OperationOutcome')
    end

    it 'adds the created resource to the bundle in session data' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
      expect(last_response.status).to eq(201)

      created_id = FHIR.from_contents(last_response.body).id
      saved_json = session_data_repo.load(test_session_id: test_session.id, name: 'mock_ehr_bundle')
      saved_bundle = FHIR.from_contents(saved_json)
      expect(saved_bundle.entry.length).to eq(1)
      expect(saved_bundle.entry.first.resource.id).to eq(created_id)
    end

    it 'sets Access-Control-Allow-Origin to *' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
    end

    it 'returns an error when the Authorization header is missing' do
      run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                    service_request_bodies:, mock_ehr_bundle:)
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
      expect(last_response.status).to be >= 400
    end

    it 'created resource can be read back via GET' do
      wait_and_auth
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
      expect(last_response.status).to eq(201)

      created_id = FHIR.from_contents(last_response.body).id
      get "/custom/#{suite_id}/fhir/Patient/#{created_id}"
      expect(last_response.status).to eq(200)
      expect(FHIR.from_contents(last_response.body).id).to eq(created_id)
    end
  end
end
