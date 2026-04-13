require 'us_core_test_kit'

module DaVinciCRDTestKit
  class PractitionerRoleOrganizationSearchTest < Inferno::Test
    include USCoreTestKit::SearchTest

    title 'Server returns valid results for PractitionerRole search by organization'
    description %(
A server SHALL support searching by
organization on the PractitionerRole resource. This test
will pass if resources are returned and match the search criteria. If
none are returned, the test is skipped.

[US Core Server CapabilityStatement](http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html)

      )

    id :crd_client_fhir_api_practitioner_role_organization_search_test

    output :practitioner_role_id_with_organization
    def self.properties
      @properties ||= USCoreTestKit::SearchTestProperties.new(
        resource_type: 'PractitionerRole',
        search_param_names: ['organization']
      )
    end

    def self.metadata
      @metadata ||= USCoreTestKit::Generator::GroupMetadata.new(YAML.load_file(File.join(__dir__, 'metadata.yml'),
                                                                               aliases: true))
    end

    def scratch_resources
      scratch[:practitioner_role_resources] ||= {}
    end

    run do
      run_search_test
      return unless requests.present?

      search_response_bundle = FHIR.from_contents(requests[0].response_body)
      return unless search_response_bundle.is_a?(FHIR::Bundle)

      practitioner_role_id_with_organization = search_response_bundle.entry&.first&.resource&.id
      output(practitioner_role_id_with_organization:)
    end
  end
end
