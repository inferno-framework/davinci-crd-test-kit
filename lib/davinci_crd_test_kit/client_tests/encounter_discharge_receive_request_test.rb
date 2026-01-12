require_relative '../urls'

module DaVinciCRDTestKit
  class EncounterDischargeReceiveRequestTest < Inferno::Test
    include URLs

    id :crd_encounter_discharge_request
    title 'Request received for encounter-discharge hook'
    description %(
        This test waits for multiple incoming [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
        hook requests and responds to the client with the response types selected as an input.
      )
    verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@197', 'hl7.fhir.us.davinci-crd_2.0.1@243',
                          'hl7.fhir.us.davinci-crd_2.0.1@244', 'hl7.fhir.us.davinci-crd_2.0.1@245'

    config options: { accepts_multiple_requests: true }

    input :cds_jwt_iss,
          title: 'CRD JWT Issuer',
          description: %(
            Value of the `iss` claim that must be sent on the Bearer token in the `Authorization`
            header of all requests. Run or re-run the **Client Registration** group to set or
            change this value.
          ),
          locked: true
    input :encounter_discharge_selected_response_types,
          title: 'Response types to return from encounter-discharge hook requests',
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
    input :encounter_discharge_custom_response_template,
          title: 'Custom response for encounter-discharge hook requests',
          description: %(
            A JSON string may be provided here to replace the normal response
            from the hook request endpoint
          ),
          type: 'textarea',
          optional: true

    run do
      wait(
        identifier: "encounter-discharge #{cds_jwt_iss}",
        message: %(
          **Encounter Discharge CDS Service Test**:

          Invoke the encounter-discharge hook and send requests to:

          `#{encounter_discharge_url}`

          Inferno will process the requests and return CDS cards if successful.

          [Click here](#{resume_pass_url}?token=encounter-discharge%20#{cds_jwt_iss}) when you have finished submitting
          requests.
        )
      )
    end
  end
end
