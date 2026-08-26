require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class SecurityAndPrivacyAttestationTest < Inferno::Test
      id :crd_v221_security_and_privacy_attestation
      ATTESTATION_TITLE = 'Health IT module adheres to security and privacy requirements'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module adheres to the security and privacy
        rules that CRD inherits from the specifications it builds on.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@sec-1'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :security_and_privacy_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module adheres to the security and privacy rules that CRD inherits from
              the specifications it builds on.
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
        assert security_and_privacy_attestation == 'true'
      end
    end
  end
end
