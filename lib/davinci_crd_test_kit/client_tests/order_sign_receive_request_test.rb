require_relative '../urls'

module DaVinciCRDTestKit
  class OrderSignReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_order_sign_request
    title 'Request received for order-sign hook'
    description %(
        This test waits for multiple incoming [order-sign](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-sign)
        hook requests and responds to the client with the response types selected as an input. This hook is a 'primary'
        hook, meaning that CRD Servers SHALL, at minimum, return a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
        system action for these hooks, even if the response indicates that further information is needed or that the
        level of detail provided is insufficient to determine coverage.
      )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@218', 'hl7.fhir.us.davinci-crd_2.0.1@225',
                          'hl7.fhir.us.davinci-crd_2.0.1@243', 'hl7.fhir.us.davinci-crd_2.0.1@244',
                          'hl7.fhir.us.davinci-crd_2.0.1@245', 'hl7.fhir.us.davinci-crd_2.0.1@284',
                          'hl7.fhir.us.davinci-crd_2.0.1@289', 'hl7.fhir.us.davinci-crd_2.0.1@290',
                          'hl7.fhir.us.davinci-crd_2.0.1@291', 'hl7.fhir.us.davinci-crd_2.0.1@292',
                          'hl7.fhir.us.davinci-crd_2.0.1@293', 'hl7.fhir.us.davinci-crd_2.0.1@294',
                          'hl7.fhir.us.davinci-crd_2.0.1@295'

    config options: { accepts_multiple_requests: true }

    input :iss
    input :order_sign_selected_response_types,
          title: 'Response types to return from order-sign hook requests',
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
    input :order_sign_custom_response,
          title: 'Custom response for order-sign hook requests',
          description: %(
            A JSON string may be provided here to replace the normal response
            from the hook request endpoint
          ),
          type: 'textarea',
          optional: true

    run do
      wait(
        identifier: "order-sign #{iss}",
        message: %(
          **Order Sign CDS Service Test**:

          Invoke the order-sign hook and send requests to:

          `#{order_sign_url}`

          Inferno will process the requests and return CDS cards if successful.

          [Click here](#{resume_pass_url}?token=order-sign%20#{iss}) when you have finished submitting requests.
        )
      )
    end
  end
end
