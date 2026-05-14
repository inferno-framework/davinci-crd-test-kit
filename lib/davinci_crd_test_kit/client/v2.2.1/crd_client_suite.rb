require_relative 'client_fhir_api_group'
require_relative 'client_hooks_group'
require_relative 'client_cross_hook_group'
require_relative 'client_registration_group'
require_relative 'client_long_running_hook_group'
require_relative '../endpoints/cds_services_discovery_handler'
require_relative '../../cross_suite/tags'
require_relative 'client_urls'
require_relative '../crd_client_options'
require_relative '../endpoints/hook_request_endpoint'
require_relative '../../ext/inferno_core/runnable'

module DaVinciCRDTestKit
  module V221
    class CRDClientSuite < Inferno::TestSuite
      id :crd_client_v221
      title 'Da Vinci CRD Client v2.2.1 Test Suite'
      description <<~DESCRIPTION
        The Da Vinci CRD Client Test Suite tests the conformance of client systems
        to [version 2.2.1 of the Da Vinci Coverage Requirements Discovery (CRD)
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
          identifier: 'hl7.fhir.us.davinci-crd_2.2.1',
          title: 'Da Vinci Coverage Requirements Discovery (CRD) v2.2.1',
          actor: 'CRD Client'
        },
        {
          identifier: 'cds-hooks_3.0.0-ballot',
          title: 'CDS Hooks 3.0.0-ballot',
          actor: 'Client'
        },
        {
          identifier: 'cds-hooks-library_1.0.1',
          title: 'CDS Hooks Library',
          actor: 'Client',
          requirements: 'referenced'
        },
        {
          identifier: 'hl7.fhir.us.core_3.1.1',
          title: 'US Core Implementation Guide v3.1.1',
          actor: 'Server',
          suite_options: {
            us_core_version: CRDClientOptions::US_CORE_3
          }
        },
        {
          identifier: 'hl7.fhir.us.core_6.1.0',
          title: 'US Core Implementation Guide v6.1.0',
          actor: 'Server',
          suite_options: {
            us_core_version: CRDClientOptions::US_CORE_6
          }
        },
        {
          identifier: 'hl7.fhir.us.core_7.0.0',
          title: 'US Core Implementation Guide v7.0.0',
          actor: 'Server',
          suite_options: {
            us_core_version: CRDClientOptions::US_CORE_7
          }
        }
      )

      verifies_requirements 'cds-hooks_3.0.0-ballot@1', # use of json for everything verified across the whole suite
                            'cds-hooks_3.0.0-ballot@15', # use of POST verified by suite endpoint setup
                            'cds-hooks_3.0.0-ballot@208', # use of CORS endpoints defined in the suite
                            'hl7.fhir.us.davinci-crd_2.2.1@impl-3' # suite verifies system interactions

      fhir_resource_validator do
        igs('hl7.fhir.us.davinci-crd#2.2.1')

        exclude_message do |message|
          [
            /\A\S+: \S+: URL value '.*' does not resolve/,
            %r{This element is not allowed by the profile http://hl7\.org/fhir/tools/StructureDefinition/CDSHooksExtensions\|1\.1\.2},
            /CDSHooksRequest.extension: Unrecognized property/
          ].any? { |match_template| message.message.match?(match_template) }
        end
      end

      suite_option :us_core_version,
                   title: 'US Core Version',
                   list_options: [
                     {
                       label: 'US Core 3.1.1 / USCDI v1',
                       value: CRDClientOptions::US_CORE_3
                     },
                     {
                       label: 'US Core 6.1.0 / USCDI v3',
                       value: CRDClientOptions::US_CORE_6
                     },
                     {
                       label: 'US Core 7.0.0 / USCDI v4',
                       value: CRDClientOptions::US_CORE_7
                     }
                   ]

      def self.extract_token_from_query_params(request)
        request.query_parameters['token']
      end

      route :get, '/cds-services', CDSServicesDiscoveryHandler
      route :get, '/prefetch-subset/cds-services', CDSServicesDiscoveryHandler

      allow_cors APPOINTMENT_BOOK_PATH, ENCOUNTER_START_PATH, ENCOUNTER_DISCHARGE_PATH, ORDER_DISPATCH_PATH,
                 ORDER_SELECT_PATH, ORDER_SIGN_PATH, '/cds-services'
      suite_endpoint :post, APPOINTMENT_BOOK_PATH, HookRequestEndpoint
      suite_endpoint :post, ENCOUNTER_START_PATH, HookRequestEndpoint
      suite_endpoint :post, ENCOUNTER_DISCHARGE_PATH, HookRequestEndpoint
      suite_endpoint :post, ORDER_DISPATCH_PATH, HookRequestEndpoint
      suite_endpoint :post, ORDER_SELECT_PATH, HookRequestEndpoint
      suite_endpoint :post, ORDER_SIGN_PATH, HookRequestEndpoint

      allow_cors APPOINTMENT_BOOK_PREFETCH_SUBSET_PATH, ENCOUNTER_START_PREFETCH_SUBSET_PATH,
                 ENCOUNTER_DISCHARGE_PREFETCH_SUBSET_PATH, ORDER_DISPATCH_PREFETCH_SUBSET_PATH,
                 ORDER_SELECT_PREFETCH_SUBSET_PATH, ORDER_SIGN_PREFETCH_SUBSET_PATH,
                 '/prefetch-subset/cds-services'
      suite_endpoint :post, APPOINTMENT_BOOK_PREFETCH_SUBSET_PATH, HookRequestEndpoint
      suite_endpoint :post, ENCOUNTER_START_PREFETCH_SUBSET_PATH, HookRequestEndpoint
      suite_endpoint :post, ENCOUNTER_DISCHARGE_PREFETCH_SUBSET_PATH, HookRequestEndpoint
      suite_endpoint :post, ORDER_DISPATCH_PREFETCH_SUBSET_PATH, HookRequestEndpoint
      suite_endpoint :post, ORDER_SELECT_PREFETCH_SUBSET_PATH, HookRequestEndpoint
      suite_endpoint :post, ORDER_SIGN_PREFETCH_SUBSET_PATH, HookRequestEndpoint

      resume_test_route :get, RESUME_PASS_PATH do |request|
        CRDClientSuite.extract_token_from_query_params(request)
      end
      resume_test_route :get, RESUME_FAIL_PATH, result: 'fail' do |request|
        CRDClientSuite.extract_token_from_query_params(request)
      end

      group do
        id :crd_v221_client_hook_invocation
        title 'Hook Invocation'
        description %(
          This groups checks that the system can register as a CDS Client with
          Inferno's simulated CRD Server and make hook invocations.
        )

        group from: :crd_v221_client_registration
        group from: :crd_v221_client_hooks
        group from: :crd_v221_client_cross_hook
        group from: :crd_v221_client_long_running_hook
      end

      group from: :crd_v221_client_fhir_api
    end
  end
end
