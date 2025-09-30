require_relative 'client_fhir_api_group'
require_relative 'client_hooks_group'
require_relative 'client_registration_group'
require_relative 'routes/cds_services_discovery_handler'
require_relative 'tags'
require_relative 'urls'
require_relative 'crd_options'
require_relative 'routes/hook_request_endpoint'
require_relative 'ext/inferno_core/runnable'

module DaVinciCRDTestKit
  class CRDClientSuite < Inferno::TestSuite
    id :crd_client
    title 'Da Vinci CRD Client Test Suite'
    description <<~DESCRIPTION
      The Da Vinci CRD Client Test Suite tests the conformance of client systems
      to [version 2.0.1 of the Da Vinci Coverage Requirements Discovery (CRD)
      Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2).

      ## Overview
      This suite contains two groups of tests. The Hooks group receives and
      responds to incoming CDS Hooks requests from CRD clients. The FHIR API
      group makes FHIR requests to CRD Clients to verify that they support the
      FHIR interactions defined in the implementation guide.

      ## CDS Services
      This suite provides basic CDS services for [the six hooks contained in the
      implementation
      guide](https://hl7.org/fhir/us/davinci-crd/STU2/hooks.html). The discovery
      endpoint is located at:

      * `#{Inferno::Application['base_url']}/custom/#{id}/cds-services`

      ## SMART App Launch
      Use this information when registering Inferno as a SMART App:

      * Launch URI: `#{SMARTAppLaunch::AppLaunchTest.config.options[:launch_uri] ||
                       "#{Inferno::Application['base_url']}/custom/smart/launch"}`
      * Redirect URI: `#{SMARTAppLaunch::AppRedirectTest.config.options[:redirect_uri] ||
                         "#{Inferno::Application['base_url']}/custom/smart/redirect"}`

      If a client receives a SMART App Launch card in a response and would like
      to test their ability to launch Inferno as a SMART App, first run the
      SMART on FHIR Discovery and SMART EHR Launch groups under FHIR API >
      Authorization. When running the SMART EHR Launch group, Inferno will wait
      for the incoming SMART App Launch request, and this is the time to perform
      the launch from the client being tested.

      ## Running the Tests
      If you would like to try out the tests against [the public CRD reference
      client](https://crd-request-generator.davinci.hl7.org/), you can do so by:
      1. Selecting the *CRD Request Generator RI* option from the Preset
         dropdown in the upper left.
      2. Selecting the *order-sign* hook group on the left menu.
      3. Clicking on the *RUN TESTS* button in the upper right.
      4. Clicking the *Submit* button at the bottom of the input dialog.
      5. Follow the instructions in the wait dialog.
      6. Open the reference client in another tab/browser.
      7. Update the *CRD Server* field in the client configuration to point to
         the discovery endpoint of this suite provided above, and the *Order
         Sign Rest End Point*
         to the service id provided in the wait dialog.
      8. Select the patient data to be used to form the request, then submit the
         request.

      You can run these tests using your own client by updating the inputs with
      your own data.

      Note that:
      - You can only sequentially *RUN ALL TESTS* if your system supports all
        hooks.
      - Systems are not expected to pass the *FHIR RESTful Capabilities* tests
        based on the provided inputs, as the resource might not exist on the
        client's FHIR server.

      ## Running the Tests aginst the Server Suite

      You can also run the Hook Invocation portion of these tests against the
      Inferno CRD Server test suite. The server suite will not render cards
      like a real CRD client would do, but will simulate and verify the
      interactions between the client and server.

      1. Start a "Da Vinci CRD Client Test Suite" session.
      1. Choose the "Run Against the CRD Server Suite" preset from the drop down in the upper left.
      1. Run the Hook Invocation test group, leaving the inputs as-is. A
         "User Action Dialog" will appear indicating that Inferno is waiting for the
         `appointment-book` hook invocation.
      1. In another tab, start a "Da Vinci CRD Server Test Suite" session.
      1. Choose the "Run Against the CRD Client Suite" preset from the drop down in the upper left.
      1. Run the Discovery test group. It should pass.
      1. Run the Demonstrate A Hook Response test. It should pass
      1. Run the 6 individual hook tests by using the following steps:
         1. In the Client Suite session, check which hook is indicated in the current "User Action
            Required" dialog.
         1. Return to the Server Suite session, and run the corresponding Hook Tests test group, leaving
            the inputs as-is.
         1. Once the server tests complete, return to the Client Suite session and click the link to
            indicate all requests have been submitted.
         1. A new "User Action Required" dialog will appear asking you to verify that all of the
            returned cards were displayed to the user. The CRD client simulation in the Server Suite
            does not display the cards, but does check that they were returned correctly. Click the
            "true" link if the corresponding server tests had no failures or skips, including on
            optional tests. Otherwise click the "false" link.
         1. The Client Suite session will continue to the next hook, or complete if they have all been tested.
      1. Review the results of the tests. Most tests should pass, but some may fail.

      ## Limitations
      The test suite does not implement any sort of payer business logic, so the
      responses to hook calls are simple hard-coded responses. Hook
      configuration is not tested.
    DESCRIPTION

    suite_summary <<~SUMMARY
      The Da Vinci CRD Client Test Suite tests the conformance of client systems
      to [version 2.0.1 of the Da Vinci Coverage Requirements Discovery (CRD)
      Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2).
    SUMMARY

    links [
      {
        label: 'Report Issue',
        url: 'https://github.com/inferno-framework/davinci-crd-test-kit/issues'
      },
      {
        label: 'Open Source',
        url: 'https://github.com/inferno-framework/davinci-crd-test-kit'
      },
      {
        label: 'Download',
        url: 'https://github.com/inferno-framework/davinci-crd-test-kit/releases'
      }
    ]

    requirement_sets(
      {
        identifier: 'hl7.fhir.us.davinci-crd_2.0.1',
        title: 'Da Vinci Coverage Requirements Discovery (CRD) v2.0.1',
        actor: 'Client'
      }
    )

    fhir_resource_validator do
      igs('hl7.fhir.us.davinci-crd#2.0.1')

      exclude_message do |message|
        message.message.match?(/\A\S+: \S+: URL value '.*' does not resolve/)
      end
    end

    suite_option :smart_app_launch_version,
                 title: 'SMART App Launch Version',
                 list_options: [
                   {
                     label: 'SMART App Launch 1.0.0',
                     value: CRDOptions::SMART_1
                   },
                   {
                     label: 'SMART App Launch 2.0.0',
                     value: CRDOptions::SMART_2
                   }
                 ]

    def self.extract_token_from_query_params(request)
      request.query_parameters['token']
    end

    route :get, '/cds-services', Routes::CDSServicesDiscoveryHandler
    # TODO
    # route :post, '/cds-services/:cds-service_id', cds_service_handler

    allow_cors APPOINTMENT_BOOK_PATH, ENCOUNTER_START_PATH, ENCOUNTER_DISCHARGE_PATH, ORDER_DISPATCH_PATH,
               ORDER_SELECT_PATH, ORDER_SIGN_PATH
    suite_endpoint :post, APPOINTMENT_BOOK_PATH, HookRequestEndpoint
    suite_endpoint :post, ENCOUNTER_START_PATH, HookRequestEndpoint
    suite_endpoint :post, ENCOUNTER_DISCHARGE_PATH, HookRequestEndpoint
    suite_endpoint :post, ORDER_DISPATCH_PATH, HookRequestEndpoint
    suite_endpoint :post, ORDER_SELECT_PATH, HookRequestEndpoint
    suite_endpoint :post, ORDER_SIGN_PATH, HookRequestEndpoint

    resume_test_route :get, RESUME_PASS_PATH do |request|
      CRDClientSuite.extract_token_from_query_params(request)
    end
    resume_test_route :get, RESUME_FAIL_PATH, result: 'fail' do |request|
      CRDClientSuite.extract_token_from_query_params(request)
    end

    group do
      id :crd_client_hook_invocation
      title 'Hook Invocation'
      description %(
        This groups checks that the system can register as a CDS Client with
        Inferno's simulated CRD Server and make hook invocations.
      )

      group from: :crd_client_registration
      group from: :crd_client_hooks
    end

    group from: :crd_client_fhir_api
  end
end
