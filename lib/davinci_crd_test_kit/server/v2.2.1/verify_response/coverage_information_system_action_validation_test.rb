require_relative '../../server_hook_request_validation'
require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'

module DaVinciCRDTestKit
  module V221
    class CoverageInformationSystemActionValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookRequestValidation
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper

      COVERAGE_INFO_EXT_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'.freeze

      title 'All Coverage Information system actions received are valid'
      id :crd_v221_coverage_info_system_action_validation
      description %(
        This test validates all [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
        system actions received. It verifies the following for each action:
        - The action type is `update`.
        - The resource within the action conforms its respective FHIR profile.
        - The resource does not change any data elements other than adding or modifying
          the `coverage-information` extension.

        Additionally, the test examines the `coverage-info` extensions within the resource to ensure that:
        - Entries referencing differing coverage have distinct `coverage-assertion-ids` and `satisfied-pa-ids`
        (if present).
        - Entries referencing the same coverage have the same `coverage-assertion-ids` and `satisfied-pa-ids`
        (if present).
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-32',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-37',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-47',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-48',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-52'

      input :coverage_info
      input :mock_ehr_bundle, optional: true

      def find_extension_value(extension, url, *properties)
        found_extension = extension.extension.find { |ext| ext.url == url }
        return nil unless found_extension

        properties.reduce(found_extension) do |current, prop|
          return current unless current.respond_to?(prop)

          current.send(prop)
        end
      end

      def extract_and_group_coverage_info(resource)
        resource.extension.each_with_object({}) do |extension, grouped_extensions|
          next unless extension.url == COVERAGE_INFO_EXT_URL

          coverage_key = find_extension_value(extension, 'coverage', 'valueReference', 'reference')
          grouped_extensions[coverage_key] ||= []
          grouped_extensions[coverage_key] << extension
        end
      end

      # For the same coverage, ensure coverage-assertion-ids and satisfied-pa-ids are the same.
      # For different coverages, ensure coverage-assertion-ids and satisfied-pa-ids are distinct.
      def multiple_extensions_conformance_check(grouped_coverage_info, resource)
        resource_ref = "#{resource.resourceType}/#{resource.id}"
        assertion_ids_across_coverages = Set.new
        pa_ids_across_coverages = Set.new

        grouped_coverage_info.each do |coverage, extensions|
          coverage_assertion_ids = collect_extensions_id(extensions, 'coverage-assertion-id', 'valueString').uniq
          satisfied_pa_ids = collect_extensions_id(extensions, 'satisfied-pa-id', 'valueString').uniq.compact
          assert coverage_assertion_ids.length == 1,
                 same_coverage_conformance_error_msg(resource_ref, coverage, 'coverage-assertion-ids')

          assert satisfied_pa_ids.length <= 1,
                 same_coverage_conformance_error_msg(resource_ref, coverage, 'satisfied-pa-ids')

          assertion_id = coverage_assertion_ids.first
          assert !assertion_ids_across_coverages.include?(assertion_id),
                 different_coverage_conformance_error_msg(resource_ref, 'coverage-assertion-ids')
          assertion_ids_across_coverages.add(assertion_id)
          pa_id = satisfied_pa_ids.first
          next unless pa_id

          assert !pa_ids_across_coverages.include?(pa_id),
                 different_coverage_conformance_error_msg(resource_ref, 'satisfied-pa-ids')
          pa_ids_across_coverages.add(pa_id)
        end
      end

      def collect_extensions_id(extensions, url, *properties)
        extensions.map do |extension|
          find_extension_value(extension, url, *properties)
        end
      end

      def same_coverage_conformance_error_msg(resource_ref, coverage, id_name)
        "#{resource_ref}: extension has multiple repetitions of coverage `#{coverage}` with different #{id_name}."
      end

      def different_coverage_conformance_error_msg(resource_ref, id_name)
        "#{resource_ref}: extensions referencing differing coverage SHALL have distinct #{id_name}."
      end

      def reference_parts(reference)
        return if reference.blank?

        parts = reference.split('/')
        return unless parts.length >= 2

        [parts[-2], parts[-1]]
      end

      def matching_request_for_action(action)
        requests.find do |request|
          response = JSON.parse(request.response_body)
          request.status == 200 && Array(response['systemActions']).any? { |candidate| candidate == action }
        rescue JSON::ParserError
          false
        end
      end

      def parse_bundle(bundle_hash)
        bundle = FHIR.from_contents(bundle_hash.to_json)
        bundle if bundle.is_a?(FHIR::Bundle)
      rescue StandardError
        nil
      end

      def find_resource_in_bundle(bundle_hash, target_type, target_id)
        bundle = parse_bundle(bundle_hash)
        return unless bundle&.entry

        bundle.entry
          .filter_map(&:resource)
          .find { |resource| resource.resourceType == target_type && resource.id == target_id }
      end

      def find_resource_in_prefetch(request_body, target_type, target_id)
        Array(request_body['prefetch']&.values).each do |prefetched_value|
          if prefetched_value.is_a?(Hash) &&
             prefetched_value['resourceType'] == target_type &&
             prefetched_value['id'] == target_id
            return FHIR.from_contents(prefetched_value.to_json)
          end

          resource = find_resource_in_bundle(prefetched_value, target_type, target_id)
          return resource if resource
        end

        nil
      end

      def mock_ehr_bundle_resource
        @mock_ehr_bundle_resource ||= JSON.parse(mock_ehr_bundle) if mock_ehr_bundle.present?
      rescue JSON::ParserError
        nil
      end

      def appointment_based_on_matches_target?(appointment, target_type, target_id)
        Array(appointment.basedOn).any? do |reference|
          reference_parts(reference.reference) == [target_type, target_id]
        end
      end

      def appointment_book_service_request(request_body, appointments_bundle_hash, target_id)
        target_type = 'ServiceRequest'
        appointments_bundle = parse_bundle(appointments_bundle_hash)
        appointment = Array(appointments_bundle&.entry)
          .filter_map(&:resource)
          .find { |candidate| appointment_based_on_matches_target?(candidate, target_type, target_id) }
        return unless appointment

        find_resource_in_prefetch(request_body, target_type, target_id) ||
          find_resource_in_bundle(mock_ehr_bundle_resource, target_type, target_id)
      end

      def find_appointment_book_resource(request_body, target_type, target_id)
        appointments_bundle = request_body.dig('context', 'appointments')
        find_resource_in_bundle(appointments_bundle, target_type, target_id) ||
          appointment_book_service_request(request_body, appointments_bundle, target_id)
      end

      def find_draft_orders_resource(request_body, target_type, target_id)
        draft_orders_bundle = request_body.dig('context', 'draftOrders')
        find_resource_in_bundle(draft_orders_bundle, target_type, target_id)
      end

      def hook_context_resource(request_body, target_type, target_id)
        case tested_hook_name
        when 'appointment-book'
          find_appointment_book_resource(request_body, target_type, target_id)
        when 'order-sign', 'order-select'
          find_draft_orders_resource(request_body, target_type, target_id)
        end
      end

      def parse_request_body(request)
        return unless request&.request_body.present?

        JSON.parse(request.request_body)
      rescue JSON::ParserError
        nil
      end

      def fallback_source_resource(request_body, target_type, target_id)
        find_resource_in_prefetch(request_body, target_type, target_id) ||
          find_resource_in_bundle(mock_ehr_bundle_resource, target_type, target_id)
      end

      # Resolve the original resource being updated by this systemAction.
      # - appointment-book: look in context.appointments; if the action targets a ServiceRequest,
      #   follow the Appointment basedOn reference and resolve that from prefetch or mock EHR data
      # - order-sign/order-select: look in context.draftOrders
      # - other hooks: resolve from prefetch or mock EHR data because context may carry only ids/references
      def find_action_source_resource(action, request)
        action_resource = action['resource']
        return unless action_resource.is_a?(Hash)

        target_type = action_resource['resourceType']
        target_id = action_resource['id']
        request_body = parse_request_body(request)
        return unless target_type.present? && target_id.present? && request_body

        hook_context_resource(request_body, target_type, target_id) ||
          fallback_source_resource(request_body, target_type, target_id)
      end

      def normalize_value(value)
        case value
        when Hash
          value.transform_values { |child| normalize_value(child) }
        when Array
          value.map { |child| normalize_value(child) }.sort_by(&:to_json)
        else
          value
        end
      end

      def strip_coverage_info_extensions(resource_hash)
        normalized_hash = resource_hash.deep_dup
        return normalized_hash unless normalized_hash['extension'].is_a?(Array)

        normalized_hash['extension'] = normalized_hash['extension'].reject do |extension|
          extension['url'] == COVERAGE_INFO_EXT_URL
        end
        normalized_hash.delete('extension') if normalized_hash['extension'].empty?
        normalized_hash
      end

      def verify_only_coverage_info_changed(action)
        request = matching_request_for_action(action)
        source_resource = find_action_source_resource(action, request)
        updated_resource_hash = action['resource']
        resource_ref = "#{updated_resource_hash['resourceType']}/#{updated_resource_hash['id']}"
        unless source_resource
          messages << {
            type: 'warning',
            message: 'Inferno could not resolve the original source resource for Coverage Information systemAction ' \
                     "targeting #{resource_ref}, so it could not verify that only coverage-information extensions " \
                     'were changed.'
          }
          return
        end

        source_resource_hash = source_resource.to_hash

        source_without_coverage_info = normalize_value(strip_coverage_info_extensions(source_resource_hash))
        updated_without_coverage_info = normalize_value(strip_coverage_info_extensions(updated_resource_hash))

        assert source_without_coverage_info == updated_without_coverage_info,
               "#{resource_ref}: resource content changed outside the coverage-information extension."
      end

      def coverage_info_system_action_check(coverage_info_system_action)
        type = coverage_info_system_action['type']
        assert type, '`type` field is missing.'
        assert type == 'update', "`type` must be `update`, but was `#{type}`"

        resource = FHIR.from_contents(coverage_info_system_action['resource'].to_json)
        profile_url = structure_definition_map('v221')[resource.resourceType]
        assert_valid_resource(resource:, profile_url:)

        grouped_coverage_info = extract_and_group_coverage_info(resource)
        multiple_extensions_conformance_check(grouped_coverage_info, resource)
        verify_only_coverage_info_changed(coverage_info_system_action)
      end

      run do
        load_tagged_requests(tested_hook_name)
        parsed_coverage_info = parse_json(coverage_info)
        error_messages = []
        parsed_coverage_info.each do |action|
          coverage_info_system_action_check(action)
        rescue Inferno::Exceptions::AssertionException => e
          error_messages << "Coverage Info system action `#{action}`: #{e.message}"
        end

        error_messages.each do |msg|
          messages << { type: 'error', message: msg }
        end
        assert error_messages.empty?, 'Some Coverage Info system actions are not valid.'
      end
    end
  end
end
