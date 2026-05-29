require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/profiles_and_resource_types'

module DaVinciCRDTestKit
  module V221
    class AllResponsesIncludeCoverageInformationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification

      title 'Hook responses include Coverage Information system actions'
      id :crd_v221_all_responses_include_coverage_information
      description %(
        This test validates that a [Coverage
        Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        system action was returned for every hook call, unless the resource
        which is the focus of the hook call already includes a
        [coverage-information
        extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html).
        It does so by:
        - First checking for the presence of actions with a `resource` element
          of the following types:
          - For `appointment-book`: Appointment
          - For `order-sign` or `order-dispatch`: CommunicationRequest,
            DeviceRequest, MedicationRequest, NutritionOrder, ServiceRequest, or
            VisionPrescription
        - Then, checking whether each resource contains the coverage-information extension
        - Finally verifying that the response to each hook call where the
          resource did not contain a coverage-information extension includes
          coverage information system action
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-16',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-28'

      input :invoked_hook

      def target_resources
        {
          'appointment-book' => ['Appointment'],
          'order-sign' => ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES,
          'order-dispatch' => ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES,
          'order-select' => ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES,
          'encounter-start' => ['Encounter'],
          'encounter-discharge' => ['Encounter']
        }[tested_hook_name]
      end

      def hook_bundle_field_name
        {
          'appointment-book' => 'appointments',
          'order-sign' => 'draftOrders'
        }[tested_hook_name]
      end

      def resources_contain_coverage_information_extension?(resources)
        resources.all? do |resource|
          resource.extension&.any? do |extension|
            extension.url == 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'
          end
        end
      end

      def order_resources(hook_call_body)
        bundle = FHIR::Bundle.new(hook_call_body.dig('context', hook_bundle_field_name))
        bundle.entry.map(&:resource).select { |resource| target_resources.include? resource.resourceType }
      end

      run do
        successful_hook_calls_without_coverage_information = 0
        coverage_information_system_actions_received = 0

        load_tagged_requests(tested_hook_name)

        requests.each do |request|
          next if request.status != 200

          hook_call_body = JSON.parse(request.request_body)

          # TODO: handle when default value for coverage-info is false
          next if hook_call_body.dig('extension', 'davinci-crd.configuration', 'coverage-info') == false

          resources = order_resources(hook_call_body)

          next if resources_contain_coverage_information_extension?(resources)

          successful_hook_calls_without_coverage_information += 1

          hook_call_response = JSON.parse(request.response_body)

          system_actions = hook_call_response['systemActions']

          next if system_actions.blank?

          system_actions_resources =
            system_actions
              .select { |action| action['type'] == 'update' }
              .select { |action| target_resources.include? action['resource']['resourceType'] }
              .map { |action| FHIR.from_contents(action['resource'].to_json) }

          next unless resources_contain_coverage_information_extension?(system_actions_resources)

          coverage_information_system_actions_received += 1
        rescue JSON::ParserError => e
          warning(e.message)
          next
        end

        skip_if successful_hook_calls_without_coverage_information.zero?,
                'No successful hook calls were made with resources which did not already ' \
                'contain a coverage-information extension.'

        assert successful_hook_calls_without_coverage_information == coverage_information_system_actions_received,
               "#{successful_hook_calls_without_coverage_information} successful hook calls " \
               'without a coverage-information extension were made, but only ' \
               "#{coverage_information_system_actions_received} of the responses contained " \
               'a coverage information system action.'
      end
    end
  end
end
