require 'us_core_test_kit'

module DaVinciCRDTestKit
  class PractitionerRoleReadTest < Inferno::Test
    include USCoreTestKit::ReadTest

    title 'Server returns correct PractitionerRole resource from PractitionerRole read interaction'
    description 'A server SHALL support the PractitionerRole read interaction.'

    id :crd_client_fhir_api_practitioner_role_read_test
    input :practitioner_role_ids,
          title: 'PractitionerRole IDs',
          description: %(
            Comma-delimited list of PractitionerRole IDs for Inferno to use to check
            for PractitionerRole read and search API support. In sum, the resources
            must demonstrate all must support elements. (Note: if Hook tests are run first,
            this will default to PractitionerRole resource IDs referenced in any hook
            invocations sent to Inferno during those tests.)
          )

    def resource_type
      'PractitionerRole'
    end

    def scratch_resources
      scratch[:practitioner_role_resources] ||= {}
    end

    run do
      resources_to_read = practitioner_role_ids.split(',').map do |id|
        FHIR::Reference.new(reference: "PractitionerRole/#{id.strip}")
      end
      resources_to_read.each do |resource|
        read_and_validate(resource)
      end
    end
  end
end
