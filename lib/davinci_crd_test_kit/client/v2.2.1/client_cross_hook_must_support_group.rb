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

        Each resource type is checked separately, so a client that supports only some of them will
        be asked to attest to the ones it does not support. Expect one attestation prompt per
        resource type that was not fully demonstrated.

        Requests made during the "Additional Hook Invocations for Cross Hook Support
        Demonstration" group above are included in this analysis, so anything not covered by the
        Hooks tests can be demonstrated there and this group re-run.
      DESCRIPTION

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
              Select each order type the client system can send in a CRD hook request. Inferno will
              expect to observe the types selected here, and will fail if it observes one that is
              not selected.
            ),
            type: 'checkbox',
            default: ORDER_TYPE_OPTIONS.map { |option| option[:value] },
            optional: true,
            options: { list_options: ORDER_TYPE_OPTIONS }
      input :supporting_types_supported,
            title: 'Supporting resource types populated by the client system',
            description: %(
              Select each supporting resource type the client system populates within its CRD hook
              requests. `Patient` and `Coverage` are required of every client, so they are not
              listed. Inferno will expect to observe the types selected here, and will fail if it
              observes one that is not selected.
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
