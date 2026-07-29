module DaVinciCRDTestKit
  module V221
    class SecurityAndPrivacyAttestationTest < Inferno::Test
      id :crd_v221_security_and_privacy_attestation
      title 'Health IT module adheres to security and privacy requirements'
      description %(
        The Health IT module adheres to the security and privacy rules that CRD inherits from the
        specifications it builds on, including FHIR, SMART App Launch, and CDS Hooks.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@sec-1'

      input :security_and_privacy_attestation,
            title: 'Health IT module adheres to security and privacy requirements',
            description: %(
              I attest that the Health IT module adheres to the security and privacy rules that CRD inherits from the
              specifications it builds on, including FHIR, SMART App Launch, and CDS Hooks.
              ([sec-1](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/security.html#ci-c-sec-1))
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :security_and_privacy_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert security_and_privacy_attestation == 'true',
               'Health IT module does not adhere to the inherited security and privacy requirements.'

        pass security_and_privacy_attestation_note if security_and_privacy_attestation_note.present?
      end
    end
  end
end
