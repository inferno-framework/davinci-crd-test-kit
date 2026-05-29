require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/suggestion_actions_validation'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/cards_validation'

module DaVinciCRDTestKit
  module V221
    class AdditionalOrdersValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::SuggestionActionsValidation
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::CardsValidation

      title 'Additional Orders cards are valid'
      id :crd_v221_additional_orders_card_validation
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

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-57',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-58'

      optional
      input :valid_cards_with_suggestions

      run do
        parsed_cards = parse_json(valid_cards_with_suggestions)
        additional_orders_cards = parsed_cards.filter do |card|
          additional_orders_response_type?(card)
        end
        skip_if additional_orders_cards.blank?,
                "#{tested_hook_name} hook response does not include Additional Orders as companion/prerequisite cards."

        additional_orders_cards.each do |card|
          card['suggestions'].each do |suggestion|
            actions_check(suggestion['actions'], ig_version: 'v221')
          end

          additional_orders_check(card)
        end

        no_error_validation('Some Additional Order cards are not valid. See messages for more information.')
      end
    end
  end
end
