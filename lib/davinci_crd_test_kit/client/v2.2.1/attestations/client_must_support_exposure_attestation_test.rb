require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class MustSupportExposureAttestationTest < Inferno::Test
      id :crd_v221_must_support_exposure_attestation
      ATTESTATION_TITLE = 'Health IT module exposes maintained must support elements'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module exposes the mustSupport elements it
        maintains and surfaces to users in its FHIR interface.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :must_support_exposure_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module exposes the mustSupport elements it maintains and surfaces to
              users in its FHIR interface.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :must_support_exposure_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert must_support_exposure_attestation == 'true'
      end
    end
  end
end
