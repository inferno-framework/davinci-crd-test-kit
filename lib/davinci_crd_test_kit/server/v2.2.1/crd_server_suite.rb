require_relative '../jwt_helper'
require_relative '../endpoints/jwk_set_endpoint_handler'
require_relative 'server_discovery_group'
require_relative 'server_demonstrate_hook_response_group'
require_relative 'server_hooks_group'
require_relative 'server_urls'
require_relative '../endpoints/mock_ehr_endpoints'

module DaVinciCRDTestKit
  module V221
    class CRDServerSuite < Inferno::TestSuite
      include ServerURLs

      id :crd_server_v221
      title 'Da Vinci CRD Server v2.2.1 Test Suite'
      description <<~DESCRIPTION
        The Da Vinci CRD Server v2.2.1 Test Suite tests the conformance of systems to the
        capabilities of a CRD server as described in [version 2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)
        of the Da Vinci Coverage Requirements Discovery (CRD) Implementation Guide.

        Detailed information about this test suite can be found in the
        [server section](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Details) of the
        [CRD Test Kit Wiki](https://github.com/inferno-framework/davinci-crd-test-kit/wiki), including:
        - [What testers need to successfully execute these tests](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions-v2.2.1#pre-execution-setup-and-required-information),
        - [Minimal](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions-v2.2.1#quick-start)
          and [complete](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions-v2.2.1#additional-testing-options)
          instructions for executing against a server system, and
        - How to [interpret test results](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions-v2.2.1#interpreting-results).
      DESCRIPTION

      suite_summary <<~SUMMARY
        The Da Vinci CRD Server v2.2.1 Test Suite tests the conformance of server systems
        to [version 2.2.1 of the Da Vinci Coverage Requirements Discovery (CRD)
        Implementation Guide](https://hl7.org/fhir/us/davinci-crd/2.2.1).
      SUMMARY

      links [
        {
          label: 'Implementation Guide',
          url: 'https://hl7.org/fhir/us/davinci-crd/2.2.1'
        },
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
          actor: 'CRD Server'
        }
      )

      input :base_url,
            title: 'CRD server base URL'

      fhir_resource_validator do
        igs(
          'hl7.fhir.us.davinci-crd#2.2.1',
          'hl7.fhir.us.core#3.1.1',
          'hl7.fhir.us.core#6.1.0',
          'hl7.fhir.us.core#7.0.0'
        )

        validation_context do
          snomedCT '731000124108' # explicit snomedCT expansion parameter
        end

        exclude_message do |message|
          message.message.match?(
            /Appointment\.participant\[.*\]: This element does not match any known slice defined in the profile/
          ) ||
            message.message.match?(
              /Slice 'Appointment.participant:\w+': a matching slice is required, but not found/
            )
        end
        #   # extension definition issue present in 2.0.1 but corrected in later versions
        #   message.message.match?(%r{The extension http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information is not allowed to be used at this point \(allowed = e:QuestionnaireResponse, e:Encounter, e:NutritionOrder, e:CommunicationRequest, e:DeviceRequest, e:ServiceRequest, e:MedicationRequest; this element is \[Appointment\]\)}) # rubocop:disable Layout/LineLength
        # end
      end

      US_CORE_7_METADATA_PATTERN = File.join(
        Gem::Specification.find_by_name('us_core_test_kit').gem_dir,
        'lib', 'us_core_test_kit', 'generated', 'v7.0.0', '*', 'metadata.yml'
      )
      CRD_V221_METADATA_PATTERN = File.join(__dir__, 'crd_metadata', '*.yml')
      include(MockEHREndpoints.with do
                Dir.glob([US_CORE_7_METADATA_PATTERN, CRD_V221_METADATA_PATTERN])
              end)

      route :get, '/jwks.json', JWKSetEndpointHandler
      resume_test_route :get, RESUME_PASS_PATH do |request|
        request.query_parameters['token']
      end
      resume_test_route :get, RESUME_FAIL_PATH, result: 'fail' do |request|
        request.query_parameters['token']
      end
      group from: :crd_v221_server_discovery_group

      group from: :crd_v221_server_demonstrate_hook_response

      group from: :crd_v221_server_hooks
    end
  end
end
