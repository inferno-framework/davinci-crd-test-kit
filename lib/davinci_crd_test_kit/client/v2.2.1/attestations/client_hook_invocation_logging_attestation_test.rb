require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class HookInvocationLoggingAttestationTest < Inferno::Test
      id :crd_v221_hook_invocation_logging_attestation
      ATTESTATION_TITLE = 'Health IT module retains logs of all CRD-related hook invocations'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module retains logs of all CRD-related hook
        invocations and their responses.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-37'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :hook_invocation_logging_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module retains logs of all CRD-related hook invocations and their
              responses.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :hook_invocation_logging_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert hook_invocation_logging_attestation == 'true'
      end
    end
  end
end
