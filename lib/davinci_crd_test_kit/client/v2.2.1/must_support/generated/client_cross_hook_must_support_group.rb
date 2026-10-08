require_relative '../../cross_hook/client_card_must_support_coverage_information_test'
require_relative '../../cross_hook/client_order_types_signed_test'
require_relative 'vision_prescription_must_support_test'
require_relative 'service_request_must_support_test'
require_relative 'nutrition_order_must_support_test'
require_relative 'medication_request_must_support_test'
require_relative 'device_request_must_support_test'
require_relative 'communication_request_must_support_test'
require_relative 'appointment_must_support_test'
require_relative 'encounter_must_support_test'
require_relative 'coverage_must_support_test'
require_relative 'location_must_support_test'
require_relative 'organization_must_support_test'
require_relative 'patient_must_support_test'
require_relative 'practitioner_must_support_test'
require_relative 'practitioner_role_must_support_test'

module DaVinciCRDTestKit
  module V221
    class ClientCrossHookMustSupportGroup < Inferno::TestGroup
      title 'Must Support'
      id :crd_v221_client_cross_hook_must_support
      description <<~DESCRIPTION
        These tests check that the CRD client supports the must support elements of the CRD profiles
        that it sends within hook requests and that it receives within hook responses.

        All requests made during the latest runs of each "Hooks" sub-groups and the "Additional Hook
        Invocations for Cross Hook Support Demonstration" group above are included in this analysis.
        When re-running these groups, remember that requests made during the prior execution will fall
        out of scope of this analysis, so elements only demonstrated during that execution will need to
        be demonstrated again during the new test run.
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
        { label: 'Encounter', value: 'Encounter' },
        { label: 'Location', value: 'Location' },
        { label: 'Organization', value: 'Organization' },
        { label: 'Practitioner', value: 'Practitioner' },
        { label: 'PractitionerRole', value: 'PractitionerRole' }
      ].freeze

      # A resource type only a non-required hook would carry is not expected when that hook was
      # never invoked, so its test passes rather than asking the tester to attest. A type that is also
      # in one of the lists above is expected when selected, and invoking one of its hooks while it is
      # deselected fails as a contradiction.
      REQUIRING_HOOKS = {
        'Appointment' => [APPOINTMENT_BOOK_TAG],
        'Encounter' => [ENCOUNTER_START_TAG, ENCOUNTER_DISCHARGE_TAG]
      }.freeze

      input :order_types_supported,
            title: 'Order types supported by the CRD client',
            description: %(
              Select the resource types that the CRD client supports placing orders for.
              Inferno will expect those order types to be demonstrated within hook requests.
              By unchecking a resource type, the tester attests that the CRD client does
              not support placing orders for the kind of request represented by that FHIR resource type.
            ),
            type: 'checkbox',
            default: ORDER_TYPE_OPTIONS.map { |option| option[:value] },
            optional: true,
            options: { list_options: ORDER_TYPE_OPTIONS }
      input :supporting_types_supported,
            title: 'Supporting resource types populated by the CRD client',
            description: %(
              Select the resource types that the CRD client supports when representing information
              related to requests sent as a part of CRD. Inferno will expect those order types to be
              demonstrated within hook requests. By unchecking a resource type, the tester attests
              that the CRD client does not support the information represented by the resource type
              or does not surface it to users. `Patient` and `Coverage` resource types are always
              checked because CRD clients are required to support them.
            ),
            type: 'checkbox',
            default: SUPPORTING_TYPE_OPTIONS.map { |option| option[:value] },
            optional: true,
            options: { list_options: SUPPORTING_TYPE_OPTIONS }

      group do
        title 'Requests'
        id :crd_v221_client_cross_hook_must_support_requests
        description <<~DESCRIPTION
          These tests check that the CRD profiles which can be sent within a hook request were
          observed across the hook requests the CRD client made, and that the must support elements on
          them were populated.

          Inferno expects to see a resource type when a hook is invoked where the resource type must appear
          in the context or the type is selected in the **Order types supported by the CRD Client** or
          **Supporting resource types populated by the Health IT Module** input. Inferno will fail without
          further analysis if an expected resource type is not observed or vice-versa. When a resource type
          was observed but some of its must support elements were not, the tester is asked to attest
          that the CRD client does not capture the represented data or does not surface it to users.
        DESCRIPTION

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
      end

      group do
        title 'Responses'
        id :crd_v221_client_cross_hook_must_support_responses
        description <<~DESCRIPTION
          These tests check that the CRD client supports the response types and the must support
          elements within them that CRD clients are required to support when returned by a CRD server.
        DESCRIPTION

        test from: :crd_v221_client_card_must_support_coverage_information
      end
    end
  end
end
