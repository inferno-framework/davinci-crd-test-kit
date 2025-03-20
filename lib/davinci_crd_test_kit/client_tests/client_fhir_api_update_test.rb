module DaVinciCRDTestKit
  class ClientFHIRApiUpdateTest < Inferno::Test
    id :crd_client_fhir_api_update_test
    title 'Update Interaction'
    description %(
        Verify that the CRD client supports the update interaction for the given resource. The capabilities required by
        each resource can be found here: https://hl7.org/fhir/us/davinci-crd/CapabilityStatement-crd-client.html#resourcesSummary1
      )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@74'

    input :update_resources,
          type: 'textarea',
          description:
          'Provide a list of resources to update. e.g., [json_resource_1, json_resource_2]'

    def resource_type
      config.options[:resource_type]
    end

    run do
      assert_valid_json(update_resources)
      update_resources_list = JSON.parse(update_resources)
      skip_if(!update_resources_list.is_a?(Array), 'Resources to update not inputted in list format, skipping test.')

      valid_update_resources =
        update_resources_list
          .compact_blank
          .map { |resource| FHIR.from_contents(resource.to_json) }
          .select { |resource| resource.resourceType == resource_type }
          .select { |resource| resource_is_valid?(resource:) }

      skip_if(valid_update_resources.blank?,
              %(No valid #{resource_type} resources were provided to send in Update requests, skipping test.))

      valid_update_resources.each do |update_resource|
        fhir_update(update_resource, update_resource.id)
        assert_response_status([200, 201])
      end
    end
  end
end
