require_relative '../../../cross_suite/fhirpath_on_cds_request'
require_relative '../../../cross_suite/replace_tokens'

module DaVinciCRDTestKit
  module V220
    class HookRequestValidPrefetchTest < Inferno::Test
      id :crd_v220_hook_request_valid_prefetch
      title 'Hook request contains valid prefetched data'
      description %(
        As stated in the [CDS hooks specification](https://cds-hooks.hl7.org/2.0#http-request), a CDS service request's
        `prefetch` field is an optional field that contains key/value pairs of FHIR queries that the service is
        requesting the CDS Client to perform and provide on each service call. The key is a string that describes
        the type of data being requested and the value is a string representing the FHIR query.
        See [Prefetch Template](https://cds-hooks.hl7.org/2.0#prefetch-template)
        for more information about how the `prefetch` formatting works.

        This test verifies that the incoming hook request's `prefetch` field is in a valid JSON format,
        validates each contained resource against its corresponding CRD resource profile, and checks
        that the data matches what is requested in by the
        [prefetch templates published by Inferno's simulated CRD Server](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.0/cds-services-v220.json).
        In CRD 2.2.0, prefetch support is required, and clients must be able to return all data in the standard
        prefetch templates, which are used by Inferno. Thus, this test checks that exactly the requested
        data is present.
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

      def assert_no_error_messages(message = '')
        assert messages.none? { |msg| msg[:type] == 'error' },
               message.present? ? message : 'Errors found - see Messages for details.'
      end

      run do
        hook_requests = load_tagged_requests(*tags_to_load)

        skip_if hook_requests.blank?, 'No Hook Requests to verify.'

        hook_requests.each_with_index do |request, request_index|
          hook_request = JSON.parse(request.request_body)
          PrefetchChecker.new(hook_request, request_index).check_prefetched_data.each do |error|
            add_message('error', error)
          end
        end

        assert_no_error_messages('Prefetch is not valid.')
      end

      # -----------------------------------------------------------------------
      # Prefetch Check Helper Class
      # -----------------------------------------------------------------------
      class PrefetchChecker
        include FhirpathOnCDSRequest
        include ReplaceTokens

        attr_accessor :hook_request, :request_index

        def initialize(hook_request, request_index)
          @hook_request = hook_request
          @request_index = request_index
          extract_prefetched_resources
        end

        def check_prefetched_data
          hook_prefetch_templates.each do |prefetch_key, prefetch_request|
            @current_prefetch_key = prefetch_key
            instantiated_request = replace_tokens_in_string(prefetch_request, hook_request)
            provided_prefetch = hook_request.dig('prefetch', prefetch_key)
            check_provided_against_request(provided_prefetch, instantiated_request)
          end

          errors
        end

        private

        # -----------------------------------------------------------------------
        # Errors to return
        # -----------------------------------------------------------------------
        def errors
          @errors ||= []
        end

        def error_prefix
          "(Request #{request_index + 1}) Prefetch Key #{@current_prefetch_key} -"
        end

        # -----------------------------------------------------------------------
        # Requested Prefetch Templates
        # -----------------------------------------------------------------------
        def hook_prefetch_templates
          @hook_prefetch_templates ||=
            JSON.parse(File.read(File.join(__dir__, '..', 'cds-services-v220.json')))['services'].find do |service|
              service['hook'] == hook_request['hook']
            end['prefetch']
        end

        # -----------------------------------------------------------------------
        # Check of actual prefetch against an instantiated request
        # -----------------------------------------------------------------------
        def check_provided_against_request(prefetched_value, instantiated_request)
          if instantiated_request.include?('?')
            if id_search?(instantiated_request)
              check_id_search(prefetched_value, instantiated_request)
            elsif instantiated_request.starts_with?('Coverage')
              check_coverage_search(prefetched_value, instantiated_request)
            else
              # TODO: better error handling for this case - or maybe none since we control the prefetches
              errors << "#{error_prefix} unexpected search template: #{instantiated_request}."
            end
          else
            check_read(prefetched_value, instantiated_request)
          end
        end

        def id_search?(request_string)
          resource_type = request_string.split('?').first
          request_string.starts_with?("#{resource_type}?_id=")
        end

        def check_coverage_search(prefetched_value, _instantiated_request)
          check_is_fhir_resource(prefetched_value)
          check_is_target_resource_type(prefetched_value, 'Bundle') if prefetched_value.key?('resourceType')
          unless prefetched_value['entry'].size == 1
            errors << "#{error_prefix} only one Coverage must be provided."
            return
          end

          prefetched_coverage = prefetched_value.dig('entry', 0, 'resource')

          unless prefetched_coverage['resourceType'].present?
            errors << "#{error_prefix} entry in prefetched Coverage Bundle is not a FHIR resource (no resourceType)."
            return
          end

          unless prefetched_coverage['resourceType'] == 'Coverage'
            errors << "#{error_prefix} entry in prefetched Coverage Bundle has an unexpected type: " \
                      "expected Coverage, got #{prefetched_coverage['resourceType']}."
            return
          end

          unless prefetched_coverage['status'] == 'active'
            errors << "#{error_prefix} prefetched Coverage has an unexpected status: " \
                      "expected active, got #{prefetched_coverage['status']}."
          end

          target_patient_id = hook_request.dig('context', 'patientId')
          unless prefetched_coverage.dig('beneficiary', 'reference') == "Patient/#{target_patient_id}"
            errors << "#{error_prefix} prefetched Coverage has an unexpected beneficiary reference: " \
                      "expected Patient/#{target_patient_id}, got #{prefetched_coverage.dig('beneficiary',
                                                                                            'reference')}."
          end

          nil
        end

        def check_read(prefetched_value, instantiated_request)
          resource_type, resource_id = instantiated_request.split('/')

          check_is_fhir_resource(prefetched_value)
          check_is_target_resource_type(prefetched_value, resource_type) if prefetched_value.key?('resourceType')
          unless prefetched_value.key?('id')
            errors << "#{error_prefix} prefetched resource is missing an id."
            return
          end
          unless prefetched_value['id'] == resource_id
            errors << "#{error_prefix} prefetched value has unexpected id: " \
                      "expected #{resource_id}, got #{prefetched_value['id']}."
          end

          nil
        end

        def check_id_search(prefetched_value, instantiated_request)
          check_is_fhir_resource(prefetched_value)
          check_is_target_resource_type(prefetched_value, 'Bundle') if prefetched_value.key?('resourceType')

          resource_type, id_list = instantiated_request.split('?_id=')
          check_bundle_entry_resource_type(prefetched_value, resource_type)

          target_ids = id_list.present? ? id_list.split(',').map { |id| "#{resource_type}/#{id}" }.uniq.sort : []
          check_ids(target_ids, actual_ids(prefetched_value))
          nil
        end

        def actual_ids(prefetched_value)
          if prefetched_value['entry'].present?
            prefetched_value['entry'].map do |entry|
              type = entry.dig('resource', 'resourceType')
              id = entry.dig('resource', 'id')
              "#{type}/#{id}" if type.present? && id.present?
            end.compact
          else
            []
          end
        end

        def check_ids(target_ids, actual_ids)
          actual_ids_no_dups = actual_ids.compact.uniq
          unless actual_ids.size == actual_ids_no_dups.size
            errors << "#{error_prefix} prefetched Bundle has multiple entries with the same resource id."
          end

          missing_ids = target_ids - actual_ids
          if missing_ids.present?
            errors << "#{error_prefix} prefetched Bundle missing expected entries: " \
                      "#{missing_ids.join('\', \'')}."
          end
          extra_ids = actual_ids - target_ids
          return unless extra_ids.present?

          errors << "#{error_prefix} prefetched Bundle includes unrequested entries: " \
                    "#{extra_ids.join('\', \'')}."
        end

        def check_bundle_entry_resource_type(bundle, target_resource_type)
          bundle['entry']&.each_with_index do |entry, index|
            entry_resource_type = entry.dig('resource', 'resourceType')
            next if entry_resource_type == target_resource_type

            errors << if entry_resource_type.present?
                        "#{error_prefix} prefetched Bundle entry #{index + 1} has an unexpected resourceType: " \
                          "expected #{target_resource_type}, got #{entry_resource_type}."
                      else
                        "#{error_prefix} prefetched Bundle entry #{index + 1} is not a FHIR resource (no resourceType)."
                      end
          end
        end

        def check_is_fhir_resource(prefetched_value)
          return if prefetched_value.key?('resourceType')

          errors << "#{error_prefix} prefetched value is not a FHIR resource (no resourceType)."
        end

        def check_is_target_resource_type(prefetched_value, target_resource_type)
          return if prefetched_value['resourceType'] == target_resource_type

          errors << "#{error_prefix} prefetched value has unexpected resourceType: " \
                    "expected #{target_resource_type}, got #{prefetched_value['resourceType']}."
        end

        # -----------------------------------------------------------------------
        # Map of prefetched resources by refernce
        # -----------------------------------------------------------------------
        def prefetched_resources
          @prefetched_resources ||= {}
        end

        def extract_prefetched_resources
          hook_request['prefetch']&.each_value do |prefetch_resource|
            next unless prefetch_resource['resourceType'].present?

            if prefetch_resource['resourceType'] == 'Bundle'
              extract_resources_from_prefetched_bundle(prefetch_resource)
            else
              extract_prefetched_resource_instance(prefetch_resource)
            end
          end
        end

        def extract_resources_from_prefetched_bundle(bundle)
          bundle['entry']&.each do |entry|
            next unless entry.dig('resource', 'resourceType').present?

            # TODO: assuming relative references
            extract_prefetched_resource_instance(entry['resource'])
          end
        end

        def extract_prefetched_resource_instance(resource_instance)
          return unless resource_instance['id'].present?

          key = "#{resource_instance['resourceType']}/#{resource_instance['id']}"
          return if prefetched_resources.key?(key)

          prefetched_resources[key] = resource_instance
        end

        # -------------------------------------------------------------------------
        # fhirpath resolve() handling
        # -------------------------------------------------------------------------

        def resolve(reference)
          key = reference.is_a?(Hash) ? reference['reference'] : reference
          return nil unless key.present?
          # TODO: assuming relative references
          return prefetched_resources[key] if prefetched_resources.key?(key)

          errors << "#{error_prefix} resource '#{key}' needed to instantiate the query " \
                    'was not provided in the prefetched values.'

          nil
        end
      end
    end
  end
end
