require_relative 'version'

module DaVinciCRDTestKit
  class Metadata < Inferno::TestKit
    id :davinci_crd_test_kit
    title 'Da Vinci Coverage Requirements Discovery (CRD) Test Kit'
    description <<~DESCRIPTION
      The Da Vinci Coverage Requirements Discovery (CRD) Test Kit tests the
      conformance of client and server systems to versions of the
      Da Vinci Coverage Requirements Discovery (CRD) FHIR Implementation Guide (IG), including
      - [Da Vinci Coverage Requirements Discovery (CRD) STU 2.0.1](https://hl7.org/fhir/us/davinci-crd/STU2), and
      - [Da Vinci Coverage Requirements Discovery (CRD) STU 2.2.1](https://hl7.org/fhir/us/davinci-crd/2.2.1)

      <!-- break -->

      ## Status

      These tests are a **DRAFT** intended to allow CRD implementers to perform
      preliminary checks of their implementations against the CRD IG requirements and
      provide feedback on the tests. Future versions of these tests may validate other
      requirements and may change how these are tested.

      Additional details on the IG requirements that underlie this test kit can be
      found in the [Specification Requirements display within the testing UI](https://inferno-framework.github.io/docs/user-interface.html#specification-requirements)
      and other artifacts of Inferno's [requirements tracking tools](https://inferno-framework.github.io/docs/advanced-test-features/requirements.html).

      ## Additional Details

      Additional details about design, scope, and limitations of the suites within this
      test kit can be found on the [CRD Test Kit Wiki](https://github.com/inferno-framework/davinci-crd-test-kit/wiki)

    DESCRIPTION
    suite_ids [:crd_client, :crd_client_v221, :crd_server, :crd_server_v221]
    tags ['Da Vinci', 'CRD']
    last_updated LAST_UPDATED
    version VERSION
    maturity 'Low'
    authors ['Stephen MacVicar', 'Vanessa Fotso', 'Emily Michaud']
    repo 'https://github.com/inferno-framework/davinci-crd-test-kit'
  end
end
