require_relative '../../lib/davinci_crd_test_kit/client_tests/client_fhir_api_include_search_test'

RSpec.describe DaVinciCRDTestKit::ClientFHIRApiIncludeSearchTest, :runnable do
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
  let(:encounter_include_search_request) do
    "#{server_endpoint}/Encounter?_id=#{encounter_id}&_include=Encounter:location"
  end
  let(:encounter_include_search_request_different_id) do
    "#{server_endpoint}/Encounter?_id=example2&_include=Encounter:location"
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

  let(:crd_location) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_location_example.json'
                ))
    )
  end

  let(:crd_location_second) do
    crd_location_second = crd_location.dup
    crd_location_second['id'] = 'example2'
    crd_location_second
  end

  let(:operation_outcome) do
    FHIR::OperationOutcome.new(
      issue: [
        {
          severity: 'information',
          code: 'informational',
          details: {
            text: 'All OK'
          }
        }
      ]
    )
  end

  let(:encounter_example_include_location_search_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/example",
                          resource: FHIR.from_contents(crd_location.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/example2",
                          resource: FHIR.from_contents(crd_location_second.to_json)
                        ))
    bundle
  end

  let(:encounter_example_include_location_search_bundle_with_outcome) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/example",
                          resource: FHIR.from_contents(crd_location.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/example2",
                          resource: FHIR.from_contents(crd_location_second.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/OperationOutcome/operation_outcome_example",
                          resource: FHIR.from_contents(operation_outcome.to_json)
                        ))
    bundle
  end

  let(:crd_location_search_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/location_example",
                          resource: FHIR.from_contents(crd_location.to_json)
                        ))
    bundle
  end

  let(:crd_encounter_search_bundle_multiple_entries) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/example",
                          resource: FHIR.from_contents(crd_location.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/example2",
                          resource: FHIR.from_contents(crd_location_second.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                          resource: FHIR.from_contents(crd_encounter_second.to_json)
                        ))
    bundle
  end

  let(:crd_encounter_search_bundle_missing_location) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ))
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/example",
                          resource: FHIR.from_contents(crd_location.to_json)
                        ))
    bundle
  end

  let(:crd_encounter_search_bundle_wrong_encounter) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Location/example",
                             resource: FHIR.from_contents(crd_location.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_encounter_second) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/example2",
                          resource: FHIR.from_contents(crd_encounter_second.to_json)
                        ))
    bundle
  end

  let(:empty_bundle) do
    FHIR::Bundle.new(type: 'searchset')
  end

  describe 'Encounter search test with `_include` search parameter' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::ClientFHIRApiIncludeSearchTest) do
        fhir_client do
          url :server_endpoint
          auth_info :smart_auth_info
        end

        config(
          options: { resource_type: 'Encounter', target_include_element: 'location' }
        )

        input :server_endpoint
        input :smart_auth_info, type: :auth_info
      end
    end

    it 'passes if valid Encounter id is passed in that can be used to _include search for Encounter resources' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: encounter_example_include_location_search_bundle.to_json)

      result = run(test, search_id: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
    end

    it 'passes if _include search result includes an OperationOutcome resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: encounter_example_include_location_search_bundle_with_outcome.to_json)

      result = run(test, search_id: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
      expect(Inferno::Repositories::Messages.new.messages_for_result(result.id)).to be_blank
    end

    it 'skips if no resources returned in Encounter _include search' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      result = run(test, search_id: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message)
        .to eq('_include search not demonstrated - search result bundle is empty for Encounter _include ' \
               'location search with an id of `example`.')
      expect(encounter_search_request).to have_been_made
    end

    it 'skips if no Encounter ids are inputted' do
      result = run(test, search_id: '', server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No target id to use for the search, skipping test.')
    end

    it 'fails if Encounter _id search returns non 200' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: empty_bundle.to_json)

      result = run(test, search_id: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 400')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with no Encounter resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_location_search_bundle.to_json)

      result = run(test, search_id: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'The location _include search for Encounter resource with id example did not return a Encounter resource ' \
        'matching the searched id example.'
      )
      expect(encounter_search_request).to have_been_made
    end

    it 'warns if Encounter _include search returns a bundle with more than 1 Encounter resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_multiple_entries.to_json)

      result = run(test, search_id: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
      messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)
      expect(messages).to be_present
      expect(messages.length).to eq(1)
      expect(messages.first.type).to eq('warning')
      expect(messages.first.message).to match('Additional resources returned beyond those requested.')
    end

    it 'fails if Encounter _include search does not return the referenced locations' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_missing_location.to_json)

      result = run(test, search_id: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('referenced resource `Location/example2` not returned from the search')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with wrong Encounter id' do
      encounter_search_request = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_wrong_encounter.to_json)

      result = run(test, search_id: 'example2', server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message)
        .to match('The location _include search for Encounter resource with id example2 did not return a Encounter ' \
                  'resource matching the searched id example2')
      expect(encounter_search_request).to have_been_made
    end

    it 'skips if provided encounter does not has data in the included element' do
      encounter_search_request = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_encounter_second.to_json)

      result = run(test, search_id: 'example2', server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(
        'Encounter resource with id example2 did not include references in the element targeted to include ' \
        'location resources.'
      )
      expect(encounter_search_request).to have_been_made
    end
  end
end
