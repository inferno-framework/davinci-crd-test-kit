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

  def wait_and_auth(bundle_input = mock_ehr_bundle)
    result = run(test, { token:, mock_ehr_bundle: bundle_input })
    expect(result.result).to eq('wait')
    header 'Authorization', "Bearer #{token}"
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

    it 'returns 400 with an OperationOutcome when the resource is not found' do
      wait_and_auth
      get "/custom/#{suite_id}/fhir/Patient/nonexistent-id"
      expect(last_response.status).to eq(400)
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome.resourceType).to eq('OperationOutcome')
    end

    it 'returns 400 with an OperationOutcome when the bundle is not loaded' do
      wait_and_auth(FHIR::Patient.new.to_json)
      get "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(400)
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome.resourceType).to eq('OperationOutcome')
    end
  end
end
