RSpec.describe DaVinciCRDTestKit::V220::FHIRRequestTest, :request do
  let(:test) { described_class }
  let(:suite_id) { :crd_server_v220 }
  let(:fhir_read_patient_example_endpoint) { "/custom/#{suite_id}/fhir/Patient/example" }
  let(:fhir_search_patient_endpoint) { "/custom/#{suite_id}/fhir/Patient" }
  let(:fhir_search_encounter_endpoint) { "/custom/#{suite_id}/fhir/Encounter" }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:token) { '12345' }
  let(:encounter_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_encounter_example.json')))
  end
  let(:patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', 'fixtures', 'crd_patient_example.json')))
  end
  let(:mock_ehr_bundle) do
    bundle = FHIR::Bundle.new
    bundle.entry << FHIR::Bundle::Entry.new({ resource: patient_example })
    bundle.entry << FHIR::Bundle::Entry.new({ resource: encounter_example })
    bundle.to_json
  end

  describe 'FHIR Read Endpoint' do
    it 'successful read request' do
      inputs = { token:, mock_ehr_bundle: }
      result = run(test, inputs)
      expect(result.result).to eq('wait')

      header 'Accept', 'application/json'
      header 'Authorization', "Bearer #{token}"
      get fhir_read_patient_example_endpoint
      expect(last_response.status).to eq(200)
      read_resource = FHIR.from_contents(last_response.body)
      expect(read_resource.id).to eq('example')
      expect(read_resource.resourceType).to eq('Patient')
    end
  end

  describe 'FHIR Search Endpoint' do
    it 'successful search on Patient.gender' do
      inputs = { token:, mock_ehr_bundle: }
      result = run(test, inputs)
      expect(result.result).to eq('wait')

      header 'Accept', 'application/json'
      header 'Authorization', "Bearer #{token}"
      get "#{fhir_search_patient_endpoint}?gender=female"
      expect(last_response.status).to eq(200)
      search_results = FHIR.from_contents(last_response.body)
      expect(search_results.resourceType).to eq('Bundle')
      expect(search_results.entry.size).to eq(1)
      expect(search_results.entry.first.resource.id).to eq('example')
      expect(search_results.entry.first.resource.resourceType).to eq('Patient')
    end

    it 'successful search on Encounter.patient' do
      inputs = { token:, mock_ehr_bundle: }
      result = run(test, inputs)
      expect(result.result).to eq('wait')

      header 'Accept', 'application/json'
      header 'Authorization', "Bearer #{token}"
      get "#{fhir_search_encounter_endpoint}?patient=example"
      expect(last_response.status).to eq(200)
      search_results = FHIR.from_contents(last_response.body)
      expect(search_results.resourceType).to eq('Bundle')
      expect(search_results.entry.size).to eq(1)
      expect(search_results.entry.first.resource.id).to eq('example')
      expect(search_results.entry.first.resource.resourceType).to eq('Encounter')
    end
  end
end
