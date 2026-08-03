require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class ResponseCaseDistinctionAttestationTest < Inferno::Test
      id :crd_v221_response_case_distinction_attestation
      ATTESTATION_TITLE = 'Health IT module distinguishes different response cases to users'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module distinguishes the different CRD
        response cases when presenting results to users.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@impl-1', 'hl7.fhir.us.davinci-crd_2.2.1@resp-49'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :response_case_distinction_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module distinguishes the different CRD response cases when presenting
              results to users.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :response_case_distinction_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert response_case_distinction_attestation == 'true'
      end
    end
  end
end
