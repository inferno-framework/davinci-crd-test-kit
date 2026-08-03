require_relative 'attestation_instructions'

module DaVinciCRDTestKit
  module V221
    class OrderSignSupportAttestationTest < Inferno::Test
      id :crd_v221_order_sign_support_attestation
      ATTESTATION_TITLE = 'Health IT module supports order-sign for all types of orders that can be placed'.freeze
      title ATTESTATION_TITLE
      description %(
        During this test, the tester will confirm that the Health IT module supports the `order-sign` hook for all
        order types it can place.
        To see the specifics of the attested requirements, click the "View Specification Requirements" link for this
        test.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-3'
      input_instructions ATTESTATION_INPUT_INSTRUCTIONS

      input :order_sign_support_attestation,
            title: ATTESTATION_TITLE,
            description: %(
              I attest that the Health IT module supports the `order-sign` hook for all order types it can place.
            ),
            type: 'radio',
            default: 'false',
            options: {
              list_options: [
                { label: 'Yes', value: 'true' },
                { label: 'No', value: 'false' }
              ]
            }
      input :order_sign_support_attestation_note,
            title: 'Notes, if applicable:',
            type: 'textarea',
            optional: true

      run do
        assert order_sign_support_attestation == 'true'
      end
    end
  end
end
