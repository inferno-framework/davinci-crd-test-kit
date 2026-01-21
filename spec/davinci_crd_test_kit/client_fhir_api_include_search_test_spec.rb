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
    crd_encounter_second
  end

  let(:crd_location) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_location_example.json'
                ))
    )
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
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents(crd_encounter_second.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_wrong_entries) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents({ resourceType: 'Coverage', id: 'cov123',
                                                            status: 'active' }.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_with_location) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents(crd_location.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_with_location_wrong_id) do
    crd_location['id'] = 'wrong_id'
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents(crd_location.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_with_operation_outcome) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ),
                        FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/OperationOutcome/operation_outcome_example",
                          resource: FHIR.from_contents(operation_outcome.to_json)
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
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location.to_json)

      result = run(test, search_ids: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
    end

    it 'passes if _include search result includes an OperationOutcome resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_operation_outcome.to_json)

      result = run(test, search_ids: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
    end

    it 'passes if at least 1 of list of Encounter ids returns resources in Encounter _include search' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location.to_json)
      encounter_search_request_empty = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      encounter_id_list = "#{encounter_id}, example2"
      result = run(test, search_ids: encounter_id_list, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
      expect(encounter_search_request_empty).to have_been_made
    end

    it 'skips if no resources returned in Encounter _include search' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      encounter_search_request_empty = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      encounter_id_list = "#{encounter_id}, example2"
      result = run(test, search_ids: encounter_id_list, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('_include search response not demonstrated.')
      expect(encounter_search_request).to have_been_made
      expect(encounter_search_request_empty).to have_been_made
    end

    it 'skips if no Encounter ids are inputted' do
      result = run(test, search_ids: '', server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No search parameters passed in, skipping test.')
    end

    it 'fails if Encounter _id search returns non 200' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: crd_encounter_search_bundle_with_location.to_json)

      result = run(test, search_ids: encounter_id, server_endpoint:, smart_auth_info:)

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

      result = run(test, search_ids: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'should include exactly 1 Encounter resource, instead got 0'
      )
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with more than 1 Encounter resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_multiple_entries.to_json)

      result = run(test, search_ids: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'should include exactly 1 Encounter resource, instead got 2'
      )
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with incorrect resource types' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_wrong_entries.to_json)

      result = run(test, search_ids: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Unexpected resource type: expected Location, but received Coverage')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with wrong Encounter id' do
      encounter_search_request = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location.to_json)

      result = run(test, search_ids: 'example2', server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Expected resource to have id: `example2`, but found `example`')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _id search returns Location resources that are not referenced by the Encounter resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location_wrong_id.to_json)

      result = run(test, search_ids: encounter_id, server_endpoint:, smart_auth_info:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'The Encounter resource in search result bundle with id example did not have a\nlocation reference'
      )
      expect(encounter_search_request).to have_been_made
    end
  end
end
