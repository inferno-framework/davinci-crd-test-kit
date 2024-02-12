require_relative '../urls'

module DaVinciCRDTestKit
  class EncounterDischargeReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_encounter_discharge_request
    title 'Request received for encounter-discharge hook'
    description %(
        This test waits for an incoming [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
        hook request and responds to the client with the response types selected as an input.
      )
    receives_request :encounter_discharge

    input :iss
    input :encounter_discharge_selected_response_types,
          title: 'Response types to return from encounter-discharge hook requests',
          description: %(
            Select the cards/action response types that the Inferno hook request endpoints will return. The default
            response type that will be returned for this hook is the `Instructions` card type.
          ),
          type: 'checkbox',
          default: ['instructions'],
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
        identifier: "encounter-discharge #{iss}",
        message: %(
          **Encounter Discharge CDS Service Test**:

          Invoke the encounter-discharge hook and send a request to:

          `#{encounter_discharge_url}`

          Inferno will process the request and return CDS cards if successful.
        )
      )
    end
  end
end
