require_relative 'jwt_helper'
require_relative 'routes/jwk_set_endpoint_handler'
require_relative 'server_discovery_group'
require_relative 'server_demonstrate_hook_response_group'
require_relative 'server_hooks_group'

module DaVinciCRDTestKit
  class CRDServerSuite < Inferno::TestSuite
    id :crd_server
    title 'Da Vinci CRD Server Test Suite'
    description <<~DESCRIPTION
      The Da Vinci CRD Server Test Suite tests the conformance of server systems
      to [version 2.0.1 of the Da Vinci Coverage Requirements Discovery (CRD)
      Implementation Guide](https://hl7.org/fhir/us/davinci-crd/STU2).

      ## Overview
      This suite contains three groups of tests:
      1. The *Discovery* group validates a CRD server's discovery response.
      2. The *Demonstrate A Hook Response* group validates that the server
         can respond to a single hook invocation and return conformant cards.
      3. The *Hooks* group makes one or more CDS Hooks calls for each hook
         type that the tester provides request bodies for. It then validates that the
         responses are conformant and cover the full range of cards as
         required by the hook type.

      ## Trusting CDS Clients
      As specified in the [CDS Hooks Spec](https://cds-hooks.hl7.org/2.0/#trusting-cds-clients),
      Each time a CDS Client transmits a request to a CDS Service which
      requires authentication, the request MUST include an Authorization
      header presenting the JWT as a “Bearer” token:
      `Authorization:  Bearer {{JWT}}`

      Inferno self-issues the JWT for each CDS Service call. The following
      info is needed to register Inferno:

        - **ISS**:  `#{Inferno::Application[:base_url]}/custom/crd_server`
        - **JWK Set Url**:
            `#{Inferno::Application[:base_url]}/custom/crd_server/jwks.json`

      ## Running the Tests
      Execution of these tests require a significant amount of tester input in
      the form of requests that Inferno will make against the server under test.

      If you would like to try out the tests using examples from the IG and the
      [CDS Hooks spec](https://cds-hooks.hl7.org/2.0/) against [the public CRD
      reference server endpoint](https://crd.davinci.hl7.org/), you can do so
      by:
      1. Selecting the *CRD Server RI* option from the
         Preset dropdown in the upper left
      2. Clicking the *Run All Tests* button in the upper right
      3. Clicking the *Submit* button at the bottom of the input dialog

      You can run these tests using your own server by updating the "CRD server
      base URL" and, if needed, providing requests inputs you wish to use for
      each hook your server supports.

      Note that the provided inputs for these tests are not complete and systems
      are not expected to pass the tests based on them.

      ## Running the Tests aginst the Client Suite

      You can also run these tests against the
      Inferno CRD Client test suite. The client suite will generate sample cards to
      return for these tests to evaluate.

      1. Start a "Da Vinci CRD Client Test Suite" session using the "SMART App Launch 2.0.0"
         option.
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
      Inferno is unable to determine what requests will result in specific kinds
      of responses from the server under test (e.g., what will result in
      Instructions being returned vs. Coverage Information). As a result, the
      tester must supply the request bodies which will cause the system under
      test to return the desired response types.

      The ability of a CRD Server to request additional FHIR resources is not
      tested. Hook configuration is not tested.
    DESCRIPTION

    suite_summary <<~SUMMARY
      The Da Vinci CRD Server Test Suite tests the conformance of server systems
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
        actor: 'Server'
      }
    )

    input :base_url,
          title: 'CRD server base URL'

    fhir_resource_validator do
      igs('hl7.fhir.us.davinci-crd#2.0.1')

      exclude_message do |message|
        message.message.match?(/\A\S+: \S+: URL value '.*' does not resolve/)
      end
    end

    def inferno_base_url
      suite_id = self.class.suite.id
      @inferno_base_url ||= "#{Inferno::Application['base_url']}/custom/#{suite_id}"
    end

    route :get, '/jwks.json', Routes::JWKSetEndpointHandler

    group from: :crd_server_discovery_group

    group from: :crd_server_demonstrate_hook_response

    group from: :crd_server_hooks
  end
end
