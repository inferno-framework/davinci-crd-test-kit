module DaVinciCRDTestKit
  module V221
    class HookInvocationLoggingAttestationTest < Inferno::Test
      id :crd_v221_hook_invocation_logging_attestation
      title 'Health IT module retains logs of all CRD-related hook invocations'
      description %(
        In addition to any logging performed for security purposes, the Health IT module retains logs of all
        CRD-related hook invocations and their responses so that they can be accessed in the event of a dispute.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-37'

      input :hook_invocation_logging_attestation,
            title: 'Health IT module retains logs of all CRD-related hook invocations',
            description: %(
              I attest that, in addition to any logging performed for security purposes, the Health IT module
              retains logs of all CRD-related hook invocations and their responses so that they can be accessed
              in the event of a dispute.
              ([found-37](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-37))
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
        assert hook_invocation_logging_attestation == 'true',
               'Health IT module does not retain logs of all CRD-related hook invocations and their responses.'

        pass hook_invocation_logging_attestation_note if hook_invocation_logging_attestation_note.present?
      end
    end
  end
end
