require_relative 'base_hook_invocation_receive_request_test'

module DaVinciCRDTestKit
  module V221
    class EncounterDischargeReceiveRequestTest < BaseHookInvocationReceiveRequestTest
      id :crd_v221_encounter_discharge_request
      title 'Client invokes the encounter-discharge hook'
      description %(
        During this test, Inferno will wait while the client makes one or more [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#encounter-discharge)
        hook requests against Inferno's simulated CRD servers. Inferno will respond
        based on the response configuration provided when running the test.
        For more details on how Inferno's simulated CRD servers behave during
        hook invocation see the [simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#crd-server-simulation)
        documentation.

        Inferno will pause and wait for inbound requests until told explicitly to continue
        by the tester by clicking on the link in the "User Action Required" dialog (NOTE: after
        5 minutes the test will become inactive and unresponsive to anything except cancelation).
      )

      input :encounter_discharge_response_approach,
            title: 'Response generation approach for encounter-discharge',
            description: %(
              Determines how Inferno will generate response for encounter-discharge
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
            }
      input :encounter_discharge_selected_response_types,
            title: 'Response types to return from encounter-discharge hook requests',
            description: %(
              Select the CRD response types that the simulated Inferno CRD server will [mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
              when responding to hook invocations. If no types are selected, Inferno will mock and return
              an [Instructions](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#instructions-response-type)
              response for this secondary hook.
            ),
            type: 'checkbox',
            default: ['coverage_information', 'external_reference', 'instructions'],
            optional: true,
            options: { list_options: RESPONSE_TYPE_OPTIONS },
            enable_when: { input_name: 'encounter_discharge_response_approach', value: 'mocked' }
      input :encounter_discharge_custom_response_template,
            title: 'Custom response template for encounter-discharge hook requests',
            description: %(
              Provide a [custom response template](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
              in JSON form for Inferno to use when responding to hook invocations.
            ),
            type: 'textarea',
            optional: true,
            enable_when: { input_name: 'encounter_discharge_response_approach', value: 'custom' }

      private

      def hook_key
        'encounter_discharge'
      end

      def primary_hook?
        false
      end
    end
  end
end
