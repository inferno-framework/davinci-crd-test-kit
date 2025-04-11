require_relative 'server_tests/service_call_test'
require_relative 'server_tests/service_request_required_fields_validation_test'
require_relative 'server_tests/service_request_context_validation_test'
require_relative 'server_tests/service_request_optional_fields_validation_test'
require_relative 'server_tests/service_response_validation_test'
require_relative 'server_tests/card_optional_fields_validation_test'
require_relative 'server_tests/external_reference_card_validation_test'
require_relative 'server_tests/launch_smart_app_card_validation_test'
require_relative 'server_tests/instructions_card_received_test'
require_relative 'server_tests/coverage_information_system_action_received_test'
require_relative 'server_tests/coverage_information_system_action_validation_test'
require_relative 'server_tests/propose_alternate_request_card_validation_test'
require_relative 'server_tests/additional_orders_validation_test'
require_relative 'server_tests/form_completion_response_validation_test'
require_relative 'server_tests/create_or_update_coverage_info_response_validation_test'
require_relative 'tags'

module DaVinciCRDTestKit
  class ServerOrderSignGroup < Inferno::TestGroup
    title 'order-sign'
    id :crd_server_order_sign
    description %(
      This group of tests invokes the order-sign hook and ensures that
      the user-provided requests are valid as per the requirements described
      in the [CRD IG section on order-sign hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)
      and the [CDS Hooks specification section on order-sign context](https://cds-hooks.hl7.org/hooks/order-sign/2023SepSTU1Ballot/order-sign/).
      It also ensures that the contents of the server's response are valid as per the requirements described in
      the [CRD IG section on order-sign hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)
      and the [CDS Hooks section on CDS Service Response](https://cds-hooks.hl7.org/2.0/#cds-service-response).

      The [CRD IG section on order-sign hook](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)
      states that "servers SHALL, at minimum, support returning and processing the Coverage Information
      system action for all invocations of this hook."

      This group includes tests to validate the following CRD response types:
      - [additional orders as companions/prerequisites](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#identify-additional-orders-as-companionsprerequisites-for-current-order)\
      - optional
      - [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
      - [Create or update coverage information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#create-or-update-coverage-information)\
      - optional
      - [External Reference](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference) - optional
      - [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions) - optional
      - [Launch SMART application](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#launch-smart-application) -
      optional
      - [Propose alternate request](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#propose-alternate-request) -
      optional
      - [Request form completion](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#request-form-completion) -
      optional
    )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@164', 'hl7.fhir.us.davinci-crd_2.0.1@168',
                          'hl7.fhir.us.davinci-crd_2.0.1@217', 'hl7.fhir.us.davinci-crd_2.0.1@226'

    config options: { hook_name: ORDER_SIGN_TAG }
    run_as_group

    test from: :crd_service_call_test,
         config: {
           inputs: {
             service_ids: {
               name: :order_sign_service_ids,
               title: 'Service id for the service that implements the `order-sign` hook'
             },
             service_request_bodies: {
               name: :order_sign_request_bodies,
               title: 'Request body or bodies for invoking the `order-sign` hook'
             }
           }
         }

    test from: :crd_service_request_required_fields_validation,
         config: {
           outputs: {
             contexts: {
               name: :order_sign_contexts
             }
           }
         }
    test from: :crd_service_request_context_validation,
         config: {
           inputs: {
             contexts: {
               name: :order_sign_contexts
             }
           }
         }
    test from: :crd_service_request_optional_fields_validation
    test from: :crd_service_response_validation,
         config: {
           outputs: {
             valid_cards: {
               name: :order_sign_valid_cards
             },
             valid_system_actions: {
               name: :order_sign_valid_system_actions
             }
           }
         }
    test from: :crd_card_optional_fields_validation,
         config: {
           inputs: {
             valid_cards: {
               name: :order_sign_valid_cards
             }
           },
           outputs: {
             valid_cards_with_links: {
               name: :order_sign_valid_cards_with_links
             },
             valid_cards_with_suggestions: {
               name: :order_sign_valid_cards_with_suggestions
             }
           }
         }
    test from: :crd_external_reference_card_validation,
         config: {
           inputs: {
             valid_cards_with_links: {
               name: :order_sign_valid_cards_with_links
             }
           }
         }
    test from: :crd_launch_smart_app_card_validation,
         config: {
           inputs: {
             valid_cards_with_links: {
               name: :order_sign_valid_cards_with_links
             }
           }
         }
    test from: :crd_valid_instructions_card_received,
         config: {
           inputs: {
             valid_cards: {
               name: :order_sign_valid_cards
             }
           }
         }
    test from: :crd_coverage_info_system_action_received,
         config: {
           inputs: {
             valid_system_actions: {
               name: :order_sign_valid_system_actions
             }
           },
           outputs: {
             coverage_info: {
               name: :order_sign_coverage_info
             }
           }
         }
    test from: :crd_coverage_info_system_action_validation,
         config: {
           inputs: {
             coverage_info: {
               name: :order_sign_coverage_info
             }
           }
         }
    test from: :crd_propose_alternate_request_card_validation,
         config: {
           inputs: {
             valid_cards_with_suggestions: {
               name: :order_sign_valid_cards_with_suggestions
             },
             contexts: {
               name: :order_sign_contexts
             }
           }
         }
    test from: :crd_additional_orders_card_validation,
         config: {
           inputs: {
             valid_cards_with_suggestions: {
               name: :order_sign_valid_cards_with_suggestions
             }
           }
         }
    test from: :crd_request_form_completion_response_validation,
         config: {
           inputs: {
             valid_system_actions: {
               name: :order_sign_valid_system_actions
             },
             valid_cards_with_suggestions: {
               name: :order_sign_valid_cards_with_suggestions
             }
           }
         }
    test from: :crd_create_or_update_coverage_info_response_validation,
         config: {
           inputs: {
             valid_system_actions: {
               name: :order_sign_valid_system_actions
             },
             valid_cards_with_suggestions: {
               name: :order_sign_valid_cards_with_suggestions
             }
           }
         }
  end
end
