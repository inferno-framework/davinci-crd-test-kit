require_relative 'cross_hook/client_card_must_support_coverage_information_test'
require_relative 'must_support/request_must_support_with_attestation_option'

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

      IG_VERSION = 'v2.2.1'.freeze
      CONF_3 = 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'.freeze
      HOOK_3 = 'hl7.fhir.us.davinci-crd_2.2.1@hook-3'.freeze

      # One test per request type, plus a single test covering the profiles that are referenced
      # from within a request rather than being requests themselves.
      TEST_DEFINITIONS = [
        { id: :crd_v221_vision_prescription_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }] },
        { id: :crd_v221_service_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'ServiceRequest', profile_keys: ['service_request'] }] },
        { id: :crd_v221_nutrition_order_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'NutritionOrder', profile_keys: ['nutrition_order'] }] },
        { id: :crd_v221_medication_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'MedicationRequest', profile_keys: ['medication_request'] }] },
        { id: :crd_v221_device_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'DeviceRequest', profile_keys: ['device_request'] }] },
        { id: :crd_v221_communication_request_must_support, requirements: [CONF_3, HOOK_3],
          profiles: [{ resource_type: 'CommunicationRequest', profile_keys: ['communication_request'] }] },
        { id: :crd_v221_appointment_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Appointment', title: 'CRD Appointment',
                       profile_keys: %w[appointment_with_order appointment_without_order] }] },
        { id: :crd_v221_encounter_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Encounter', profile_keys: ['encounter'] }] },
        { id: :crd_v221_coverage_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Coverage', profile_keys: ['coverage'] }] },
        { id: :crd_v221_location_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Location', profile_keys: ['location'] }] },
        { id: :crd_v221_organization_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Organization', profile_keys: ['organization'] }] },
        { id: :crd_v221_patient_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Patient', profile_keys: ['patient'] }] },
        { id: :crd_v221_practitioner_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'Practitioner', profile_keys: ['practitioner'] }] },
        { id: :crd_v221_practitioner_role_must_support, requirements: [CONF_3],
          profiles: [{ resource_type: 'PractitionerRole', profile_keys: ['practitioner_role'] }] }
      ].freeze

      TEST_DEFINITIONS.each do |definition|
        options = { ig_version: IG_VERSION, profiles: definition[:profiles] }
        test_id = definition[:id]
        test_requirements = definition[:requirements]
        test_description = RequestMustSupportWithAttestationOption.build_description(options)
        test_title =
          definition[:title] ||
          begin
            profile = definition[:profiles].first
            metadata = RequestMustSupportWithAttestationOption.metadata_for(IG_VERSION, profile)
            name = RequestMustSupportWithAttestationOption.title_for(metadata, profile)
            "#{name} must support elements are observed"
          end

        test from: :crd_v221_request_must_support_with_attestation_option do
          id test_id
          title test_title
          description test_description
          verifies_requirements(*test_requirements)
          config(options:)
        end
      end

      test from: :crd_v221_client_card_must_support_coverage_information
    end
  end
end
