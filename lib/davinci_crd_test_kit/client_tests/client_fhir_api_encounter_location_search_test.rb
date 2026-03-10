require 'us_core_test_kit'

module DaVinciCRDTestKit
  class ClientFHIRApiEncounterLocationSearchTest < USCoreTestKit::USCoreV311::EncounterIdentifierSearchTest
    title 'Server returns valid results for Encounter search by location'
    description %(
A CRD Client (as a FHIR server) SHALL support searching by
location on the Encounter resource. This test
will pass if resources are returned and match the search criteria. If
none are returned, the test is skipped.

[CRD Client CapabilityStatement](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html)

      )

    id :crd_client_fhir_api_encounter_location_search
    optional false

    output :encounter_id_with_location

    def self.properties
      @properties ||= USCoreTestKit::SearchTestProperties.new(
        resource_type: 'Encounter',
        search_param_names: ['location'],
        possible_status_search: false
      )
    end

    def add_location_search_to_metadata
      metadata.search_definitions[:location] = {
        paths: ['location.location'],
        full_paths: ['Encounter.location.location'],
        comparators: {},
        values: [],
        type: 'Reference',
        contains_multiple: true,
        multiple_or: 'MAY'
      }
    end

    run do
      add_location_search_to_metadata
      run_search_test

      return unless requests.present?

      search_response_bundle = FHIR.from_contents(requests[0].response_body)
      return unless search_response_bundle.is_a?(FHIR::Bundle)

      encounter_id_with_location = search_response_bundle.entry&.first&.resource&.id
      output(encounter_id_with_location:)
    end
  end
end
