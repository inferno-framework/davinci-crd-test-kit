require_relative '../urls'

module DaVinciCRDTestKit
  class AppointmentBookReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_appointment_book_request
    title 'Request received for appointment-book hook'
    description %(
        This test waits for multiple incoming [appointment-book](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
        hook requests and responds to the client with the response types selected as an input. This hook is a 'primary'
        hook, meaning that CRD Servers SHALL, at minimum, return a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
        system action for these hooks, even if the response indicates that further information is needed or that the
        level of detail provided is insufficient to determine coverage.
      )
    config options: { accepts_multiple_requests: true }
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@164', 'hl7.fhir.us.davinci-crd_2.0.1@171',
                          'hl7.fhir.us.davinci-crd_2.0.1@183', 'hl7.fhir.us.davinci-crd_2.0.1@243',
                          'hl7.fhir.us.davinci-crd_2.0.1@244', 'hl7.fhir.us.davinci-crd_2.0.1@245'

    input :iss
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
    input :appointment_book_custom_response,
          title: 'Custom response for appointment-book hook requests',
          description: %(
            A JSON string may be provided here to replace the normal response
            from the hook request endpoint
          ),
          type: 'textarea',
          optional: true

    run do
      wait(
        identifier: "appointment-book #{iss}",
        message: %(
          **Appointment Book CDS Service Test**:

          Invoke the appointment-book hook and send requests to:

          `#{appointment_book_url}`

          Inferno will process the requests and return CDS cards if successful.

          [Click here](#{resume_pass_url}?token=appointment-book%20#{iss}) when you have finished submitting requests.
        )
      )
    end
  end
end
