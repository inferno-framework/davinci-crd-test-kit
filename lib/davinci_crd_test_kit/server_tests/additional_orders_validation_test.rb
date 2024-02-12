require_relative '../test_helper'
require_relative '../suggestion_actions_validation'

module DaVinciCRDTestKit
  class AdditionalOrdersValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper
    include DaVinciCRDTestKit::SuggestionActionsValidation

    title 'Valid Additional Orders as companions/prerequisites cards received'
    id :crd_additional_orders_card_validation
    description %(
      This test validates that an [Additional Orders as companions/prerequisites](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#identify-additional-orders-as-companionsprerequisites-for-current-order)
      card was received. It does so by:
      - Filtering cards with the following criteria:
        - For each suggestion in the card's suggestions array, all actions have a type of 'create'
          and the action's resource type is one of the expected types: CommunicationRequest, Device,
          DeviceRequest, Medication, MedicationRequest, NutritionOrder, ServiceRequest, or VisionPrescription.
      - Then, for each valid Additional Orders card retrieved, verifying that each action within the
      card's suggestions complies with their respective profiles as specified in the
      [CRD IG section on Additional Orders as companions/prerequisites](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#identify-additional-orders-as-companionsprerequisites-for-current-order):
        - [crd-profile-communicationrequest](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-communicationrequest.html)
        - [crd-profile-device](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-device.html)
        - [crd-profile-deviceRequest](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-devicerequest.html)
        - [us-core-medication](http://hl7.org/fhir/us/core/STU3.1.1/StructureDefinition-us-core-medication.html)
        - [crd-profile-medicationRequest](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-medicationrequest.html)
        - [crd-profile-nutritionOrder](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-nutritionorder.html)
        - [crd-profile-serviceRequest](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-servicerequest.html)
        - [crd-profile-visionPrescription](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-profile-visionprescription.html).

      The test will skip if no Additional Orders cards are found.
    )

    optional
    input :valid_cards_with_suggestions

    EXPECTED_RESOURCE_TYPES = %w[
      CommunicationRequest Device DeviceRequest Medication
      MedicationRequest NutritionOrder ServiceRequest
      VisionPrescription
    ].freeze

    def hook_name
      config.options[:hook_name]
    end

    def additional_orders_card?(card)
      card['suggestions'].all? do |suggestion|
        actions = suggestion['actions']
        actions&.all? do |action|
          action['type'] == 'create' && action_resource_type_check(action, EXPECTED_RESOURCE_TYPES)
        end
      end
    end

    run do
      parsed_cards = parse_json(valid_cards_with_suggestions)
      additional_orders_cards = parsed_cards.filter { |card| additional_orders_card?(card) }
      skip_if additional_orders_cards.blank?,
              "#{hook_name} hook response does not contain an Additional Orders as companions/prerequisites card."

      additional_orders_cards.each do |card|
        card['suggestions'].each do |suggestion|
          actions_check(suggestion['actions'])
        end
      end

      no_error_validation('Some Additional Orders as companions/prerequisites cards are not valid.')
    end
  end
end
