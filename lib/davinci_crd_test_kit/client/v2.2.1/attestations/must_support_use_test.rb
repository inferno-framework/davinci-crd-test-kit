module DaVinciCRDTestKit
  module V221
    class MustSupportUseAttestationTest < Inferno::Test
      id :crd_v221_must_support_use_attestation
      title 'Health IT module uses received must support data'
      description %(
        The Health IT module makes the mustSupport data it receives available to the appropriate clinical or
        administrative user, or leverages that data within its workflow as necessary to follow the intention of
        the provided decision support.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-6'

      input :must_support_use_attestation,
            title: 'Health IT module uses received must support data',
            description: %(
              I attest that the Health IT module makes the mustSupport data it receives available to the
              appropriate clinical or administrative user, or leverages that data within its workflow as
              necessary to follow the intention of the provided decision support.
              ([conf-6](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-6))
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :must_support_use_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert must_support_use_attestation == 'true',
               'Health IT module does not use the must support data that it receives.'

        pass must_support_use_attestation_note if must_support_use_attestation_note.present?
      end
    end
  end
end
