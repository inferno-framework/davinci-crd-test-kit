require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class AppointmentBookReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v221_appointment_book_request
      title 'Client invokes the appointment-book hook'
      description %(
        During this test, Inferno will wait while the client makes one or more [appointment-book](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#appointment-book)
        hook requests against Inferno's simulated CRD servers. Inferno will respond
        based on the response configuration provided when running the test.
        For more details on how Inferno's simulated CRD servers behave during
        hook invocation see the [simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#crd-server-simulation)
        documentation.

        Inferno will pause and wait for inbound requests until told explicitly to continue
        by the tester by clicking on the link in the "User Action Required" dialog (NOTE: after
        5 minutes the test will become inactive and unresponsive to anything except cancelation).
      )
      config options: { accepts_multiple_requests: true }

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the client's hook
              request sent as the Bearer token in the `Authorization` header.
              Run or re-run the "Registration" group to set or change this value.
            ),
            locked: true
      input :appointment_book_selected_response_types,
            title: 'Response types to return from appointment-book hook requests',
            description: %(
              Select the CRD response types that the simulated Inferno CRD server will [mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
              when responding to hook invocations. If no types are selected, Inferno will mock and return
              a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
              response for this primary hook.
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
                }
              ]
            }
      input :appointment_book_custom_response_template,
            title: 'Custom response template for appointment-book hook requests',
            description: %(
              To control the responses of Inferno's simulated CRD server, provide
              a [custom response template](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
              in JSON form for Inferno to use when responding to hook invocations.
              If this input is populated, the corresponding **Response types to return**
              input will be ignored.
            ),
            type: 'textarea',
            optional: true
      output :continuation_url

      run do
        identifier = cds_jwt_iss
        continuation_url = "#{resume_pass_url}?token=#{identifier}"
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            **Appointment Book CDS Service Test**:

            Invoke the appointment-book hook and send requests to:

            `#{appointment_book_url}`

            Inferno will process the requests and return CDS cards if successful.

            [Click here](#{continuation_url}) when you have finished
            submitting requests.
          )
        )
      end
    end
  end
end
