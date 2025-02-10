require_relative 'version'

module DaVinciCRDTestKit
  class Metadata < Inferno::TestKit
    id :davinci_crd_test_kit
    title 'Da Vinci Coverage Requirements Discovery (CRD) Test Kit'
    description <<~DESCRIPTION
      The Da Vinci Coverage Requirements Discovery (CRD) Test Kit tests the
      conformance of client and server systems to [version 2.0.1 of the Da Vinci
      Coverage Requirements Discovery (CRD) Implementation
      Guide](https://hl7.org/fhir/us/davinci-crd/STU2).

      <!-- break -->

      ## Status

      These tests are a **DRAFT** intended to allow CRD implementers to perform
      preliminary checks of their implementations against the CRD IG requirements and
      provide feedback on the tests. Future versions of these tests may validate other
      requirements and may change how these are tested.

      Additional details on the IG requirements that underlie this test kit can be
      found in this [CRD testing note](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/docs/crd-testing-notes.md). The document
      includes the requirements extracted from the IG and specified the ones that are
      not testable.

      ## Test Scope and Limitations

      Documentation of the current tests and their limitations can be found in each
      suite's (client and server) description when the tests are run.

      ### Test Scope

      At a high-level, the tests check:

      - **Client Suite**:
        - The ability of a CRD client to initiate CDS Hooks calls.
        - The ability of a CRD client to support the FHIR interactions defined in the
          implementation guide.
      - **Server Suite**:
        - The ability of a CRD server to return a valid response when invoking its
          discovery endpoint.
        - The ability of a CRD server to return a valid response when invoking a
          supported hook, including producing the required response types across all
          hooks invoked.

      ### Limitations

      - **Client Suite**:
        - This suite does not implement any payer business logic, so the responses to
          hook calls are simple hard-coded responses.
        - The tests cannot verify that a client is able to consume the received
          decision support. Testers should consider this requirement to be verified
          through attestation and should not represent their systems as having passed
          these tests if this requirement is not met.
        - Hook configuration is not tested.
      - **Server Suite**:
        - Inferno is unable to determine what requests will result in specific kinds
          of responses from the server under test (e.g., what will result in
          Instructions being returned vs. Coverage Information). As a result, the
          tester must supply the request bodies that will cause the system under test
          to return the desired response types.
        - The ability of a CRD server to request additional FHIR resources is not
          tested.
        - Hook configuration is not tested.
    DESCRIPTION
    suite_ids [:crd_client, :crd_server]
    tags ['Da Vinci', 'CRD']
    last_updated LAST_UPDATED
    version VERSION
    maturity 'Low'
    authors ['Stephen MacVicar', 'Vanessa Fotso', 'Emily Michaud']
    repo 'https://github.com/inferno-framework/davinci-crd-test-kit'
  end
end
