require_relative '../urls'

module DaVinciCRDTestKit
  class OrderSignReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_order_sign_request
    title 'Request received for order-sign hook'
    description %(
        This test waits for an incoming [order-sign](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)
        hook request and responds to the client with the response types selected as an input. This hook is a 'primary'
        hook, meaning that CRD Servers SHALL, at minimum, return a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
        system action for these hooks, even if the response indicates that further information is needed or that the
        level of detail provided is insufficient to determine coverage.
      )
    receives_request :order_sign

    input :iss
    input :order_sign_selected_response_types,
          title: 'Response types to return from order-sign hook requests',
          description: %(
            Select the cards/action response types that the Inferno hook request endpoints will return. The default
            response type that will be returned for this hook is the `Coverage Information` card type.
          ),
          type: 'checkbox',
          default: ['coverage_information'],
          options: {
            list_options: [
              {
                label: 'External Reference',
                value: 'external_reference'
              },
              {
                label: 'Instructions',
                value: 'instructions'
              },
              {
                label: 'Coverage Information',
                value: 'coverage_information'
              },
              {
                label: 'Request Form Completion',
                value: 'request_form_completion'
              },
              {
                label: 'Create/Update Coverage Information',
                value: 'create_update_coverage_info'
              },
              {
                label: 'Launch SMART Application',
                value: 'launch_smart_app'
              },
              {
                label: 'Propose Alternate Request',
                value: 'propose_alternate_request'
              },
              {
                label: 'Additional Orders as Companions/Prerequisites',
                value: 'companions_prerequisites'
              }
            ]
          }

    run do
      wait(
        identifier: "order-sign #{iss}",
        message: %(
          **Order Sign CDS Service Test**:

          Invoke the order-sign hook and send a request to:

          `#{order_sign_url}`

          Inferno will process the request and return CDS cards if successful.
        )
      )
    end
  end
end
