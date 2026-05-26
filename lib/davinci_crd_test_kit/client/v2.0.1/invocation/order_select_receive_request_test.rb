require_relative '../client_urls'

module DaVinciCRDTestKit
  module V201
    class OrderSelectReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v201_order_select_request
      title 'Request received for order-select hook'
      description %(
        This test waits for multiple incoming [order-select](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#order-select)
        hook requests and responds to the client with the response types selected as an input.

        For more details on how Inferno's simulated CDS Service behave during hook invocation see the
        [simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#crd-server-simulation)
        documentation.
      )
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@209', 'hl7.fhir.us.davinci-crd_2.0.1@243',
                            'hl7.fhir.us.davinci-crd_2.0.1@244', 'hl7.fhir.us.davinci-crd_2.0.1@245',
                            'cds-hooks_2.0@15'

      config options: { accepts_multiple_requests: true }

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be sent on the Bearer token in the `Authorization`
              header of all requests. Run or re-run the **Client Registration** group to set or
              change this value.
            ),
            locked: true
      input :order_select_response_approach,
            title: 'Response generation approach for order-select',
            description: %(
              Determines how Inferno will generate response for order-select
              hook invocations.
            ),
            type: 'radio',
            default: 'mocked',
            options: {
              list_options: [
                {
                  label: 'Create simple mocks based on selected response types',
                  value: 'mocked'
                },
                {
                  label: 'Generate responses based on a tester-provided template',
                  value: 'custom'
                }
              ]
            }
      input :order_select_selected_response_types,
            title: 'Response types to return from order-select hook requests',
            description: %(
              Select the cards/action response types that the Inferno hook request endpoints will return. The default
              response type that will be returned for this hook is the `Instructions` card type.
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
            },
            enable_when: { input_name: 'order_select_response_approach', value: 'mocked' }
      input :order_select_custom_response_template,
            title: 'Custom response template for order-select hook requests',
            description: %(
              Select the CRD response types that the simulated Inferno CRD server will [mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
              when responding to hook invocations. If no types are selected, Inferno will mock and return
              an [Instructions](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#instructions-response-type)
              response for this secondary hook.
            ),
            type: 'textarea',
            optional: true,
            enable_when: { input_name: 'order_select_response_approach', value: 'custom' }
      output :continuation_url

      run do
        identifier = cds_jwt_iss
        continuation_url = "#{resume_pass_url}?token=#{identifier}"
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            **Order Select CDS Service Test**:

            Invoke the order-select hook and send requests to:

            `#{order_select_url}`

            Inferno will process the requests and return CDS cards if successful.

            [Click here](#{continuation_url}) when you have finished submitting
            requests.
          )
        )
      end
    end
  end
end
