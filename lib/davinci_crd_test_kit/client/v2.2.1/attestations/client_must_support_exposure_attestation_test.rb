module DaVinciCRDTestKit
  module V221
    class MustSupportExposureAttestationTest < Inferno::Test
      id :crd_v221_must_support_exposure_attestation
      ATTESTATION_TITLE = 'Health IT module exposes maintained must support elements'.freeze
      title ATTESTATION_TITLE
      description %(
        Where the Health IT module maintains a mustSupport data element and surfaces it to users, that element
        is exposed in its FHIR interface when the data exists and privacy constraints permit.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3'

      input :must_support_exposure_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that, where the Health IT module maintains a mustSupport data element and surfaces it to
              users, that element is exposed in its FHIR interface when the data exists and privacy constraints
              permit.
              ([conf-3](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3))
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
        assert must_support_exposure_attestation == 'true',
               'Health IT module does not expose the must support elements that it maintains and surfaces to users.'

        pass must_support_exposure_attestation_note if must_support_exposure_attestation_note.present?
      end
    end
  end
end
