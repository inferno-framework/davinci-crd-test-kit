require_relative 'base_hook_invocation_receive_request_test'
require_relative '../../../cross_suite/short_circuit_interaction'

module DaVinciCRDTestKit
  module V221
    class CrossHooksReceiveRequestTest < BaseHookInvocationReceiveRequestTest
      include ShortCircuitInteraction

      id :crd_v221_cross_hooks_request
      title 'CRD client invokes any hook'
      description %(
        During this test, Inferno will wait while the CRD client makes one or more [hook](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html)
        requests against Inferno's simulated CRD servers. Inferno will respond
        based on the response configuration provided when running the test.
        For more details on how Inferno's simulated CRD servers behave during
        hook invocation see the [simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#simulated-crd-server-in-the-crd-client-v221-suite)
        documentation.

        Inferno will pause and wait for inbound requests until told explicitly to continue
        by the tester by clicking on the link in the "User Action Required" dialog (NOTE: after
        5 minutes the test will become inactive and unresponsive to anything except cancelation).
      )

      input :make_additional_hook_requests,
            title: 'Make additional hook requests?',
            description: %(
              Cross hook analysis considers every hook request made during the most recent execution
              of each group in this session. Select `Yes` to send more requests now so that features
              the earlier requests did not cover can be demonstrated. Otherwise select `No` to
              evaluate the requests already received, and every test in this group will pass without
              further requests. NOTE: if re-running this test, requests made during its previous
              execution run will no longer be considered, even if `No` is selected.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes, send more hook requests now.', value: 'true' },
                { label: 'No, the requests already made cover everything.', value: 'false' }
              ]
            }
      input :cross_hooks_response_approach,
            title: 'Response generation approach for all hooks',
            description: %(
              Determines how Inferno will generate response for all
              hook invocations.
            ),
            type: 'radio',
            default: 'mocked',
            options: {
              list_options: [
                {
                  label: 'Create simple mocks based on selected response types',
                  value: 'mocked'
                },
                {
                  label: 'Generate responses based on a tester-provided template',
                  value: 'custom'
                }
              ]
            },
            enable_when: { input_name: 'make_additional_hook_requests', value: 'true' }
      input :cross_hooks_selected_response_types,
            title: 'Response types to return from all hook requests',
            description: %(
              Select the CRD response types that the simulated Inferno CRD server will [mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
              when responding to hook invocations. If no types are selected, Inferno will mock and return
              a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
              response.
            ),
            type: 'checkbox',
            default: ['coverage_information', 'external_reference', 'instructions'],
            optional: true,
            options: { list_options: ORDER_RESPONSE_TYPE_OPTIONS },
            enable_when: { input_name: 'cross_hooks_response_approach', value: 'mocked' }
      input :cross_hooks_custom_response_template,
            title: 'Custom response template for all hook requests',
            description: %(
              Provide a [custom response template](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
              in JSON form for Inferno to use when responding to hook invocations.
            ),
            type: 'textarea',
            optional: true,
            enable_when: { input_name: 'cross_hooks_response_approach', value: 'custom' }

      # The tester may have demonstrated everything during the Hooks group, in which case there is
      # nothing to wait for and the tests evaluating these requests have nothing to evaluate.
      def skip_waiting_for_requests?
        clear_short_circuit_flag
        return false unless make_additional_hook_requests == 'false'

        short_circuit_remaining_tests(:pass)
        pass DEFAULT_SHORT_CIRCUIT_MESSAGE
      end

      private

      def hook_key
        'cross_hooks'
      end

      def hook_slug
        'all'
      end

      def primary_hook?
        true
      end

      def invoke_heading
        'Invoke any hook'
      end

      def invoke_intro
        "Invoke any hook by sending requests to\n            " \
          "one or both of the two Inferno simulated CRD servers\n            " \
          'discoverable at the following endpoints:'
      end

      def complete_prefetch_url
        discovery_url
      end

      def subset_prefetch_url
        prefetch_subset_discovery_url
      end
    end
  end
end
