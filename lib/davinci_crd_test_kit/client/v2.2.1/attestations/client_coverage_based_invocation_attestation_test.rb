require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class CoverageBasedInvocationAttestationTest < Inferno::Test
      id :crd_v221_coverage_based_invocation_attestation
      ATTESTATION_TITLE = 'Health IT module invokes hooks appropriately based on active coverage(s)'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module invokes hooks on payer services
        appropriately based on the patient's active coverages.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-26', 'hl7.fhir.us.davinci-crd_2.2.1@dev-28',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-30', 'hl7.fhir.us.davinci-crd_2.2.1@dev-32'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :coverage_based_invocation_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module invokes hooks on payer services appropriately based on the
              patient's active coverages.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :coverage_based_invocation_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert coverage_based_invocation_attestation == 'true'
      end
    end
  end
end
