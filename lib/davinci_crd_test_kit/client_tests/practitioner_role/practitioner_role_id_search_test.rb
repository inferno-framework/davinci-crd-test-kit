require 'us_core_test_kit'

module DaVinciCRDTestKit
  class PractitionerRoleIdSearchTest < Inferno::Test
    include USCoreTestKit::SearchTest

    title 'Server returns valid results for PractitionerRole search by _id'
    description %(
A server SHALL support searching by
_id on the PractitionerRole resource. This test
will pass if resources are returned and match the search criteria. If
none are returned, the test is skipped.

[US Core Server CapabilityStatement](http://hl7.org/fhir/us/core/STU3.1.1/CapabilityStatement-us-core-server.html)

      )

    id :crd_client_fhir_api_practitioner_role_id_search_test
    def self.properties
      @properties ||= USCoreTestKit::SearchTestProperties.new(
        resource_type: 'PractitionerRole',
        search_param_names: ['_id']
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
    end
  end
end
