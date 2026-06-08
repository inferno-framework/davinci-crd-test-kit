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

        Inferno simulates two CRD discovery endpoints for the client to connect to:
        - Discovery endpoint for services requesting the complete [standard prefetch data set](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch):
          `#{ClientURLs.discovery_url}`
        - Discovery endpoint for services requesting the a subset of the [standard prefetch data set](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch):
          `#{ClientURLs.prefetch_subset_discovery_url}`

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
