require 'us_core_test_kit'

module DaVinciCRDTestKit
  class PractitionerRoleMustSupportTest < Inferno::Test
    include USCoreTestKit::MustSupportTest

    title 'All must support elements are provided in the PractitionerRole resources returned'
    description %(
        US Core Responders SHALL be capable of populating all data elements as
        part of the query results as specified by the US Core Server Capability
        Statement. This test will look through the PractitionerRole resources
        found previously for the following must support elements:

        * PractitionerRole.code
        * PractitionerRole.endpoint
        * PractitionerRole.location
        * PractitionerRole.organization
        * PractitionerRole.practitioner
        * PractitionerRole.specialty
        * PractitionerRole.telecom
        * PractitionerRole.telecom.system
        * PractitionerRole.telecom.value
      )

    id :crd_client_fhir_api_practitioner_role_must_support_test

    def resource_type
      'PractitionerRole'
    end

    def self.metadata
      @metadata ||= USCoreTestKit::Generator::GroupMetadata.new(YAML.load_file(File.join(__dir__, 'metadata.yml'),
                                                                               aliases: true))
    end

    def scratch_resources
      scratch[:practitioner_role_resources] ||= {}
    end

    run do
      perform_must_support_test(all_scratch_resources)
    end
  end
end
