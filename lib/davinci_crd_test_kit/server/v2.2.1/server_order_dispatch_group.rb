require_relative '../../cross_suite/tags'
require_relative 'interaction/server_invoke_hook_test'
require_relative 'verify_request/service_request_required_fields_validation_test'
require_relative 'verify_response/service_response_validation_test'
require_relative 'verify_response/external_reference_card_validation_test'
require_relative 'verify_response/launch_smart_app_card_validation_test'
require_relative 'verify_response/instructions_card_received_test'
require_relative 'verify_response/coverage_information_system_action_validation_test'
require_relative 'verify_response/coverage_information_card_absence_test'
require_relative 'verify_response/coverage_info_configuration_test'
require_relative 'verify_response/form_completion_response_validation_test'
require_relative 'verify_response/create_or_update_coverage_info_response_validation_test'
require_relative 'verify_response/order_dispatch_coverage_information_test'
require_relative 'verify_response/unknown_configuration_test'
require_relative 'verify_response/unknown_context_test'
require_relative 'verify_response/unknown_cds_hooks_elements_test'

module DaVinciCRDTestKit
  module V221
    class ServerOrderDispatchGroup < Inferno::TestGroup
      title 'order-dispatch'
      id :crd_v221_server_order_dispatch
      description %(
        This group of tests invokes the order-dispatch hook and ensures that
        the user-provided requests are valid as per the requirements described
        in the [CRD IG section on order-dispatch hook](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-dispatch)
        and the [CDS Hooks specification section on order-dispatch context](http://cds-hooks.hl7.org/hooks/STU1/order-dispatch.html).
        It also ensures that the contents of the server's response are valid as per the requirements described in
        the [CRD IG section on order-dispatch hook](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-dispatch)
        and the [CDS Hooks section on CDS Service Response](https://cds-hooks.hl7.org/2026Jan/en/#cds-service-response).

        The [CRD IG section on order-dispatch hook](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#order-dispatch)
        states that "servers SHALL, at minimum, support returning and processing the Coverage Information
        system action for all invocations of this hook."

        This group includes tests to validate the following CRD response types:
        - [External Reference](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#external-reference-response-type)
        - [Instructions](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#instructions-response-type)
        - [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        - [Request Form Completion](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#request-form-completion-response-type)
        - [Update Coverage Records](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#update-coverage-records-response-type)
        - [Launch SMART Application](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#launch-smart-application-response-type)
      )

      config options: { hook_name: ORDER_DISPATCH_TAG }
      run_as_group

      group do
        title 'Interaction'

        test from: :crd_v221_server_invoke_hook_test,
             config: {
               inputs: {
                 service_ids: {
                   name: :order_dispatch_service_ids,
                   title: 'Service id for the service that implements the `order-dispatch` hook'
                 },
                 service_request_bodies: {
                   name: :order_dispatch_request_bodies,
                   title: 'Request body or bodies for invoking the `order-dispatch` hook'
                 }
               }
             }
      end

      group do
        title 'Requests'

        test from: :crd_v221_service_request_required_fields_validation
      end

      group do
        title 'Responses'

        test from: :crd_v221_service_response_validation
        test from: :crd_v221_external_reference_card_validation
        test from: :crd_v221_launch_smart_app_card_validation
        test from: :crd_v221_valid_instructions_card_received
        test from: :crd_v221_coverage_info_system_action_validation
        test from: :crd_v221_order_dispatch_coverage_information,
             verifies_requirements: [
               'hl7.fhir.us.davinci-crd_2.2.1@hook-16',
               'hl7.fhir.us.davinci-crd_2.2.1@resp-28',
               'hl7.fhir.us.davinci-crd_2.2.1@hook-33',
               'hl7.fhir.us.davinci-crd_2.2.1@resp-29'
             ]
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
