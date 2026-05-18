require_relative 'registration/client_registration_verification_test'
require_relative 'registration/client_service_registration_attestation_test'

module DaVinciCRDTestKit
  module V221
    class CRDClientRegistrationGroup < Inferno::TestGroup
      id :crd_v221_client_registration
      title 'Registration'
      description %(
        Before hook invocations can be made, the client tested in this session
        must be registered with and trusted by Inferno's simulated CRD server
        and vice-versa. Tests in this group confirm the registration of the partner
        system on both ends.

        This group must be run before any other tests in the "Hook Invocation" group because inputs
        provided to this group will be used by Inferno for the remainder of the tests
        to identify client requests and verify behavior. The inputs will appear as locked and
        unchangeable on these subsequent tests. If changes to these values are needed,
        re-run this group and provide the corrected input values.
      )
      run_as_group

      test from: :crd_v221_client_registration_verification
      test from: :crd_v221_client_service_registration_attestation
    end
  end
end
