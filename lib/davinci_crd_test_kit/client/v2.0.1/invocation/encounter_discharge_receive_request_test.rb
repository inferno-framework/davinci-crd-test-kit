require_relative '../client_urls'
require_relative '../../client_input_helper'

module DaVinciCRDTestKit
  module V201
    class EncounterDischargeReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v201_encounter_discharge_request
      title 'Request received for encounter-discharge hook'
      description %(
        This test waits for multiple incoming [encounter-discharge](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html#encounter-discharge)
        hook requests and responds to the client with the response types selected as an input.

        For more details on how Inferno's simulated CDS Service behave during hook invocation see the
        [simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details#simulated-crd-server-in-the-crd-client-v201-suite)
        documentation.
      )
      verifies_requirements 'hl7.fhir.us.davinci-crd_2.0.1@197', 'hl7.fhir.us.davinci-crd_2.0.1@243',
                            'hl7.fhir.us.davinci-crd_2.0.1@244', 'hl7.fhir.us.davinci-crd_2.0.1@245',
                            'cds-hooks_2.0@15'

      config options: { accepts_multiple_requests: true }

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: ClientInputHelper.v201_locked_cds_jwt_iss_description,
            locked: true
      input :encounter_discharge_response_approach,
            title: 'Response generation approach for encounter-discharge',
            description: ClientInputHelper.response_approach_description('encounter-discharge'),
            type: 'radio',
            default: 'mocked',
            options: ClientInputHelper.response_approach_options
      input :encounter_discharge_selected_response_types,
            title: 'Response types to return from encounter-discharge hook requests',
            description: %(
              #{ClientInputHelper.mocked_response_types_intro}
              #{ClientInputHelper.default_response_type_note(primary: false)}
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
            },
            enable_when: { input_name: 'encounter_discharge_response_approach', value: 'mocked' }
      input :encounter_discharge_custom_response_template,
            title: 'Custom response template for encounter-discharge hook requests',
            description: ClientInputHelper.custom_response_template_description,
            type: 'textarea',
            optional: true,
            enable_when: { input_name: 'encounter_discharge_response_approach', value: 'custom' }
      output :continuation_url
      flag_as_tester_initiated_exchange

      run do
        identifier = cds_jwt_iss
        continuation_url = resume_pass_url_for(identifier)
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            **Encounter Discharge CDS Service Test**:

            Invoke the encounter-discharge hook and send requests to:

            `#{encounter_discharge_url}`

            Inferno will process the requests and return CDS cards if successful.

            [Click here](#{continuation_url}) when you have finished submitting
            requests.
          )
        )
      end
    end
  end
end
