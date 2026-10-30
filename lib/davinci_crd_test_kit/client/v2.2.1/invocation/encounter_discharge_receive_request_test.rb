require_relative 'base_hook_invocation_receive_request_test'
require_relative '../../client_input_helper'

module DaVinciCRDTestKit
  module V221
    class EncounterDischargeReceiveRequestTest < BaseHookInvocationReceiveRequestTest
      id :crd_v221_encounter_discharge_request
      title 'CRD client invokes the encounter-discharge hook'
      description %(
        During this test, Inferno will wait while the CRD client makes one or more [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#encounter-discharge)
        hook requests against Inferno's simulated CRD servers. Inferno will respond
        based on the response configuration provided when running the test.
        For more details on how Inferno's simulated CRD servers behave during
        hook invocation see the [simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#simulated-crd-server-in-the-crd-client-v221-suite)
        documentation.

        Inferno will pause and wait for inbound requests until told explicitly to continue
        by the tester by clicking on the link in the "User Action Required" dialog (NOTE: after
        5 minutes the test will become inactive and unresponsive to anything except cancelation).
      )

      input :encounter_discharge_response_approach,
            title: 'Response generation approach for encounter-discharge',
            description: ClientInputHelper.response_approach_description('encounter-discharge'),
            type: 'radio',
            default: 'mocked',
            options: ClientInputHelper.response_approach_options
      input :encounter_discharge_selected_response_types,
            title: 'Response types to return from encounter-discharge hook requests',
            description: %(
              #{ClientInputHelper.mocked_response_types_intro}
              #{ClientInputHelper.default_response_type_note(primary: false)}
            ),
            type: 'checkbox',
            default: ['coverage_information', 'external_reference', 'instructions'],
            optional: true,
            options: { list_options: RESPONSE_TYPE_OPTIONS },
            enable_when: { input_name: 'encounter_discharge_response_approach', value: 'mocked' }
      input :encounter_discharge_custom_response_template,
            title: 'Custom response template for encounter-discharge hook requests',
            description: ClientInputHelper.custom_response_template_description,
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
