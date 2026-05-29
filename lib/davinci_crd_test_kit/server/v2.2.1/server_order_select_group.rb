require_relative '../../cross_suite/tags'
require_relative 'interaction/server_invoke_hook_test'
require_relative 'verify_request/service_request_required_fields_validation_test'
require_relative 'verify_request/service_request_optional_fields_validation_test'
require_relative 'verify_request/service_request_context_validation_test'
require_relative 'verify_response/service_response_validation_test'
require_relative 'verify_response/card_optional_fields_validation_test'
require_relative 'verify_response/external_reference_card_validation_test'
require_relative 'verify_response/launch_smart_app_card_validation_test'
require_relative 'verify_response/instructions_card_received_test'
require_relative 'verify_response/propose_alternate_request_card_validation_test'
require_relative 'verify_response/additional_orders_validation_test'
require_relative 'verify_response/form_completion_response_validation_test'
require_relative 'verify_response/create_or_update_coverage_info_response_validation_test'
require_relative 'verify_response/coverage_info_configuration_test'
require_relative 'verify_response/unknown_configuration_test'
require_relative 'verify_response/unknown_context_test'
require_relative 'verify_response/unknown_cds_hooks_elements_test'

module DaVinciCRDTestKit
  module V221
    class ServerOrderSelectGroup < Inferno::TestGroup
      CARDS_URL = 'https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html'.freeze

      title 'order-select'
      id :crd_v221_server_order_select
      description %(
        This group of tests invokes the order-select hook and ensures that
        the user-provided requests are valid as per the requirements described
        in the [CRD IG section on order-select hook](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-select)
        and the [CDS Hooks specification section on order-select context](https://cds-hooks.hl7.org/hooks/order-select.html).
        It also ensures that the contents of the server's response are valid as per the requirements described in
        the [CRD IG section on order-select hook](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-select)
        and the [CDS Hooks section on CDS Service Response](https://cds-hooks.hl7.org/2.0/#cds-service-response).

        This group includes tests to validate the following CRD response types:
        - [Identify Additional Orders](#{CARDS_URL}#identify-additional-orders-response-type)\
        - optional
        - [Coverage Information](#{CARDS_URL}#coverage-information-response-type) - optional
        - [Update Coverage Records](#{CARDS_URL}#update-coverage-records-response-type)\
        - optional
        - [External Reference](#{CARDS_URL}#external-reference-response-type) - optional
        - [Instructions](#{CARDS_URL}#instructions-response-type) - optional
        - [Launch SMART Application](#{CARDS_URL}#launch-smart-application-response-type) -
        optional
        - [Propose Alternate Request](#{CARDS_URL}#propose-alternate-request-response-type) -
        optional
        - [Request Form Completion](#{CARDS_URL}#request-form-completion-response-type) -
        optional
      )

      config options: { hook_name: ORDER_SELECT_TAG }
      run_as_group

      group do
        title 'Make Hook Requests'

        test from: :crd_v221_server_invoke_hook_test,
             config: {
               inputs: {
                 service_ids: {
                   name: :order_select_service_ids,
                   title: 'Service ID for the service that implements the `order-select` hook'
                 },
                 service_request_bodies: {
                   name: :order_select_request_bodies,
                   title: 'Request body or bodies for invoking the `order-select` hook'
                 }
               }
             }
      end

      group do
        title 'Verify Requests'

        test from: :crd_v221_service_request_required_fields_validation,
             config: {
               outputs: {
                 contexts: {
                   name: :order_select_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_context_validation,
             config: {
               inputs: {
                 contexts: {
                   name: :order_select_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_optional_fields_validation
      end

      group do
        title 'Verify Responses'

        test from: :crd_v221_service_response_validation,
             config: {
               outputs: {
                 valid_cards: {
                   name: :order_select_valid_cards
                 },
                 valid_system_actions: {
                   name: :order_select_valid_system_actions
                 }
               }
             }
        test from: :crd_v221_card_optional_fields_validation,
             config: {
               inputs: {
                 valid_cards: {
                   name: :order_select_valid_cards
                 }
               },
               outputs: {
                 valid_cards_with_links: {
                   name: :order_select_valid_cards_with_links
                 },
                 valid_cards_with_suggestions: {
                   name: :order_select_valid_cards_with_suggestions
                 }
               }
             }
        test from: :crd_v221_external_reference_card_validation,
             config: {
               inputs: {
                 valid_cards_with_links: {
                   name: :order_select_valid_cards_with_links
                 }
               }
             }
        test from: :crd_v221_launch_smart_app_card_validation,
             config: {
               inputs: {
                 valid_cards_with_links: {
                   name: :order_select_valid_cards_with_links
                 }
               }
             }
        test from: :crd_v221_valid_instructions_card_received,
             config: {
               inputs: {
                 valid_cards: {
                   name: :order_select_valid_cards
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_received,
             optional: true,
             config: {
               inputs: {
                 valid_system_actions: {
                   name: :order_select_valid_system_actions
                 }
               },
               outputs: {
                 coverage_info: {
                   name: :order_select_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_validation,
             optional: true,
             config: {
               inputs: {
                 coverage_info: {
                   name: :order_select_coverage_info
                 }
               }
             }
        test from: :crd_v221_propose_alternate_request_card_validation,
             config: {
               inputs: {
                 valid_cards_with_suggestions: {
                   name: :order_select_valid_cards_with_suggestions
                 },
                 contexts: {
                   name: :order_select_contexts
                 }
               }
             }
        test from: :crd_v221_additional_orders_card_validation,
             config: {
               inputs: {
                 valid_cards_with_suggestions: {
                   name: :order_select_valid_cards_with_suggestions
                 }
               }
             }
        test from: :crd_v221_request_form_completion_response_validation,
             config: {
               inputs: {
                 valid_system_actions: {
                   name: :order_select_valid_system_actions
                 },
                 valid_cards_with_suggestions: {
                   name: :order_select_valid_cards_with_suggestions
                 }
               }
             }
        test from: :crd_v221_create_or_update_coverage_info_response_validation,
             config: {
               inputs: {
                 valid_system_actions: {
                   name: :order_select_valid_system_actions
                 },
                 valid_cards_with_suggestions: {
                   name: :order_select_valid_cards_with_suggestions
                 }
               }
             }
        test from: :crd_v221_coverage_info_configuration
        test from: :crd_v221_unknown_configuration
        test from: :crd_v221_unknown_context
        test from: :crd_v221_unknown_cds_hooks_elements
      end
    end
  end
end
