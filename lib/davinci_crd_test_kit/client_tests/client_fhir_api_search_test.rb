module DaVinciCRDTestKit
  class ClientFHIRApiSearchTest < Inferno::Test
    id :crd_client_fhir_api_search_test
    title 'Search Interaction'
    description %(
        Verify that the CRD client supports the specified search interaction for the given resource. The capabilities
        required by each resource can be found here: https://hl7.org/fhir/us/davinci-crd/CapabilityStatement-crd-client.html#resourcesSummary1
      )

    input :search_param_values,
          optional: true

    attr_accessor :successful_search

    def resource_type
      config.options[:resource_type]
    end

    def search_type
      config.options[:search_type]
    end

    def include_searches
      ['organization_include', 'practitioner_include', 'location_include']
    end

    def reference_search_parameters
      ['organization', 'practitioner', 'patient']
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

    def status_search_result_check(bundle, status)
      return if bundle.entry.empty?

      self.successful_search = true

      bundle.entry
        .reject { |entry| entry&.resource&.resourceType == 'OperationOutcome' }
        .map(&:resource)
        .each do |resource|
          assert_resource_type(resource_type, resource:)
          assert(resource.status == status, %(
            Each #{resource_type} resource in search result bundle should have a status of `#{status}`, instead got:
            `#{resource.status}` for resource with id: `#{resource.id}`
            ))
        end
    end

    def check_id_search_result_entry(bundle_entry, search_id, entry_resource_type)
      assert_resource_type(entry_resource_type, resource: bundle_entry)

      assert bundle_entry.id.present?, "Expected id field in returned #{entry_resource_type} resource"

      assert bundle_entry.id == search_id,
             bad_resource_id_message(search_id, bundle_entry.id)
    end

    def id_search_result_check(bundle, search_id)
      warning do
        assert bundle.entry.any?,
               "Search result bundle is empty for #{resource_type} _id search with an id of `#{search_id}`"
      end
      return if bundle.entry.empty?

      self.successful_search = true

      bundle.entry
        .reject { |entry| entry&.resource&.resourceType == 'OperationOutcome' }
        .map(&:resource)
        .each do |resource|
          check_id_search_result_entry(resource, search_id, resource_type)
        end
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
               "Search result bundle is empty for #{resource_type} _include #{search_type} search with an id
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

    def reference_search_result_check(bundle, reference_id, reference_type)
      warning do
        assert bundle.entry.any?, %(
               Search result bundle is empty for #{resource_type} #{reference_type} search with a #{reference_type} id
               `#{reference_id}`
        )
      end
      return if bundle.entry.empty?

      self.successful_search = true

      bundle.entry
        .reject { |entry| entry&.resource&.resourceType == 'OperationOutcome' }
        .map(&:resource)
        .each do |resource|
          assert_resource_type(resource_type, resource:)

          entry_reference_field = get_reference_field(reference_type, resource)
          assert(
            entry_reference_field.present?,
            %(
              #{resource_type} resource with id #{resource.id} did not include the field that references
              a #{reference_type} resource
            )
          )

          entry_reference_id = entry_reference_field.reference_id
          assert(
            entry_reference_id == reference_id,
            %(
              The #{resource_type} resource in search result bundle with id #{resource.id} should have a
              #{reference_type} reference with an id of `#{reference_id}`, instead got: `#{entry_reference_id}`
            )
          )
        end
    end

    run do
      if search_type == 'status'
        coverage_status = ['active', 'cancelled', 'draft', 'entered-in-error']
        coverage_status.each do |status|
          bundle = perform_fhir_search({ status: }, [resource_type, 'status_search'])
          status_search_result_check(bundle, status)
        end
      else
        skip_if search_param_values.blank?, 'No search parameters passed in, skipping test.'

        search_id_list = search_param_values.split(',').map(&:strip)
        search_id_list.each do |search_id|
          if search_type == '_id'
            bundle = perform_fhir_search({ _id: search_id }, [resource_type, 'id_search'])
            id_search_result_check(bundle, search_id)
          elsif reference_search_parameters.include?(search_type)
            search_params = {}
            search_params[search_type] = search_id
            bundle = perform_fhir_search(search_params, [resource_type, "#{search_type}_search"])
            reference_search_result_check(bundle, search_id, search_type)
          elsif include_searches.include?(search_type)
            include_resource_type = search_type.gsub('_include', '')
            bundle = perform_fhir_search({ _id: search_id, _include: "#{resource_type}:#{include_resource_type}" },
                                         [resource_type, "include_#{include_resource_type}_search"])
            include_search_result_check(bundle, search_id, include_resource_type)
          else
            raise StandardError,
                  'Passed in search_type does not match to any of the search types handled by this search test.'
          end
        end
      end
      skip_if !successful_search,
              'No resources returned in any of the search result bundles.'
    end
  end
end
