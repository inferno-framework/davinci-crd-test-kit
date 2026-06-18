require_relative '../interaction/server_invoke_hook_single_request_test'
require_relative 'unresolved_coverage_test'

module DaVinciCRDTestKit
  module V221
    class UnresolvedCoverageGroup < Inferno::TestGroup
      title 'Unresolved Coverage'
      id :crd_v221_server_unresolved_coverage_group
      description %(
        This group of tests allows the system to demonstrate its ability to respond to a CRD Hook invocation
        with a `not-covered` coverage determination when the patient can be resolved but no active coverage can
        be found or resolved to a single coverage.

        For these tests, provide a hook request body that represents a resolvable patient with no active
        coverage, or for whom the CRD Server cannot resolve to a single coverage. The tests then verify that a Coverage
        Information systemAction is received with `not-covered` coverage for `coverage-not-found` or
        `no-active-coverage` reasons.
      )

      config options: { hook_name: UNRESOLVED_COVERAGE_TAG }
      run_as_group

      group do
        title 'Interaction'

        test from: :crd_v221_server_invoke_hook_single_request_test,
             title: 'Inferno invokes the selected hook to elicit unresolved coverage response',
             description: <<~DESCRIPTION,
               This test initiates a POST request to a specified CDS Service using the JSON body provided
               by the user. The request body should represent a resolvable patient without active coverage, or for
               whom the CRD Server cannot resolve to a single coverage.
             DESCRIPTION
             config: {
               inputs: {
                 service_ids: {
                   name: :unresolved_coverage_service_ids,
                   title: 'Service id to use for the "Unresolved Coverage" test',
                   description: %(
                     If blank, Inferno will attempt to infer the service id to use by finding a service entry
                     in the Discovery response for the hook indicated in the provided request body. If it
                     cannot be inferred, the tests will be skipped.
                   )
                 },
                 service_request_bodies: {
                   name: :unresolved_coverage_request_body,
                   title: 'Request body to use for the "Unresolved Coverage" test',
                   description: %(
                     Provide a single JSON request body to submit for the hook invocation. The type of hook
                     invoked will be inferred based on the `hook` element in the request. The body should be
                     constructed so that it represents a resolvable patient without active coverage, or for whom
                     the CRD Server cannot resolve to a single coverage.
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
                   name: :unresolved_coverage_contexts
                 }
               }
             }
        test from: :crd_v221_service_request_context_validation,
             config: {
               inputs: {
                 contexts: {
                   name: :unresolved_coverage_contexts
                 },
                 request_body: {
                   name: :unresolved_coverage_request_body
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
                   name: :unresolved_coverage_valid_cards
                 },
                 valid_system_actions: {
                   name: :unresolved_coverage_valid_system_actions
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_received,
             config: {
               inputs: {
                 valid_system_actions: {
                   name: :unresolved_coverage_valid_system_actions
                 }
               },
               outputs: {
                 coverage_info: {
                   name: :unresolved_coverage_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_system_action_validation,
             config: {
               inputs: {
                 coverage_info: {
                   name: :unresolved_coverage_coverage_info
                 }
               }
             }
        test from: :crd_v221_coverage_info_unresolved_coverage,
             config: {
               inputs: {
                 coverage_info: {
                   name: :unresolved_coverage_coverage_info
                 }
               }
             }
      end
    end
  end
end
