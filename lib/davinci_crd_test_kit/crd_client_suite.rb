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

      For details on the design and use of these tests, see the wiki including
      - [Suite Details](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Details)
        for a high-level description of the test
        organization, including its components and limitations.
      - [Testing Instructions](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Instructions)
        for a step-by-step guide to execution of these
        tests against a CRD client, including [instructions for a demonstration execution](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Instructions#demonstration-execution)
        against the [public reference implementation](https://crd-request-generator.davinci.hl7.org/).
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
