module DaVinciCRDTestKit
  module V221
    class ResourceIdentifiersAttestationTest < Inferno::Test
      id :crd_v221_resource_identifiers_attestation
      ATTESTATION_TITLE = 'Health IT module does not use business identifiers in resource identifiers'.freeze
      title ATTESTATION_TITLE
      description %(
        The Health IT module ensures that the resource identifiers it exposes over the CRD interface are
        distinct from, and have no determinable relationship with, any business identifiers associated with
        those records.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@sec-7'

      input :resource_identifiers_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module ensures that the resource identifiers it exposes over the CRD
              interface are distinct from, and have no determinable relationship with, any business identifiers
              associated with those records.
              ([sec-7](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/security.html#ci-c-sec-7))
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :resource_identifiers_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert resource_identifiers_attestation == 'true',
               'Health IT module exposes resource identifiers that are related to business identifiers.'

        pass resource_identifiers_attestation_note if resource_identifiers_attestation_note.present?
      end
    end
  end
end
