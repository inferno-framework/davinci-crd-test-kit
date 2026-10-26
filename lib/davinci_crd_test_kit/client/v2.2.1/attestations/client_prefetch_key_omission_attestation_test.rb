require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class PrefetchKeyOmissionAttestationTest < Inferno::Test
      id :crd_v221_prefetch_key_omission_attestation
      ATTESTATION_TITLE = 'CRD client omits prefetch keys when data not available'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the CRD client omits prefetch keys when the relevant
        data cannot be provided, e.g., due to intermittent connectivity issues. Note that this is distinct
        from the normal case tested in the Hook Invocation group where CRD clients must demonstrate conditions
        under which they can provide complete prefetch data which includes present but empty entries when
        no information matches the requested data.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      flag_as_attestation
      verifies_requirements 'cds-hooks_3.0.0-ballot@51'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :prefetch_key_omission_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the CRD client omits prefetch keys when the relevant data cannot be provided.
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
