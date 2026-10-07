require_relative 'cross_hook/client_card_must_support_coverage_information_test'
require_relative 'cross_hook/client_order_types_signed_test'
require_relative 'must_support/generated/vision_prescription_must_support_test'
require_relative 'must_support/generated/service_request_must_support_test'
require_relative 'must_support/generated/nutrition_order_must_support_test'
require_relative 'must_support/generated/medication_request_must_support_test'
require_relative 'must_support/generated/device_request_must_support_test'
require_relative 'must_support/generated/communication_request_must_support_test'
require_relative 'must_support/generated/appointment_must_support_test'
require_relative 'must_support/generated/encounter_must_support_test'
require_relative 'must_support/generated/coverage_must_support_test'
require_relative 'must_support/generated/location_must_support_test'
require_relative 'must_support/generated/organization_must_support_test'
require_relative 'must_support/generated/patient_must_support_test'
require_relative 'must_support/generated/practitioner_must_support_test'
require_relative 'must_support/generated/practitioner_role_must_support_test'

module DaVinciCRDTestKit
  module V221
    class ClientCrossHookMustSupportGroup < Inferno::TestGroup
      title 'Must Support'
      id :crd_v221_client_cross_hook_must_support
      description <<~DESCRIPTION
        These tests check that the CRD profiles which can be sent within a hook request were
        observed across the hook requests the client made, and that the must support elements on
        them were populated.

        Each resource type is checked separately. Use the inputs below to say which types the
        client system supports; a type left unchecked is not expected to appear. Where a type was
        observed but some of its must support elements were not, the tester is asked to attest that
        the client system does not capture the represented data or does not surface it to users.

        Requests made during the "Additional Hook Invocations for Cross Hook Support
        Demonstration" group above are included in this analysis, so anything not covered by the
        Hooks tests can be demonstrated there and this group re-run on its own.
      DESCRIPTION

      run_as_group

      input_order :order_types_supported, :supporting_types_supported

      ORDER_TYPE_OPTIONS = [
        { label: 'VisionPrescription', value: 'VisionPrescription' },
        { label: 'ServiceRequest', value: 'ServiceRequest' },
        { label: 'NutritionOrder', value: 'NutritionOrder' },
        { label: 'MedicationRequest', value: 'MedicationRequest' },
        { label: 'DeviceRequest', value: 'DeviceRequest' },
        { label: 'CommunicationRequest', value: 'CommunicationRequest' }
      ].freeze

      # Patient and Coverage are required of every CRD client, so they are not listed here.
      SUPPORTING_TYPE_OPTIONS = [
        { label: 'Location', value: 'Location' },
        { label: 'Organization', value: 'Organization' },
        { label: 'Practitioner', value: 'Practitioner' },
        { label: 'PractitionerRole', value: 'PractitionerRole' }
      ].freeze

      # A resource type only a non-required hook would carry is not expected when that hook was
      # never invoked, so its test passes rather than asking the tester to attest.
      REQUIRING_HOOKS = {
        'Appointment' => [APPOINTMENT_BOOK_TAG],
        'Encounter' => [ENCOUNTER_START_TAG, ENCOUNTER_DISCHARGE_TAG]
      }.freeze

      input :order_types_supported,
            title: 'Order types supported by the client system',
            description: %(
              Select the resource types that the client system supports placing orders for.
              Inferno will expect those order types to be demonstrated within hook requests.
              By unchecking a resource type, the tester attests that the client system does
              not support placing orders for the kind of request represented by that FHIR resource type.
            ),
            type: 'checkbox',
            default: ORDER_TYPE_OPTIONS.map { |option| option[:value] },
            optional: true,
            options: { list_options: ORDER_TYPE_OPTIONS }
      input :supporting_types_supported,
            title: 'Supporting resource types populated by the client system',
            description: %(
              Select the resource types that the client system supports when representing information
              related to requests sent as a part of CRD. Inferno will expect those order types to be
              demonstrated within hook requests. By unchecking a resource type, the tester attests
              that the client system does not support the information represented by the resource type
              or does not surface it to users. `Patient` and `Coverage` resource types are required of
              every client and are always checked.
            ),
            type: 'checkbox',
            default: SUPPORTING_TYPE_OPTIONS.map { |option| option[:value] },
            optional: true,
            options: { list_options: SUPPORTING_TYPE_OPTIONS }

      test from: :crd_v221_vision_prescription_must_support
      test from: :crd_v221_service_request_must_support
      test from: :crd_v221_nutrition_order_must_support
      test from: :crd_v221_medication_request_must_support
      test from: :crd_v221_device_request_must_support
      test from: :crd_v221_communication_request_must_support
      test from: :crd_v221_appointment_must_support
      test from: :crd_v221_encounter_must_support
      test from: :crd_v221_coverage_must_support
      test from: :crd_v221_location_must_support
      test from: :crd_v221_organization_must_support
      test from: :crd_v221_patient_must_support
      test from: :crd_v221_practitioner_must_support
      test from: :crd_v221_practitioner_role_must_support
      test from: :crd_v221_client_order_types_signed
      test from: :crd_v221_client_card_must_support_coverage_information
    end
  end
end
