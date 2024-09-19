require_relative '../urls'

module DaVinciCRDTestKit
  class OrderDispatchReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_order_dispatch_request
    title 'Request received for order-dispatch hook'
    description %(
        This test waits for multiple incoming [order-dispatch](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-dispatch)
        hook requests and responds to the client with the response types selected as an input. This hook is a 'primary'
        hook, meaning that CRD Servers SHALL, at minimum, return a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
        system action for these hooks, even if the response indicates that further information is needed or that the
        level of detail provided is insufficient to determine coverage.
      )

    config options: { accepts_multiple_requests: true }

    input :iss
    input :order_dispatch_selected_response_types,
          title: 'Response types to return from order-dispatch hook requests',
          description: %(
            Select the cards/action response types that the Inferno hook request endpoints will return. The default
            response type that will be returned for this hook is the `Coverage Information` card type.
          ),
          type: 'checkbox',
          default: ['coverage_information', 'external_reference', 'instructions'],
          optional: true,
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
    input :order_dispatch_custom_response,
          title: 'Custom response for order-dispatch hook requests',
          description: %(
            A JSON string may be provided here to replace the normal response
            from the hook request endpoint
          ),
          type: 'textarea',
          optional: true

    run do
      wait(
        identifier: "order-dispatch #{iss}",
        message: %(
          **Order Dispatch CDS Service Test**:

          Invoke the order-dispatch hook and send requests to:

          `#{order_dispatch_url}`

          Inferno will process the requests and return CDS cards if successful.

          [Click here](#{resume_pass_url}?token=order-dispatch%20#{iss}) when you have finished submitting requests.
        )
      )
    end
  end
end
