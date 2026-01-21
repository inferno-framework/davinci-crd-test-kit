module DaVinciCRDTestKit
  class ClientFHIRApiIncludeSearchTest < Inferno::Test
    id :crd_client_fhir_api_include_search_test
    title 'Search Interaction'
    description %(
        Verify that the CRD client supports the `_include` directive targeting
        the specified element on searches for the resource type.
      )

    input :search_ids,
          optional: true

    attr_accessor :successful_search

    def resource_type
      config.options[:resource_type]
    end

    def target_include_element
      config.options[:target_include_element]
    end

    def bad_resource_id_message(expected_id, actual_id)
      "Expected resource to have id: `#{expected_id}`, but found `#{actual_id}`"
    end

    def perform_fhir_search(search_params, tags)
      fhir_search(resource_type, params: search_params, tags:)
      assert_response_status(200)
      assert_resource_type(:bundle)
      resource
    end

    def check_id_search_result_entry(bundle_entry, search_id, entry_resource_type)
      assert_resource_type(entry_resource_type, resource: bundle_entry)

      assert bundle_entry.id.present?, "Expected id field in returned #{entry_resource_type} resource"

      assert bundle_entry.id == search_id,
             bad_resource_id_message(search_id, bundle_entry.id)
    end

    def check_include_reference(base_resource_entry, include_resource_id, include_resource_type)
      base_resource_references = Array.wrap(get_reference_field(include_resource_type, base_resource_entry)).compact

      assert(base_resource_references.present?, %(
             #{resource_type} resource with id #{base_resource_entry.id} did not include the field that references a
             #{include_resource_type} resource}
             ))

      base_resource_reference_match_found = base_resource_references.any? do |base_resource_reference|
        base_resource_reference.reference_id == include_resource_id
      end

      assert(base_resource_reference_match_found, %(
        The #{resource_type} resource in search result bundle with id #{base_resource_entry.id} did not have a
        #{include_resource_type} reference with an id of `#{include_resource_id}`.`
      ))
    end

    def include_search_result_check(bundle, search_id, included_resource_type) # rubocop:disable Metrics/CyclomaticComplexity
      warning do
        assert bundle.entry.any?,
               "Search result bundle is empty for #{resource_type} _include #{target_include_element} search with an id
               of `#{search_id}`"
      end
      return if bundle.entry.empty?

      self.successful_search = true

      base_resource_entry_list = bundle.entry.select do |entry|
        entry.resource&.resourceType == resource_type
      end

      assert(base_resource_entry_list.length == 1, %(
        The #{included_resource_type} _include search for #{resource_type} resource with id #{search_id}
        should include exactly 1 #{resource_type} resource, instead got #{base_resource_entry_list.length}.
      ))

      base_resource_entry = base_resource_entry_list.first.resource

      bundle.entry
        .map(&:resource)
        .each do |resource|
          entry_resource_type = resource.resourceType

          if entry_resource_type == resource_type
            check_id_search_result_entry(resource, search_id, entry_resource_type)
          elsif entry_resource_type != 'OperationOutcome'
            entry_resource_type = included_resource_type.capitalize
            assert_resource_type(entry_resource_type, resource:)

            included_resource_id = resource.id
            assert included_resource_id.present?, "Expected id field in returned #{entry_resource_type} resource"
            check_include_reference(base_resource_entry, included_resource_id, included_resource_type)
          end
        end
    end

    def get_reference_field(reference_type, entry)
      case reference_type
      when 'patient'
        entry.beneficiary
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
        locations.map(&:location)
      end
    end

    run do
      skip_if search_ids.blank?, 'No search parameters passed in, skipping test.'

      search_id_list = search_ids.split(',').map(&:strip)
      search_id_list.each do |search_id|
        bundle = perform_fhir_search({ _id: search_id, _include: "#{resource_type}:#{target_include_element}" },
                                     [resource_type, "include_#{target_include_element}_search"])
        include_search_result_check(bundle, search_id, target_include_element)
      end

      skip_if !successful_search, '_include search response not demonstrated.'
    end
  end
end
