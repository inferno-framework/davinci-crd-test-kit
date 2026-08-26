require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class ResourceIdentifiersAttestationTest < Inferno::Test
      id :crd_v221_resource_identifiers_attestation
      ATTESTATION_TITLE = 'Health IT module does not use business identifiers in resource identifiers'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module does not expose resource identifiers
        that have a determinable relationship with business identifiers.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@sec-7'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :resource_identifiers_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module does not expose resource identifiers that have a determinable
              relationship with business identifiers.
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
        assert resource_identifiers_attestation == 'true'
      end
    end
  end
end
