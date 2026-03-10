RSpec.describe DaVinciCRDTestKit::ClientFHIRApiEncounterLocationSearchTest, :runnable do
  let(:suite_id) { 'crd_client' }

  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:ehr_smart_credentials) do
    {
      access_token: 'SAMPLE_TOKEN',
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      issue_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }
  end
  let(:smart_auth_info) { Inferno::DSL::AuthInfo.new(ehr_smart_credentials) }

  let(:patient_id) { 'example' }
  let(:encounter_id) { 'example' }
  let(:encounter_location_search_request) do
    "#{server_endpoint}/Encounter?location=Location/example"
  end

  let(:crd_encounter) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_encounter_example.json'
                ))
    )
  end

  let(:crd_encounter_second) do
    crd_encounter_second = crd_encounter.dup
    crd_encounter_second['id'] = 'example2'
    crd_encounter_second.delete('location')
    crd_encounter_second
  end

  let(:crd_encounter_search_bundle_extra) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ),
                        FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                          resource: FHIR.from_contents(crd_encounter_second.to_json)
                        ))
    bundle
  end

  let(:crd_encounter_search_bundle_correct) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ))
    bundle
  end

  let(:empty_bundle) do
    FHIR::Bundle.new(type: 'searchset')
  end

  describe 'Encounter location search test' do
    let(:test) do
      Class.new(described_class) do
        fhir_client do
          url :server_endpoint
          auth_info :smart_auth_info
        end

        input :server_endpoint
        input :smart_auth_info, type: :auth_info
      end
    end

    it 'passes and outputs an id if search values found and return results' do
      allow_any_instance_of(test).to receive(:scratch_resources_for_patient)
        .and_return([
                      FHIR.from_contents(crd_encounter.to_json),
                      FHIR.from_contents(crd_encounter_second.to_json)
                    ])

      encounter_search_request = stub_request(:get, encounter_location_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_correct.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made

      outputs_hash = JSON.parse(result.output_json)
      encounter_id_output = outputs_hash.find do |output|
        output['name'] == 'encounter_id_with_location'
      end

      expect(encounter_id_output).to be_present
      expect(encounter_id_output['value']).to eq('example')
    end

    it 'skips if search values found but no results returned' do
      allow_any_instance_of(test).to receive(:scratch_resources_for_patient)
        .and_return([
                      FHIR.from_contents(crd_encounter.to_json),
                      FHIR.from_contents(crd_encounter_second.to_json)
                    ])

      encounter_search_request = stub_request(:get, encounter_location_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(encounter_search_request).to have_been_made

      outputs_hash = JSON.parse(result.output_json)
      encounter_id_output = outputs_hash.find do |output|
        output['name'] == 'encounter_id_with_location'
      end
      expect(encounter_id_output).to be_blank
    end

    it 'fails if non-matching encounters returned' do
      allow_any_instance_of(test).to receive(:scratch_resources_for_patient)
        .and_return([
                      FHIR.from_contents(crd_encounter.to_json),
                      FHIR.from_contents(crd_encounter_second.to_json)
                    ])

      encounter_search_request = stub_request(:get, encounter_location_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_extra.to_json)

      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(encounter_search_request).to have_been_made

      outputs_hash = JSON.parse(result.output_json)
      encounter_id_output = outputs_hash.find do |output|
        output['name'] == 'encounter_id_with_location'
      end
      expect(encounter_id_output).to be_blank
    end

    it 'skips if no encounter previously found with a location value' do
      result = run(test, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match('Could not find values for all search params `location`')

      outputs_hash = JSON.parse(result.output_json)
      encounter_id_output = outputs_hash.find do |output|
        output['name'] == 'encounter_id_with_location'
      end
      expect(encounter_id_output).to be_blank
    end
  end
end
