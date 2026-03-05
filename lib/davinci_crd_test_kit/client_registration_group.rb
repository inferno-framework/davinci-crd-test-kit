require_relative 'client_tests/client_registration_verification_test'
require_relative 'client_tests/client_service_registration_attestation_test'

module DaVinciCRDTestKit
  class PASClientRegistrationGroup < Inferno::TestGroup
    id :crd_client_registration
    title 'Client Registration'
    description %(
        Register the CRD client under test with Inferno's simulated CRD Server by
        providing required information for Inferno to use in identifying and verify
        hook requests.

        Testers will be required to provide:
        1. The `iss` URI that uniquely identifies this CRD client to Inferno.
        2. The CRD client's JSON Web Key (JWK) Set in the form of either a URL
           that resolves to a valid JWK Set or the literal JWK Set in JSON form.

        Inferno will verify these values and use them for the remainder of the tests.
        These tests must be run before any other tests as they represent the registration
        of the client under test with the Inferno service. If the client needs to make a
        change to its registered values during execution, this test will need to be re-run.
      )
    run_as_group

    test from: :crd_client_registration_verification
    test from: :crd_client_service_registration_attestation
  end
end
