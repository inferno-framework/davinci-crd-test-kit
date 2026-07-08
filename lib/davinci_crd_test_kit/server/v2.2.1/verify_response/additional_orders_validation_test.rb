require_relative '../../server_test_helper'
require_relative '../../server_hook_helper'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/response_logical_model_validation'

module DaVinciCRDTestKit
  module V221
    class AdditionalOrdersValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper
      include DaVinciCRDTestKit::ServerHookHelper
      include DaVinciCRDTestKit::CardsIdentification
      include DaVinciCRDTestKit::ResponseLogicalModelValidation

      title 'Additional Orders cards are valid'
      id :crd_v221_additional_orders_card_validation
      description %(
        This test validates that an [Identify Additional
        Orders](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#identify-additional-orders-response-type)
        card was received. It does so by:
        - Filtering cards with the following criteria:
          - For each suggestion in the card's suggestions array, all actions
            have a type of 'create' and the action's resource type is one of the
            expected types: CommunicationRequest, Device, DeviceRequest,
            Medication, MedicationRequest, NutritionOrder, ServiceRequest, or
            VisionPrescription.
        - Then, for each valid Additional Orders card retrieved, verifying that
          each action within the card's suggestions complies with their
          respective profiles as specified in the [CRD IG section on Identify
          Additional
          Orders](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#identify-additional-orders-response-type):
          -
            [crd-profile-communicationrequest](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-profile-communicationrequest.html)
          -
            [crd-profile-device](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-profile-device.html)
          -
            [crd-profile-deviceRequest](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-profile-devicerequest.html)
          -
            [us-core-medication](http://hl7.org/fhir/us/core/STU3.1.1/StructureDefinition-us-core-medication.html)
          -
            [crd-profile-medicationRequest](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-profile-medicationrequest.html)
          -
            [crd-profile-nutritionOrder](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-profile-nutritionorder.html)
          -
            [crd-profile-serviceRequest](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-profile-servicerequest.html)
          -
            [crd-profile-visionPrescription](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-profile-visionprescription.html).

        The test will skip if no Identify Additional Orders cards are found.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-57',
                            'hl7.fhir.us.davinci-crd_2.2.1@resp-58'

      input :invoked_hook

      optional

      def body_has_no_cards?(body)
        !body.is_a?(Hash) ||
          body['cards'].blank? ||
          !body['cards'].is_a?(Array) ||
          !body['cards'].all?(Hash)
      end

      def additional_orders_cards(request)
        return [] if request.status != 200

        response_body = JSON.parse(request.response_body)

        return [] if body_has_no_cards?(response_body)

        response_body['cards'].select { |card| additional_orders_response_type? card }
      rescue JSON::ParserError
        []
      end

      run do
        load_tagged_requests(tested_hook_name)

        additional_orders_count = 0

        successful_requests = requests.select { |request| request.status == 200 }

        skip_if successful_requests.blank?,
                'No successful hook responses were received'

        requests.each_with_index do |request, index|
          cards = additional_orders_cards(request)

          additional_orders_count += cards.length

          perform_response_logical_model_validation(
            cards,
            nil,
            request.request_body,
            index,
            '2.2.1'
          )
        end

        skip_if additional_orders_count.zero?,
                "#{tested_hook_name} hook responses do not contain any Additional Orders cards."

        no_error_validation('Not all Additional Orders cards were valid. See messages for more information.')
      end
    end
  end
end
