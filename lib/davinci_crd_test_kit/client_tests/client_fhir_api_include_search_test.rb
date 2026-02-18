module DaVinciCRDTestKit
  class ClientFHIRApiIncludeSearchTest < Inferno::Test
    id :crd_client_fhir_api_include_search_test
    title 'Search Interaction'
    description %(
        Verify that the CRD client supports the `_include` directive targeting
        the specified element on searches for the resource type.
      )

    input :search_id,
          optional: true

    def resource_type
      config.options[:resource_type]
    end

    def target_include_element
      config.options[:target_include_element]
    end

    def perform_fhir_search(search_params, tags)
      fhir_search(resource_type, params: search_params, tags:)
      assert_response_status(200)
      assert_resource_type(:bundle)
      resource
    end

    def include_search_result_check(bundle, search_id, included_resource_type) # rubocop:disable Metrics/CyclomaticComplexity
      skip_if bundle.entry.blank?,
              "_include search not demonstrated - search result bundle is empty for #{resource_type} " \
              "_include #{target_include_element} search with an id of `#{search_id}`."

      searched_resource_entry = bundle.entry.find do |entry|
        entry&.resource&.resourceType == resource_type && entry&.resource&.id == search_id
      end
      assert(searched_resource_entry.present?,
             "The #{included_resource_type} _include search for #{resource_type} resource with id #{search_id} " \
             "did not return a #{resource_type} resource matching the searched id #{search_id}.")

      searched_resource = searched_resource_entry.resource
      base_resource_references = Array.wrap(get_reference_field(included_resource_type, searched_resource)).compact
      skip_if base_resource_references.blank?,
              "#{resource_type} resource with id #{searched_resource.id} did not include references in " \
              "the element targeted to include #{included_resource_type} resources."

      base_resource_references.each do |include_target|
        target_resource_type, target_id =
          if include_target.reference.include?('/')
            include_target.reference.split('/')
          else
            [included_resource_type, include_target.reference]
          end

        target_entry = bundle.entry.find do |entry|
          entry&.resource&.resourceType == target_resource_type && entry&.resource&.id == target_id
        end

        assert target_entry.present?,
               "referenced resource `#{target_resource_type}/#{target_id}` not returned from the search"
      end

      returned_resources = bundle.entry
        .map(&:resource)
        .select { |resource| resource.present? && resource.resourceType != 'OperationOutcome' }
      warning do
        assert returned_resources.length == base_resource_references.length + 1,
               'Additional resources returned beyond those requested. While servers are allowed ' \
               'to return additional resources that they deem to be relevant, this may be an indication ' \
               'that the server is not correctly filtering results.'
      end
    end

    def get_reference_field(reference_type, entry)
      case reference_type
      when 'practitioner'
        entry.practitioner
      when 'organization'
        if resource_type == 'Encounter'
          entry.serviceProvider
        else
          entry.organization
        end
      when 'location'
        locations = entry.location
        locations&.map(&:location)
      end
    end

    run do
      skip_if search_id.blank?, 'No target id to use for the search, skipping test.'

      bundle = perform_fhir_search({ _id: search_id, _include: "#{resource_type}:#{target_include_element}" },
                                   [resource_type, "include_#{target_include_element}_search"])
      include_search_result_check(bundle, search_id, target_include_element)
    end
  end
end
