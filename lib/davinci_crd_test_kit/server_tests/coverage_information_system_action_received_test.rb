require_relative '../test_helper'
require_relative '../server_hook_helper'

module DaVinciCRDTestKit
  class CoverageInformationSystemActionReceivedTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper
    include DaVinciCRDTestKit::ServerHookHelper

    title 'Coverage Information system action was received'
    id :crd_coverage_info_system_action_received
    description %(
      This test validates that a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
      system action was returned. It does so by:
      - First checking for the presence of actions with a `resource` element of the following types:
        - For `appointment-book`: Appointment
        - For `order-sign` or `order-dispatch`: DeviceRequest, MedicationRequest, NutritionOrder,
          ServiceRequest, or VisionPrescription
      - Then, among the target actions, checking if their resource has the [coverage-information extension](http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information).
    )

    input :valid_system_actions, :invoked_hook
    output :coverage_info

    def resources_by_hook
      shared_resources = [
        'DeviceRequest', 'MedicationRequest', 'NutritionOrder',
        'ServiceRequest', 'VisionPrescription'
      ]
      {
        'appointment-book' => ['Appointment'],
        'order-sign' => shared_resources,
        'order-dispatch' => shared_resources,
        'order-select' => shared_resources,
        'encounter-start' => ['Encounter'],
        'encounter-discharge' => ['Encounter']
      }
    end

    run do
      parsed_actions = parse_json(valid_system_actions)
      target_resources = resources_by_hook[invoked_hook]

      target_actions = parsed_actions.select do |action|
        resource = FHIR.from_contents(action['resource'].to_json)
        target_resources.include?(resource&.resourceType)
      end

      coverage_info_system_actions = target_actions.select do |action|
        resource = FHIR.from_contents(action['resource'].to_json)
        coverage_info_ext_url = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'
        resource.extension.any? { |extension| extension.url == coverage_info_ext_url }
      end

      assert coverage_info_system_actions.present?,
             "Coverage Information system action was not returned in the #{tested_hook_name} hook response."

      output coverage_info: coverage_info_system_actions.to_json
    end
  end
end
