require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class PrefetchKeyOmissionAttestationTest < Inferno::Test
      id :crd_v221_prefetch_key_omission_attestation
      ATTESTATION_TITLE = 'Health IT module omits prefetch keys when data not available'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module omits prefetch keys when the relevant
        data cannot be provided.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'cds-hooks_3.0.0-ballot@51'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :prefetch_key_omission_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module omits prefetch keys when the relevant data cannot be provided.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :prefetch_key_omission_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert prefetch_key_omission_attestation == 'true'
      end
    end
  end
end
