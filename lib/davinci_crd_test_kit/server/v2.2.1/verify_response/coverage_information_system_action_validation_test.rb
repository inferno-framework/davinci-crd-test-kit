require_relative '../../server_hook_request_validation'
require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'
require_relative 'hook_request_resource_resolution'

module DaVinciCRDTestKit
  module V221
    class CoverageInformationSystemActionValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookRequestValidation
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include HookRequestResourceResolution
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      COVERAGE_INFO_EXT_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'.freeze

      title 'Coverage Information system actions are valid'
      id :crd_v221_coverage_info_system_action_validation
      description %(
        This test validates all [Coverage
        Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        system actions received. It verifies the following for each action:
        - The action type is `update`.
        - The resource within the action conforms its respective FHIR profile.
        - The resource does not change any data elements other than adding or
          modifying the `coverage-information` extension.

        Additionally, the test examines the `coverage-info` extensions within
        the resource to ensure that:
        - Entries referencing differing coverage have distinct
        `coverage-assertion-ids` and `satisfied-pa-ids` (if present).
        - Entries referencing the same coverage have the same
        `coverage-assertion-ids` and `satisfied-pa-ids` (if present).
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-26',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-32',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-37',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-47',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-48',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-52'

      input :invoked_hook
      input :mock_ehr_bundle, optional: true
      output :coverage_info

      def verify_only_coverage_info_changed(action, request)
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

        return if only_coverage_information_changed?(source_resource.to_hash, updated_resource_hash)

        add_message(
          'error',
          "#{resource_ref}: resource content changed outside the coverage-information extension."
        )
      end

      def body_has_no_system_actions?(body)
        !body.is_a?(Hash) ||
          body['systemActions'].blank? ||
          !body['systemActions'].is_a?(Array) ||
          !body['systemActions'].all?(Hash)
      end

      def coverage_info_actions(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_system_actions?(response_body)

        response_body['systemActions'].select { |action| coverage_information_response_type? action }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        all_coverage_info_actions = []
        coverage_info_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          actions = coverage_info_actions(request)

          coverage_info_count += actions.length

          perform_response_logical_model_validation(
            nil,
            actions,
            request.request_body,
            index,
            '2.2.1'
          )
          actions.each { |action| verify_only_coverage_info_changed(action, request) }

          all_coverage_info_actions.concat(actions)
        end

        skip_if coverage_info_count.zero?,
                "#{tested_hook_name} hook responses do not contain any Coverage Information system actions."

        output coverage_info: all_coverage_info_actions.to_json

        no_error_validation(
          'Not all Coverage Information system actions were valid. See messages for more information.'
        )
      end
    end
  end
end
