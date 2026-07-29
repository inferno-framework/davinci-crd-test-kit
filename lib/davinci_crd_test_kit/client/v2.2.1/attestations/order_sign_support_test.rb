module DaVinciCRDTestKit
  module V221
    class OrderSignSupportAttestationTest < Inferno::Test
      id :crd_v221_order_sign_support_attestation
      title 'Health IT module supports order-sign for all types of orders that can be placed'
      description %(
        For the products and services it supports ordering that are covered by one of the CRD-supported request
        types, the Health IT module supports the `order-sign` hook for each of those order types.
      )
      attestation
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-3'

      input :order_sign_support_attestation,
            title: 'Health IT module supports order-sign for all types of orders that can be placed',
            description: %(
              I attest that, for the products and services it supports ordering that are covered by one of the
              CRD-supported request types, the Health IT module supports the `order-sign` hook for each of those
              order types.
              ([hook-3](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#ci-c-hook-3))
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
        assert order_sign_support_attestation == 'true',
               'Health IT module does not support the `order-sign` hook for all order types that it supports.'

        pass order_sign_support_attestation_note if order_sign_support_attestation_note.present?
      end
    end
  end
end
