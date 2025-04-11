module DaVinciCRDTestKit
  class ClientFHIRApiCreateTest < Inferno::Test
    id :crd_client_fhir_api_create_test
    title 'Create Interaction'
    description %(
        Verify that the CRD client supports the create interaction for the given resource. The capabilities required
        by each resource can be found here: https://hl7.org/fhir/us/davinci-crd/CapabilityStatement-crd-client.html#resourcesSummary1
      )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@74'

    input :create_resources,
          type: 'textarea',
          description:
          'Provide a list of resources to create. e.g., [json_resource_1, json_resource_2]'

    def resource_type
      config.options[:resource_type]
    end

    run do
      assert_valid_json(create_resources)
      create_resources_list = JSON.parse(create_resources)
      skip_if(!create_resources_list.is_a?(Array), 'Resources to create not inputted in list format, skipping test.')

      valid_create_resources =
        create_resources_list
          .compact_blank
          .map { |resource| FHIR.from_contents(resource.to_json) }
          .select { |resource| resource.resourceType == resource_type }
          .select { |resource| resource_is_valid?(resource:) }

      skip_if(valid_create_resources.blank?,
              %(No valid #{resource_type} resources were provided to send in Create requests, skipping test.))

      valid_create_resources.each do |create_resource|
        fhir_create(create_resource)
        assert_response_status(201)
      end
    end
  end
end
