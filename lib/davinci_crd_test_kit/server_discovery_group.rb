require 'tls_test_kit'
require_relative 'server_tests/discovery_endpoint_test'
require_relative 'server_tests/discovery_services_validation_test'

module DaVinciCRDTestKit
  class ServerDiscoveryGroup < Inferno::TestGroup
    title 'Discovery'
    id :crd_server_discovery_group
    description %(
      # Background

      The #{title} Group checks for a CDS Service's Discovery endpoint as described by the
      [CDS Hooks Specification](https://cds-hooks.hl7.org/2.0/#discovery).
      A CDS Service is discoverable via a stable endpoint by CDS Clients. The Discovery endpoint
      includes information such as a description of the CDS Service, when it should be invoked,
      and any data that is requested to be prefetched.
      The Discovery endpoint SHALL always be available at `{baseUrl}/cds-services`.

      # Test Methodology

      This test sequence accesses the CRD server Dicovery endpoint at /cds-services using a GET request.
      It parses the response and verifies that:
      - The Discovery endpoint is TLS secured.
      - The Discovery endpoint is available at `{baseURL}/cds-services`.
      - Each CDS Service in the response contains the required fields as specified in the [CDS Hooks Spec](https://cds-hooks.hl7.org/2.0/#response).

      It collects the following information that is saved in the testing session for use by later tests:
      - List of supported CDS Services/Hooks
      - List of service IDs for each supported Hook.
    )

    run_as_group

    test from: :tls_version_test do
      title 'CRD Server is secured by transport layer security'
      description <<~DESCRIPTION
        Under [Privacy, Security, and Safety](https://hl7.org/fhir/us/davinci-crd/STU2/security.html),
        the CRD Implementation Guide imposes the following rule about TLS:

        As per the [CDS Hook specification](https://cds-hooks.hl7.org/2.0/#security-and-safety),
        communications between CRD Clients and CRD Servers SHALL
        use TLS. Mutual TLS is not required by this specification but is permitted. CRD Servers and
        CRD Clients SHOULD enforce a minimum version and other TLS configuration requirements based
        on HRex rules for PHI exchange.

        This test verifies that the CRD server is using TLS 1.2 or higher.
      DESCRIPTION
      id :crd_server_tls_version_stu2

      config(
        options: { minimum_allowed_version: OpenSSL::SSL::TLS1_2_VERSION },
        inputs: { url: { name: :base_url } }
      )
    end

    test from: :crd_discovery_endpoint_test
    test from: :crd_discovery_services_validation
  end
end
