require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientCoverageInfoUpdateTest < Inferno::Test
      include CardsIdentification
      include TaggedRequestLoadHelper

      title "Client's FHIR server stores updates from coverage-information responses"
      id :crd_v221_client_coverage_info_update
      description <<~DESCRIPTION
        This test verifies that when the client receives a [Coverage Information response type](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type),
        it stores the [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        and makes it available when accessing the associated resource.

        During this test, Inferno will find all [Coverage Information responses](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type),
        attempt to read the updated FHIR resource from the client's FHIR server, and verify
        that the [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        in the response is now present in the returned resource. When comparing the
        [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        in the response with what is returned from the client FHIR server, Inferno
        expects that client stores and exposes the extension without modification, meaning
        that the exact set of sub-extensions in the response and their values are present
        in the stored version.

        Inferno will not always be able to perform this check. CRD clients are not required
        to expose FHIR read APIs for all request resource types, so resource types for which
        the client's CapabilityStatement does not indicate read interaction support will be omitted.
        Additionally, Inferno will not check complex cases where determining the expected
        stored extensions is difficult. For example, when there are multiple Coverage Information
        responses for a single resource or multiple coverage-information extensions in a
        single Coverage Information response. Implementers are still responsible for storing updates
        in these cases. To pass this test at least one target resource that Inferno can access must be found.
        The stored [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        must be correct for all resources checked by Inferno.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-36-B', 'hl7.fhir.us.davinci-crd_2.2.1@resp-46'

      uses_request :capability_statement

      run do
        supported_resource_types = extract_supported_resource_types(resource) # extract before loading other requests

        loaded_requests = requests_to_analyze # all requests for one hook or all requests for all hooks
        skip_if loaded_requests.blank?, 'No hook requests found, run hook tests first.'

        resources_to_check, unsupported = find_coverage_info_responses(loaded_requests)
          .partition { |request_details| supported_resource_types.include?(request_details[:resource_type]) }
        unsupported.each do |request_details|
          add_message('info', "#{error_prefix(request_details)}Resource type #{request_details[:resource_type]} " \
                              'is not supported by the client\'s FHIR API. This resource will not be verified.')
        end
        skip_if resources_to_check.blank?,
                'No coverage-info responses found that Inferno could verify: ' \
                're-run hook tests generating responses that Inferno can verify.'

        resources_to_check.each do |resource_details|
          check_for_stored_coverage_information_extension(resource_details)
        end

        assert_no_error_messages('Not all coverage-information extensions stored. See Messages for details.')
      end

      # important information to record:
      # - relative resource reference (resource type + id)
      # - coverage-information extension
      # - position (response index + systemAction index)
      def find_coverage_info_responses(requests)
        all_responses = requests.flat_map.with_index do |request, request_index|
          find_coverage_info_actions_in_response(request, request_index)
        end

        all_responses.group_by { |resource_details| [resource_details[:resource_type], resource_details[:target_id]] }
          .filter_map do |(_type, _id), entries|
            if entries.size > 1
              add_message('info',
                          "#{error_prefix(entries.first)}Multiple coverage-info responses found. Due to the " \
                          'complexity of determining the expected state, this resource will not be verified.')
              next
            end

            if entries.first[:coverage_information_extensions].size > 1
              add_message('info',
                          "#{error_prefix(entries.first)}Multiple coverage-information extensions found. Due to the " \
                          'complexity of determining the expected state, this resource will not be verified.')
              next
            end

            entries.first
          end
      end

      def find_coverage_info_actions_in_response(request, request_index)
        response = JSON.parse(request.response_body)
        return [] unless response.is_a?(Hash) && response.key?('systemActions')

        response['systemActions'].map.with_index do |action, action_index|
          if coverage_information_response_type?(action)
            extract_coverage_information_details(action, action_index, request_index)
          end
        end.compact
      rescue JSON::ParserError
        [] # no responses to check, error registered elsewhere
      end

      def extract_coverage_information_details(action, action_index, request_index)
        {
          request_index:,
          action_index:,
          resource_type: action.dig('resource', 'resourceType'),
          target_id: action.dig('resource', 'id'),
          coverage_information_extensions: FHIR.from_contents(action['resource'].to_json).extension.select do |ext|
                                             ext.url == COVERAGE_INFO_EXT_URL
                                           end
        }
      end

      def extract_supported_resource_types(capability_statement)
        return [] unless capability_statement.rest.is_a?(Array)

        capability_statement.rest.select { |rest| rest.mode == 'server' }.flat_map do |rest|
          next [] unless rest.resource.is_a?(Array)

          rest.resource.select do |resource|
            supports_read?(resource)
          end.flat_map(&:type).compact
        end.uniq
      end

      def supports_read?(resource)
        resource.interaction&.any? do |interaction|
          interaction.code == 'read'
        end
      end

      def check_for_stored_coverage_information_extension(resource_details)
        fhir_read resource_details[:resource_type], resource_details[:target_id]
        unless resource.present? && resource.resourceType == resource_details[:resource_type]
          add_message('error', "#{error_prefix(resource_details)}Unable to read target resource.")
          return
        end

        stored_extensions = resource.extension.select { |ext| ext.url == COVERAGE_INFO_EXT_URL }
        if stored_extensions.blank?
          add_message('error', "#{error_prefix(resource_details)}coverage-information extension(s) not stored.")
          return
        end

        difference_string = coverage_info_extension_differences(
          resource_details[:coverage_information_extensions],
          stored_extensions
        )
        return unless difference_string.present?

        add_message('error', "#{error_prefix(resource_details)}#{difference_string}.")
      end

      def coverage_info_extension_differences(expected, actual)
        raise ArgumentError, 'expected must contain exactly one coverage-information extension' if expected.size != 1

        if expected.size != actual.size
          return "Expected #{expected.size} coverage-information extension(s), found #{actual.size}."
        end

        differences = compare_coverage_info_sub_extensions(expected[0], actual[0])
        return unless differences.present?

        "Stored coverage-information extension does not match what was sent by the server: #{differences.join(', ')}"
      end

      def compare_coverage_info_sub_extensions(expected, actual)
        expected_by_url = expected.extension.group_by(&:url)
        actual_by_url = actual.extension.group_by(&:url)

        (expected_by_url.keys | actual_by_url.keys).filter_map do |url|
          compare_url_sub_extensions(url, expected_by_url, actual_by_url)
        end
      end

      def compare_url_sub_extensions(url, expected_by_url, actual_by_url)
        if !expected_by_url.key?(url)
          "unexpected sub-extension '#{url}' found in stored resource"
        elsif !actual_by_url.key?(url)
          "sub-extension '#{url}' missing from stored resource"
        elsif normalized_extensions(expected_by_url[url]) != normalized_extensions(actual_by_url[url])
          "sub-extension '#{url}' value differs"
        end
      end

      def normalized_extensions(extensions)
        extensions.map { |e| normalize_extension(e.to_hash) }.sort_by(&:to_json)
      end

      # Recursively sort nested arrays so sub-extension order doesn't affect equality.
      def normalize_extension(value)
        case value
        when Hash  then value.transform_values { |v| normalize_extension(v) }
        when Array then value.map { |item| normalize_extension(item) }.sort_by(&:to_json)
        else value
        end
      end

      def error_prefix(resource_details)
        "(Request #{resource_details[:request_index] + 1}) " \
          "coverage-info systemAction #{resource_details[:action_index] + 1} " \
          "targeting resource #{resource_details[:resource_type]}/#{resource_details[:target_id]}: "
      end
    end
  end
end
