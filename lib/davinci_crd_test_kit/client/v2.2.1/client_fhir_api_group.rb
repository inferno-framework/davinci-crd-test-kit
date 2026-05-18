require 'us_core_test_kit'
require_relative '../crd_client_options'
require_relative 'api/client_crd_update_verification_group'

module DaVinciCRDTestKit
  module V221
    class ClientFHIRAPIGroup < Inferno::TestGroup
      title 'FHIR API'
      description <<~DESCRIPTION
        Systems wishing to conform to the [CRD client](https://hl7.org/fhir/us/davinci-crd/STU2/CapabilityStatement-crd-client.html)
        role are responsible for returning data requested by the CRD Server needed to provide decision support. The Da
        Vinci CRD client FHIR API Test Group contains tests that test the ['server' capabilities](https://hl7.org/fhir/us/davinci-crd/CapabilityStatement-crd-client.html#resourcesSummary1)
        of the CRD client and ensures that the CRD client can respond to CRD Server queriers. These 'server' capabilities
        are based on [US Core](https://hl7.org/fhir/us/core/STU3.1.1/).
      DESCRIPTION
      id :crd_v221_client_fhir_api

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-1'

      input_instructions %(
        Details on how and what to access the client's FHIR server are expected to come in
        the CDS Hooks request. The following information will be auto-populated from
        the latest hook request made during this session:
        - The URL of the CRD client FHIR server from the `fhirServer` field.
        - The OAuth Access Token from the `fhirAuthorization.access_token` field.

        If that access token will not be long-lived enough to perform
        a full test of the US Core FHIR API, provide an updated token and/or refresh
        token with Client ID and token endpoint so that Inferno can perform these tests.
      )

      input :url,
            title: 'FHIR Endpoint',
            description: %(
              URL of the CRD client FHIR server.
            ),
            locked: true
      input :smart_auth_info,
            title: 'OAuth Credentials',
            type: 'auth_info'

      group from: :'us_core_v311-us_core_v311_fhir_api' do
        description %(
          This test group verifies that the CRD client can respond to queries as required by the
          US Core 3.1.1 Server Capability Statement

          Note: these tests do not look for crd-specific data and so only verify conformance against
          US Core profiles. The hook tests take the CRD-specific profiles into account.
        )
        required_suite_options CRDClientOptions::US_CORE_3_REQUIREMENT

        group from: :crd_v221_client_update_verification,
              id: :crd_v221_us_core_311_client_update_verification
        reorder :crd_v221_us_core_311_client_update_verification, 1
      end
      group from: :'us_core_v610-us_core_v610_fhir_api' do
        description %(
          This test group verifies that the CRD client can respond to queries as required by the
          US Core 6.1.0 Server Capability Statement

          Note: these tests do not look for crd-specific data and so only verify conformance against
          US Core profiles. The hook tests take the CRD-specific profiles into account.
        )
        required_suite_options CRDClientOptions::US_CORE_6_REQUIREMENT

        group from: :crd_v221_client_update_verification,
              id: :crd_v221_us_core_610_client_update_verification
        reorder :crd_v221_us_core_610_client_update_verification, 1
      end
      group from: :'us_core_v700-us_core_v700_fhir_api' do
        description %(
          This test group verifies that the CRD client can respond to queries as required by the
          US Core 7.0.0 Server Capability Statement

          Note: these tests do not look for crd-specific data and so only verify conformance against
          US Core profiles. The hook tests take the CRD-specific profiles into account.
        )
        required_suite_options CRDClientOptions::US_CORE_7_REQUIREMENT

        group from: :crd_v221_client_update_verification,
              id: :crd_v221_us_core_700_client_update_verification
        reorder :crd_v221_us_core_700_client_update_verification, 1
      end
    end
  end
end
