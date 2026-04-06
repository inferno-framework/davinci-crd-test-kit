require_relative '../client_urls'

module DaVinciCRDTestKit
  module V220
    class AppointmentBookReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v220_appointment_book_request
      title 'Request received for appointment-book hook'
      description %(
        This test waits for multiple incoming [appointment-book](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
        hook requests and responds to the client with the response types selected as an input. This hook is a 'primary'
        hook, meaning that CRD Servers SHALL, at minimum, return a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
        system action for these hooks, even if the response indicates that further information is needed or that the
        level of detail provided is insufficient to determine coverage.

        For more details on how Inferno's simulated CDS Service behave during hook invocation see the
        [Simulated CDS Services](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#cds-services)
        documentation.
      )
      config options: { accepts_multiple_requests: true }
      # verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@171',
      #                       'hl7.fhir.us.davinci-crd_2.0.1@183', 'hl7.fhir.us.davinci-crd_2.0.1@243',
      #                       'hl7.fhir.us.davinci-crd_2.0.1@244', 'hl7.fhir.us.davinci-crd_2.0.1@245',
      #                       'cds-hooks_2.0@15'

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be sent on the Bearer token in the `Authorization`
              header of all requests. Run or re-run the **Client Registration** group to set or
              change this value.
            ),
            locked: true
      input :appointment_book_selected_response_types,
            title: 'Response types to return from appointment-book hook requests',
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
                }
              ]
            }
      input :appointment_book_custom_response_template,
            title: 'Custom response for appointment-book hook requests',
            description: %(
              A JSON string may be provided here to replace the normal response
              from the hook request endpoint
            ),
            type: 'textarea',
            optional: true
      output :continuation_url

      run do
        identifier = "appointment-book #{cds_jwt_iss}"
        continuation_url = "#{resume_pass_url}?token=#{identifier.gsub(' ', '%20')}"
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
