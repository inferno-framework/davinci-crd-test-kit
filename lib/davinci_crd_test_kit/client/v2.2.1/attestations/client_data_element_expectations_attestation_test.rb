require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class DataElementExpectationsAttestationTest < Inferno::Test
      id :crd_v221_data_element_expectations_attestation
      ATTESTATION_TITLE = 'Health IT module does not set additional expectations for data elements'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module does not set expectations for data
        elements beyond those the CRD specification requires.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-10', 'hl7.fhir.us.davinci-crd_2.2.1@conf-12',
                            'hl7.fhir.us.davinci-crd_2.2.1@conf-13', 'hl7.fhir.us.davinci-crd_2.2.1@found-33'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :data_element_expectations_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module does not set expectations for data elements beyond those the CRD
              specification requires.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :data_element_expectations_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert data_element_expectations_attestation == 'true'
      end
    end
  end
end
