require_relative '../../cross_suite/tags'
require_relative 'interaction/server_invoke_hook_test'
require_relative 'verify_request/service_request_required_fields_validation_test'
require_relative 'verify_request/service_request_optional_fields_validation_test'
require_relative 'verify_request/service_request_context_validation_test'
require_relative 'verify_response/service_response_validation_test'
require_relative 'verify_response/external_reference_card_validation_test'
require_relative 'verify_response/launch_smart_app_card_validation_test'
require_relative 'verify_response/instructions_card_received_test'
require_relative 'verify_response/form_completion_response_validation_test'
require_relative 'verify_response/create_or_update_coverage_info_response_validation_test'
require_relative 'verify_response/coverage_information_card_absence_test'
require_relative 'verify_response/coverage_info_configuration_test'
require_relative 'verify_response/unknown_configuration_test'
require_relative 'verify_response/unknown_context_test'
require_relative 'verify_response/unknown_cds_hooks_elements_test'

module DaVinciCRDTestKit
  module V221
    class ServerEncounterDischargeGroup < Inferno::TestGroup
      title 'encounter-discharge'
      id :crd_v221_server_encounter_discharge
      description %(
        This group of tests invokes the encounter-discharge hook and ensures that
        the user-provided requests are valid as per the requirements described
        in the [CRD IG section on encounter-discharge hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
        and the [CDS Hooks specification section on encounter-discharge context](https://cds-hooks.hl7.org/hooks/encounter-discharge/2023SepSTU1Ballot/encounter-discharge/).
        It also ensures that the contents of the server's response are valid as per the requirements described in
        the [CRD IG section on encounter-discharge hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
        and the [CDS Hooks section on CDS Service Response](https://cds-hooks.hl7.org/2.0/#cds-service-response).

        This group includes tests to validate the following CRD response types:
        - [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information) - optional
        - [Create or update coverage information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#create-or-update-coverage-information)\
        - optional
        - [External Reference](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference) - optional
        - [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions) - optional
        - [Launch SMART application](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#launch-smart-application) -
        optional
        - [Request form completion](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#request-form-completion) -
        optional
      )
      # verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@168', 'hl7.fhir.us.davinci-crd_2.0.1@196'

      config options: { hook_name: ENCOUNTER_DISCHARGE_TAG }
      run_as_group

      group do
        title 'Interaction'

        test from: :crd_v221_server_invoke_hook_test,
             config: {
               inputs: {
                 service_ids: {
                   name: :encounter_discharge_service_ids,
                   title: 'Service id for the service that implements the `encounter-discharge` hook'
                 },
                 service_request_bodies: {
                   name: :encounter_discharge_request_bodies,
                   title: 'Request body or bodies for invoking the `encounter-discharge` hook'
                 }
               }
             }
      end

      group do
        title 'Requests'
        simulation_verification

        test from: :crd_v221_service_request_required_fields_validation,
             config: {
               outputs: {
                 contexts: {
                   name: :encounter_discharge_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_context_validation,
             config: {
               inputs: {
                 contexts: {
                   name: :encounter_discharge_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_optional_fields_validation
      end

      group do
        title 'Responses'

        test from: :crd_v221_service_response_validation
        test from: :crd_v221_external_reference_card_validation
        test from: :crd_v221_launch_smart_app_card_validation
        test from: :crd_v221_valid_instructions_card_received
        test from: :crd_v221_coverage_info_system_action_validation
        test from: :crd_v221_coverage_information_card_absence
        test from: :crd_v221_request_form_completion_response_validation
        test from: :crd_v221_create_or_update_coverage_info_response_validation
        test from: :crd_v221_coverage_info_configuration
        test from: :crd_v221_unknown_configuration
        test from: :crd_v221_unknown_context
        test from: :crd_v221_unknown_cds_hooks_elements
      end
    end
  end
end
