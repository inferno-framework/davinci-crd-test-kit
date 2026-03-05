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

      For details on the design and use of these tests, see the wiki including
      - [Suite Details](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Details)
        for a high-level description of the test
        organization, including its components and limitations.
      - [Testing Instructions](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions)
        for a step-by-step guide to execution of these
        tests against a CRD client, including [instructions for a demonstration execution](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Server-Instructions#demonstration-execution)
        against the [public reference implementation](https://crd.davinci.hl7.org/).
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
