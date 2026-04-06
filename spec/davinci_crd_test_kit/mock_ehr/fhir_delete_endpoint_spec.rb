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

    it 'returns 400 when the bundle is not loaded' do
      wait_and_auth(not_a_bundle)
      delete "/custom/#{suite_id}/fhir/Patient/#{patient.id}"
      expect(last_response.status).to eq(400)
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome.resourceType).to eq('OperationOutcome')
    end
  end
end
