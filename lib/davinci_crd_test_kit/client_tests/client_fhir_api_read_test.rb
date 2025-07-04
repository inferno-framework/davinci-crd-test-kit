module DaVinciCRDTestKit
  class ClientFHIRApiReadTest < Inferno::Test
    id :crd_client_fhir_api_read_test
    title 'Read Interaction'
    description %(
        Verify that the CRD client supports the read interaction for the given resource. The capabilities required by
        each resource can be found here: https://hl7.org/fhir/us/davinci-crd/CapabilityStatement-crd-client.html#resourcesSummary1
      )

    input :resource_ids,
          optional: true

    def resource_type
      config.options[:resource_type]
    end

    def no_resources_skip_message
      "No #{resource_type} resource ids were provided, skipping test. "
    end

    def bad_resource_id_message(expected_id)
      "Expected resource to have id: `#{expected_id}`, but found `#{resource.id}`"
    end

    run do
      skip_if resource_ids.blank?, no_resources_skip_message

      resource_id_list = resource_ids.split(',').map(&:strip)
      assert resource_id_list.present?, "No #{resource_type} id provided."

      resource_id_list.each do |resource_id_to_read|
        fhir_read resource_type, resource_id_to_read, tags: [resource_type, 'read']

        assert_response_status(200)
        assert_resource_type(resource_type)
        assert resource.id.present? && resource.id == resource_id_to_read, bad_resource_id_message(resource_id_to_read)
      end
    end
  end
end
