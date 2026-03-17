RSpec.describe DaVinciCRDTestKit::V220::FHIRRequestTest, :request do
  let(:test) { described_class }
  let(:suite_id) { :crd_server_v220 }
  let(:token) { '12345' }
  let(:patient) do
    FHIR.from_contents(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:mock_ehr_bundle) do
    bundle = FHIR::Bundle.new
    bundle.entry << FHIR::Bundle::Entry.new({ resource: patient })
    bundle.to_json
  end
  let(:not_a_bundle) { FHIR::Patient.new.to_json }

  def wait_and_auth(bundle_input = mock_ehr_bundle)
    result = run(test, { token:, mock_ehr_bundle: bundle_input })
    expect(result.result).to eq('wait')
    header 'Authorization', "Bearer #{token}"
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

    it 'returns 400 when the bundle is not loaded' do
      updated = FHIR::Patient.new(id: patient.id)
      wait_and_auth(not_a_bundle)
      put "/custom/#{suite_id}/fhir/Patient/#{patient.id}", updated.to_json
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
      expect(saved_patient).not_to be_nil
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
  end
end
