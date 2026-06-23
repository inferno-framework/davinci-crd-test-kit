require_relative '../../server_hook_request_validation'
require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative 'hook_request_resource_resolution'

module DaVinciCRDTestKit
  module V221
    class CoverageInformationSystemActionValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerHookRequestValidation
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include HookRequestResourceResolution

      COVERAGE_INFO_EXT_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'.freeze

      title 'Coverage Information system actions are valid'
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

        assert only_coverage_information_changed?(source_resource.to_hash, updated_resource_hash),
               "#{resource_ref}: resource content changed outside the coverage-information extension."
      end

      def coverage_info_system_action_check(coverage_info_system_action)
        type = coverage_info_system_action['type']
        assert type, '`type` field is missing.'
        assert type == 'update', "`type` must be `update`, but was `#{type}`"

        resource = FHIR.from_contents(coverage_info_system_action['resource'].to_json)
        profile_url = structure_definition_map('v221')[resource.resourceType]
        resource_is_valid?(resource:, profile_url:)

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

        assert_no_error_messages 'Some Coverage Info system actions are not valid.'
      end
    end
  end
end
