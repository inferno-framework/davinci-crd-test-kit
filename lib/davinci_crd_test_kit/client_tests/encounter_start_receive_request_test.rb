require_relative '../urls'

module DaVinciCRDTestKit
  class EncounterStartReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_encounter_start_request
    title 'Request received for encounter-start hook'
    description %(
      This test waits for multiple incoming [encounter-start](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-start)
      hook requests and responds to the client with the response types selected as an input.
      )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@186', 'hl7.fhir.us.davinci-crd_2.0.1@243',
                          'hl7.fhir.us.davinci-crd_2.0.1@244', 'hl7.fhir.us.davinci-crd_2.0.1@245',
                          'hl7.fhir.us.davinci-crd_2.0.1@297', 'hl7.fhir.us.davinci-crd_2.0.1@303'

    config options: { accepts_multiple_requests: true }

    input :iss
    input :encounter_start_selected_response_types,
          title: 'Response types to return from encounter-start hook requests',
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
              }
            ]
          }
    input :encounter_start_custom_response,
          title: 'Custom response for encounter-start hook requests',
          description: %(
            A JSON string may be provided here to replace the normal response
            from the hook request endpoint
          ),
          type: 'textarea',
          optional: true

    run do
      wait(
        identifier: "encounter-start #{iss}",
        message: %(
          **Encounter Start CDS Service Test**:

          Invoke the encounter-start hook and send requests to:

          `#{encounter_start_url}`

          Inferno will process the requests and return CDS cards if successful.

          [Click here](#{resume_pass_url}?token=enounter-start%20#{iss}) when you have finished submitting requests.
        )
      )
    end
  end
end
