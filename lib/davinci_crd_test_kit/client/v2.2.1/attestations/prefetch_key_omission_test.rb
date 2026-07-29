module DaVinciCRDTestKit
  module V221
    class PrefetchKeyOmissionAttestationTest < Inferno::Test
      id :crd_v221_prefetch_key_omission_attestation
      title 'Health IT module omits prefetch keys when data not available'
      description %(
        The Health IT module omits a prefetch key from the hook request when the relevant details cannot be
        provided, for example because of intermittent connectivity issues.
      )
      attestation
      verifies_requirements 'cds-hooks_3.0.0-ballot@51'

      input :prefetch_key_omission_attestation,
            title: 'Health IT module omits prefetch keys when data not available',
            description: %(
              I attest that the Health IT module omits a prefetch key from the hook request when the relevant
              details cannot be provided, for example because of intermittent connectivity issues.
              ([CDS Hooks prefetch template](https://cds-hooks.hl7.org/2026Jan/en/index.html#prefetch-template))
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
        assert prefetch_key_omission_attestation == 'true',
               'Health IT module does not omit prefetch keys when the relevant details cannot be provided.'

        pass prefetch_key_omission_attestation_note if prefetch_key_omission_attestation_note.present?
      end
    end
  end
end
