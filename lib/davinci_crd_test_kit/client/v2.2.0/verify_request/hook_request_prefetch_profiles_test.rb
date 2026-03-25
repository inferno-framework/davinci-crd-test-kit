require_relative '../../../cross_suite/hook_request_field_validation'

module DaVinciCRDTestKit
  module V220
    class HookRequestPrefetchProfilesTest < Inferno::Test
      include HookRequestFieldValidation

      id :crd_v220_hook_request_prefetch_profiles
      title 'Prefetched data conforms to required CRD profiles'
      description %(
        As stated in the [CDS hooks specification](https://build.fhir.org/ig/HL7/cds-hooks/en/#http-request-1),
        a CDS service request's `prefetch` field contains key/value pairs of FHIR queries that the service is
        requesting the CDS Client to perform and provide on each service call. The key is a string that describes
        the type of data being requested and the value is a string representing the FHIR query.
        See [Prefetch Template](https://build.fhir.org/ig/HL7/cds-hooks/en/#prefetch-template)
        for more information about how the `prefetch` formatting works.

        [CRD requires support for prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.0/en/foundation.html#prefetch).
        This test verifies that the incoming hook request's `prefetch` field is present and that the provided
        FHIR resources conform to the appropriate CRD profile.
      )
      # verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@54', 'cds-hooks_2.0@30', 'cds-hooks_2.0@47'

      def hook_name
        config.options[:hook_name]
      end

      def crd_test_group
        config.options[:crd_test_group]
      end

      def tags_to_load
        crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
      end

      # TODO: remove when updated to core with a standard version
      def assert_no_error_messages(message = '', message_list: messages)
        assert message_list.none? { |msg| msg[:type] == 'error' },
               message.present? ? message : 'Errors found - see Messages for details.'
      end

      run do
        hook_requests = load_tagged_requests(*tags_to_load)

        skip_if hook_requests.blank?, 'No Hook Requests to verify.'

        hook_requests.each_with_index do |request, request_index|
          @request_index = request_index
          hook_request = JSON.parse(request.request_body)
          next unless hook_request.key?('prefetch')

          hook_request['prefetch'].each do |key, prefetched_resource|
            @prefetch_template = key
            @bundle_entry_index = nil
            check_resource_profile(prefetched_resource)
          end
        end

        assert_no_error_messages('Prefetched resources do not all conform to CRD profiles.')
      end

      def check_resource_profile(prefetched_resource)
        if prefetched_resource['resourceType'] == 'Bundle'
          prefetched_resource['entry']&.each_with_index do |entry, bundle_entry_index|
            @bundle_entry_index = bundle_entry_index
            check_resource_profile(entry['resource']) if entry['resource'].present?
          end
          @bundle_entry_index = nil
        elsif prefetched_resource['resourceType'].present?
          check_non_bundle_resource_profile(prefetched_resource)
        end
      end

      def check_non_bundle_resource_profile(prefetched_resource)
        target_crd_profile = structure_definition_map('v220')[prefetched_resource['resourceType']]
        return unless target_crd_profile.present?

        validation_details = []
        resource_is_valid?(resource: FHIR.from_contents(prefetched_resource.to_json),
                           profile_url: target_crd_profile,
                           validator_response_details: validation_details, add_messages_to_runnable: false)
        validation_details.each do |issue|
          add_message(issue.severity, "#{error_prefix}#{issue.message}")
        end
      end

      def error_prefix
        prefix = "(Request #{@request_index + 1}) Prefetch Template '#{@prefetch_template}'"
        prefix = " #{prefix} Bundle entry #{@bundle_entry_index + 1}" if @bundle_entry_index.present?
        "#{prefix} validation issue - "
      end
    end
  end
end
