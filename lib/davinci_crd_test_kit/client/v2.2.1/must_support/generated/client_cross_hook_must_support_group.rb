require_relative '../../cross_hook/client_card_must_support_coverage_information_test'
require_relative '../../cross_hook/client_order_types_signed_test'
require_relative 'appointment_must_support_test'
require_relative 'appointment_reference_resolution_test'
require_relative 'communication_request_must_support_test'
require_relative 'communication_request_reference_resolution_test'
require_relative 'coverage_must_support_test'
require_relative 'coverage_reference_resolution_test'
require_relative 'device_must_support_test'
require_relative 'device_request_must_support_test'
require_relative 'device_request_reference_resolution_test'
require_relative 'encounter_must_support_test'
require_relative 'encounter_reference_resolution_test'
require_relative 'location_must_support_test'
require_relative 'location_reference_resolution_test'
require_relative 'medication_must_support_test'
require_relative 'medication_request_must_support_test'
require_relative 'medication_request_reference_resolution_test'
require_relative 'nutrition_order_must_support_test'
require_relative 'nutrition_order_reference_resolution_test'
require_relative 'organization_must_support_test'
require_relative 'organization_reference_resolution_test'
require_relative 'patient_must_support_test'
require_relative 'practitioner_must_support_test'
require_relative 'practitioner_role_must_support_test'
require_relative 'practitioner_role_reference_resolution_test'
require_relative 'service_request_must_support_test'
require_relative 'service_request_reference_resolution_test'
require_relative 'vision_prescription_must_support_test'
require_relative 'vision_prescription_reference_resolution_test'

module DaVinciCRDTestKit
  module V221
    class ClientCrossHookMustSupportGroup < Inferno::TestGroup
      title 'Must Support'
      id :crd_v221_client_cross_hook_must_support
      description <<~DESCRIPTION
        These tests check that the CRD client supports the must support elements of the CRD profiles
        that it sends within hook requests and that it receives within hook responses.

        All requests made during the latest runs of each "Hooks" sub-group and the "Additional Hook
        Invocations" group above are included in this analysis.
        When re-running these groups, remember that requests made during the prior execution will fall
        out of scope of this analysis, so elements only demonstrated during that execution will need to
        be demonstrated again during the new test run.

        For additional details on this group, see the [Client Must Support Tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support)
        page in the CRD Test Kit wiki.
      DESCRIPTION

      run_as_group

      input_order :order_types_supported, :supporting_types_supported

      ORDER_TYPE_OPTIONS = [
        { label: 'CommunicationRequest', value: 'CommunicationRequest' },
        { label: 'DeviceRequest', value: 'DeviceRequest' },
        { label: 'MedicationRequest', value: 'MedicationRequest' },
        { label: 'NutritionOrder', value: 'NutritionOrder' },
        { label: 'ServiceRequest', value: 'ServiceRequest' },
        { label: 'VisionPrescription', value: 'VisionPrescription' }
      ].freeze

      # Patient and Coverage are required of every CRD client, so they are not listed here.
      SUPPORTING_TYPE_OPTIONS = [
        { label: 'Appointment', value: 'Appointment' },
        { label: 'Device', value: 'Device' },
        { label: 'Encounter', value: 'Encounter' },
        { label: 'Location', value: 'Location' },
        { label: 'Medication', value: 'Medication' },
        { label: 'Organization', value: 'Organization' },
        { label: 'Practitioner', value: 'Practitioner' },
        { label: 'PractitionerRole', value: 'PractitionerRole' }
      ].freeze

      # The hooks whose requests always carry a supporting resource type. Whether the type is expected
      # is decided by the input above, but invoking one of these hooks while the type is deselected
      # fails as a contradiction.
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
              related to requests sent as a part of CRD. Inferno will expect those resource types to be
              demonstrated within hook requests. By unchecking a resource type, the tester attests
              that the CRD client does not support the information represented by the resource type
              or does not surface it to users. `Patient` and `Coverage` resource types are not
              listed but are always included in the checks because CRD clients are required to support them.
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

          Inferno expects to see a resource type when it is selected in the **Order types supported by the
          CRD client** or **Supporting resource types populated by the CRD client** input, and always expects
          the `Patient` and `Coverage` resource types, which CRD clients are required to support. A
          tester who deselects a resource type must not invoke the hooks whose requests always carry it:
          `appointment-book` for `Appointment`, and `encounter-start` and `encounter-discharge` for
          `Encounter`. Inferno will fail without
          further analysis if an expected resource type is not observed or vice-versa. When a resource type
          was observed but some of its must support elements were not, the tester is asked to attest
          that the CRD client does not capture the represented data or does not surface it to users.

          For additional details on this group, see the [Client Must Support Tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support)
          page and specifically the [Requests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support#requests)
          section in the CRD Test Kit wiki.
        DESCRIPTION

        test from: :crd_v221_appointment_must_support
        test from: :crd_v221_appointment_must_support_reference_resolution
        test from: :crd_v221_communication_request_must_support
        test from: :crd_v221_communication_request_must_support_reference_resolution
        test from: :crd_v221_coverage_must_support
        test from: :crd_v221_coverage_must_support_reference_resolution
        test from: :crd_v221_device_must_support
        test from: :crd_v221_device_request_must_support
        test from: :crd_v221_device_request_must_support_reference_resolution
        test from: :crd_v221_encounter_must_support
        test from: :crd_v221_encounter_must_support_reference_resolution
        test from: :crd_v221_location_must_support
        test from: :crd_v221_location_must_support_reference_resolution
        test from: :crd_v221_medication_must_support
        test from: :crd_v221_medication_request_must_support
        test from: :crd_v221_medication_request_must_support_reference_resolution
        test from: :crd_v221_nutrition_order_must_support
        test from: :crd_v221_nutrition_order_must_support_reference_resolution
        test from: :crd_v221_organization_must_support
        test from: :crd_v221_organization_must_support_reference_resolution
        test from: :crd_v221_patient_must_support
        test from: :crd_v221_practitioner_must_support
        test from: :crd_v221_practitioner_role_must_support
        test from: :crd_v221_practitioner_role_must_support_reference_resolution
        test from: :crd_v221_service_request_must_support
        test from: :crd_v221_service_request_must_support_reference_resolution
        test from: :crd_v221_vision_prescription_must_support
        test from: :crd_v221_vision_prescription_must_support_reference_resolution
        test from: :crd_v221_client_order_types_signed
      end

      group do
        title 'Responses'
        id :crd_v221_client_cross_hook_must_support_responses
        description <<~DESCRIPTION
          These tests check that the CRD client supports the response types and the must support
          elements within them that CRD clients are required to support when returned by a CRD server.

          For additional details on this group, see the [Client Must Support Tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support)
          page and specifically the [Responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Must-Support#responses)
          section in the CRD Test Kit wiki.
        DESCRIPTION

        test from: :crd_v221_client_card_must_support_coverage_information
      end
    end
  end
end
