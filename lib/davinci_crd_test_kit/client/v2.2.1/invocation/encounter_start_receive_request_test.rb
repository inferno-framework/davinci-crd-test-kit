require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class EncounterStartReceiveRequestTest < Inferno::Test
      include ClientURLs

      id :crd_v221_encounter_start_request
      title 'Client invokes the encounter-start hook'
      description %(
        During this test, Inferno will wait while the client makes one or more [encounter-start](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/hooks.html#encounter-start)
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
      input :encounter_start_response_approach,
            title: 'Response generation approach for encounter-start',
            description: %(
              Determines how Inferno will generate response for encounter-start
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
      input :encounter_start_selected_response_types,
            title: 'Response types to return from encounter-start hook requests',
            description: %(
              Select the CRD response types that the simulated Inferno CRD server will [mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses)
              when responding to hook invocations. If no types are selected, Inferno will mock and return
              an [Instructions](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#instructions-response-type)
              response for this secondary hook.
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
            enable_when: { input_name: 'encounter_start_response_approach', value: 'mocked' }
      input :encounter_start_custom_response_template,
            title: 'Custom response template for encounter-start hook requests',
            description: %(
              Provide a [custom response template](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses)
              in JSON form for Inferno to use when responding to hook invocations.
            ),
            type: 'textarea',
            optional: true,
            enable_when: { input_name: 'encounter_start_response_approach', value: 'custom' }
      output :continuation_url

      def configured_response_details
        if encounter_start_response_approach == 'custom'
          # rubocop:disable Layout/LineLength
          'When responding, Inferno will evaluate the provided [custom response template](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses) ' \
            'from the **Custom response template for encounter-start hook requests** input ' \
            'against the incoming request to create a response.'
          # rubocop:enable Layout/LineLength

        else
          # rubocop:disable Layout/LineLength
          'When responding, Inferno will [mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses) ' \
            'the following response types using the incoming request: ' \
            "\n            - #{selected_response_types_string}"
          # rubocop:enable Layout/LineLength
        end
      end

      def selected_response_types_string
        if encounter_start_selected_response_types.present?
          encounter_start_selected_response_types.join("\n            - ")
        else
          'Instructions' # secondary hook default
        end
      end

      run do
        identifier = cds_jwt_iss
        continuation_url = "#{resume_pass_url}?token=#{identifier}"
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            **Invoke the `encounter-start` hook**:

            Invoke the encounter-start hook by sending requests to
            one or both of the two Inferno simulated CRD servers:

            - Complete Prefetch: `#{encounter_start_url}`
            - Subset Prefetch: `#{encounter_start_prefetch_subset_url}`

            For Inferno to recognize these requests and associate them with this session,
            the authentication JWT sent as a Bearer token in the Authorization header
            must have `#{cds_jwt_iss}` as the `iss` claim in the JWT payload.

            #{configured_response_details}

            [Click here](#{continuation_url}) when you have finished submitting requests.
          )
        )
      end
    end
  end
end
