require_relative 'server_tests/service_call_test'
require_relative 'server_tests/service_request_required_fields_validation_test'
require_relative 'server_tests/service_request_context_validation_test'
require_relative 'server_tests/service_request_optional_fields_validation_test'
require_relative 'server_tests/service_response_validation_test'
require_relative 'server_tests/card_optional_fields_validation_test'
require_relative 'server_tests/external_reference_card_validation_test'
require_relative 'server_tests/launch_smart_app_card_validation_test'
require_relative 'server_tests/instructions_card_received_test'
require_relative 'server_tests/form_completion_response_validation_test'
require_relative 'server_tests/create_or_update_coverage_info_response_validation_test'
require_relative 'tags'

module DaVinciCRDTestKit
  class ServerEncounterDischargeGroup < Inferno::TestGroup
    title 'encounter-discharge'
    id :crd_server_encounter_discharge
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
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@196'

    config options: { hook_name: ENCOUNTER_DISCHARGE_TAG }
    run_as_group

    test from: :crd_service_call_test,
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
    test from: :crd_service_request_required_fields_validation,
         config: {
           outputs: {
             contexts: {
               name: :encounter_discharge_contexts
             }
           }
         }
    test from: :crd_service_request_context_validation,
         config: {
           inputs: {
             contexts: {
               name: :encounter_discharge_contexts
             }
           }
         }
    test from: :crd_service_request_optional_fields_validation
    test from: :crd_service_response_validation,
         config: {
           outputs: {
             valid_cards: {
               name: :encounter_discharge_valid_cards
             },
             valid_system_actions: {
               name: :encounter_discharge_valid_system_actions
             }
           }
         }
    test from: :crd_card_optional_fields_validation,
         config: {
           inputs: {
             valid_cards: {
               name: :encounter_discharge_valid_cards
             }
           },
           outputs: {
             valid_cards_with_links: {
               name: :encounter_discharge_valid_cards_with_links
             },
             valid_cards_with_suggestions: {
               name: :encounter_discharge_valid_cards_with_suggestions
             }
           }
         }
    test from: :crd_external_reference_card_validation,
         config: {
           inputs: {
             valid_cards_with_links: {
               name: :encounter_discharge_valid_cards_with_links
             }
           }
         }
    test from: :crd_launch_smart_app_card_validation,
         config: {
           inputs: {
             valid_cards_with_links: {
               name: :encounter_discharge_valid_cards_with_links
             }
           }
         }
    test from: :crd_valid_instructions_card_received,
         config: {
           inputs: {
             valid_cards: {
               name: :encounter_discharge_valid_cards
             }
           }
         }
    test from: :crd_coverage_info_system_action_received,
         optional: true,
         config: {
           inputs: {
             valid_system_actions: {
               name: :encounter_discharge_valid_system_actions
             }
           },
           outputs: {
             coverage_info: {
               name: :encounter_discharge_coverage_info
             }
           }
         }
    test from: :crd_coverage_info_system_action_validation,
         optional: true,
         config: {
           inputs: {
             coverage_info: {
               name: :encounter_discharge_coverage_info
             }
           }
         }
    test from: :crd_request_form_completion_response_validation,
         config: {
           inputs: {
             valid_system_actions: {
               name: :encounter_discharge_valid_system_actions
             },
             valid_cards_with_suggestions: {
               name: :encounter_discharge_valid_cards_with_suggestions
             }
           }
         }
    test from: :crd_create_or_update_coverage_info_response_validation,
         config: {
           inputs: {
             valid_system_actions: {
               name: :encounter_discharge_valid_system_actions
             },
             valid_cards_with_suggestions: {
               name: :encounter_discharge_valid_cards_with_suggestions
             }
           }
         }
  end
end
