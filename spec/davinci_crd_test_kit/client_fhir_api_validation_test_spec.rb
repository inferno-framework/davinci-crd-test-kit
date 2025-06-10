require_relative '../../lib/davinci_crd_test_kit/client_tests/client_fhir_api_validation_test'

RSpec.describe DaVinciCRDTestKit::ClientFHIRApiValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:server_endpoint) { 'http://example.com/fhir' }

  let(:encounter_id) { 'example' }
  let(:organization_id) { 'example' }

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

  let(:crd_encounter_search_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json),
                          id: 'encounter_entry'
                        ))
    bundle
  end

  let(:crd_encounter_search_bundle_multiple_entries) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                             resource: FHIR.from_contents(crd_encounter_second.to_json)
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

  let(:operation_outcome_success) do
    {
      outcomes: [{
        issues: []
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  let(:operation_outcome_failure) do
    {
      outcomes: [{
        issues: [{
          level: 'ERROR'
        }]
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  def create_fhir_api_requests(url: nil, body: nil, status: 200, search_tag: nil, name: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: 'Bearer SAMPLE_TOKEN'
      }
    ]
    repo_create(
      :request,
      direction: 'outgoing',
      url:,
      name:,
      test_session_id: test_session.id,
      result:,
      response_body: body.is_a?(Hash) ? body.to_json : body,
      tags: ['Encounter', search_tag],
      status:,
      headers:
    )
  end

  describe 'FHIR Resource Validation' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::ClientFHIRApiValidationTest) do
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL', 'http://hl7_validator_service:3500')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.us.davinci-crd', 'hl7.fhir.us.core')
        end
        config(
          options: { resource_type: 'Encounter' }
        )
      end
    end

    it 'passes if several fhir api requests return all valid resources' do
      validation_request = stub_request(:post, validator_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}",
        body: crd_encounter_search_bundle.to_json,
        search_tag: 'id_search',
        name: 'encounter_id_search'
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter/#{encounter_id}",
        body: crd_encounter.to_json,
        search_tag: 'read',
        name: 'encounter_readh'
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?organization=#{organization_id}",
        body: crd_encounter_search_bundle_multiple_entries.to_json,
        search_tag: 'organization_search',
        name: 'encounter_organization_search'
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}&_include=Encounter:location",
        body: crd_encounter_search_bundle_with_location.to_json,
        search_tag: 'include_location_search',
        name: 'encounter_include_search'
      )

      result = run(test)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(2)
    end

    it 'fails if any fhir api requests return invalid resources' do
      validation_request = stub_request(:post, validator_url)
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}",
        body: crd_encounter_search_bundle.to_json,
        search_tag: 'id_search',
        name: 'encounter_id_search'
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?organization=#{organization_id}",
        body: crd_encounter_search_bundle_multiple_entries.to_json,
        search_tag: 'organization_search',
        name: 'encounter_organization_search'
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}&_include=Encounter:location",
        body: crd_encounter_search_bundle_with_location.to_json,
        search_tag: 'include_location_search',
        name: 'encounter_include_search'
      )

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('2/2 Encounter resources returned from previous')
      expect(validation_request).to have_been_made.times(2)
    end

    it 'skips if no fhir api requests were made' do
      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No FHIR api requests were made')
    end

    it 'passes if at least one fhir api request returns a 200 even if one returns a non 200' do
      validation_request = stub_request(:post, validator_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}",
        body: operation_outcome_failure.to_json,
        search_tag: 'id_search',
        name: 'encounter_id_search',
        status: 400
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?organization=#{organization_id}",
        body: crd_encounter_search_bundle_multiple_entries.to_json,
        search_tag: 'organization_search',
        name: 'encounter_organization_search'
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}&_include=Encounter:location",
        body: crd_encounter_search_bundle_with_location.to_json,
        search_tag: 'include_location_search',
        name: 'encounter_include_search'
      )

      result = run(test)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(2)
    end

    it 'skips if all fhir api requests return a non 200' do
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}",
        body: operation_outcome_failure.to_json,
        search_tag: 'id_search',
        name: 'encounter_id_search',
        status: 400
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?organization=#{organization_id}",
        body: operation_outcome_failure.to_json,
        search_tag: 'organization_search',
        name: 'encounter_organization_search',
        status: 400
      )
      create_fhir_api_requests(
        url: "#{server_endpoint}/Encounter?_id=#{encounter_id}&_include=Encounter:location",
        body: operation_outcome_failure.to_json,
        search_tag: 'include_location_search',
        name: 'encounter_include_search',
        status: 400
      )

      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(
        'There were no successful FHIR API requests made in previous tests to use in validation.'
      )
    end
  end
end
