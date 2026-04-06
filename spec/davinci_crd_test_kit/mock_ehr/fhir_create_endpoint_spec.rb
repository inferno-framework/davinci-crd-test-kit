RSpec.describe DaVinciCRDTestKit::V220::FHIRRequestTest, :request do
  let(:test) { described_class }
  let(:suite_id) { :crd_server_v220 }
  let(:token) { '12345' }
  let(:mock_ehr_bundle) { FHIR::Bundle.new.to_json }
  let(:new_patient) { FHIR::Patient.new(name: [FHIR::HumanName.new(family: 'Test')]) }
  let(:not_a_bundle) { FHIR::Patient.new.to_json }

  def wait_and_auth(bundle_input = mock_ehr_bundle)
    result = run(test, { token:, mock_ehr_bundle: bundle_input })
    expect(result.result).to eq('wait')
    header 'Authorization', "Bearer #{token}"
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
      expect(resource.id).not_to be_nil
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

    it 'returns 400 when the bundle is not loaded' do
      wait_and_auth(not_a_bundle)
      post "/custom/#{suite_id}/fhir/Patient", new_patient.to_json
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
  end
end
