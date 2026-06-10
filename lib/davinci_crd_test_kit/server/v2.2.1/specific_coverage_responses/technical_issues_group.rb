require_relative 'technical_issues_invoke_test'
require_relative 'technical_issues_test'

module DaVinciCRDTestKit
  module V221
    class TechnicalIssuesGroup < Inferno::TestGroup
      title 'Technical Issues'
      id :crd_v221_server_technical_issues_group
      description %(
        This group of tests allows the system to demonstrate its ability to
        respond to a CRD Hook invocation with an `indeterminate` coverage
        determination due to technical issues.

        For these tests, the hook call will include an invalid access token,
        which due to the nature of Inferno's FHIR server simulation will result
        in 500 response to FHIR requests, simulating a temporary server outage.
        The tests then verify that a Coverage Information systemAction is
        received with `indeterminate` coverage for `technical` reasons.
      )

      config options: { hook_name: TECHNICAL_ISSUES_TAG }
      run_as_group

      group do
        title 'Interaction'

        test from: :crd_v221_server_technical_issues_invoke_hook_test,
             description: <<~DESCRIPTION,
               This test initiates a POST request to a specified CDS Service
               using the JSON body list provided by the user. This request is
               generated so that requests for FHIR resources from the CDS service
               result in 500 errors, simulating a temporary server error.
             DESCRIPTION
             config: {
               inputs: {
                 service_ids: {
                   name: :technical_issues_service_ids,
                   title: 'Service id to use for the "Technical Issues" test',
                   description: %(
                     If blank, Inferno will attempt to infer the service id to use
                     by finding a service entry in the Discovery response for the
                     hook indicated in the provided request body. If it cannot be
                     inferred, the tests will be skipped.
                   )
                 },
                 service_request_bodies: {
                   name: :technical_issues_request_body,
                   title: 'Request body to use for the "Technical Issues" test',
                   description: %(
                     Provide a single JSON request body to submit for the hook
                     invocation. The type of hook invoked will be inferred based
                     on the `hook` element in the request.
                   )
                 }
               }
             }
      end

      group do
        title 'Requests'

        test from: :crd_v221_service_request_required_fields_validation,
             config: {
               outputs: {
                 contexts: {
                   name: :technical_issues_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_context_validation,
             config: {
               inputs: {
                 contexts: {
                   name: :technical_issues_contexts
                 },
                 request_body: {
                   name: :technical_issues_request_body
                 }
               }
             }
      end

      group do
        title 'Responses'

        test from: :crd_v221_service_response_validation,
             config: {
               outputs: {
                 valid_cards: {
                   name: :technical_issues_valid_cards
                 },
                 valid_system_actions: {
                   name: :technical_issues_valid_system_actions
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_received,
             config: {
               inputs: {
                 valid_system_actions: {
                   name: :technical_issues_valid_system_actions
                 }
               },
               outputs: {
                 coverage_info: {
                   name: :technical_issues_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_validation,
             config: {
               inputs: {
                 coverage_info: {
                   name: :technical_issues_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_technical_issues,
             config: {
               inputs: {
                 coverage_info: {
                   name: :technical_issues_coverage_info
                 }
               }
             }
      end
    end
  end
end
