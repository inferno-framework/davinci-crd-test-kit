require_relative '../urls'

module DaVinciCRDTestKit
  class AppointmentBookReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_appointment_book_request
    title 'Request received for appointment-book hook'
    description %(
        This test waits for an incoming [appointment-book](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#appointment-book)
        hook request and responds to the client with the response types selected as an input. This hook is a 'primary'
        hook, meaning that CRD Servers SHALL, at minimum, return a [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
        system action for these hooks, even if the response indicates that further information is needed or that the
        level of detail provided is insufficient to determine coverage.
      )
    receives_request :appointment_book

    input :iss
    input :appointment_book_selected_response_types,
          title: 'Response types to return from appointment-book hook requests',
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
              }
            ]
          }

    run do
      wait(
        identifier: "appointment-book #{iss}",
        message: %(
          **Appointment Book CDS Service Test**:

          Invoke the appointment-book hook and send a request to:

          `#{appointment_book_url}`

          Inferno will process the request and return CDS cards if successful.
        )
      )
    end
  end
end
