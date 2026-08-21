require_relative 'unknown_content/client_unknown_content_receive_request_test'
require_relative 'unknown_content/client_unknown_content_attestation_test'

module DaVinciCRDTestKit
  module V221
    class ClientUnknownContentHookGroup < Inferno::TestGroup
      title 'Unknown Response Content'
      id :crd_v221_client_unknown_content_hook
      description <<~DESCRIPTION
        CRD servers may return content that clients do not recognize, and the CRD IG requires
        clients to ignore it rather than fail. During this scenario Inferno returns coverage
        information accompanied by an element within the system action and a custom extension
        on the response, both with randomly generated names. This content is added at the CRD
        response level rather than within the FHIR resources carried in the response.

        Hook requests made during these tests will not be checked for conformance
        or included in the cross-hook analyses around must support and other coverage requirements.
      DESCRIPTION

      run_as_group

      config(
        options: {
          hook_name: ANY_HOOK_TAG,
          crd_interaction_group: UNKNOWN_CONTENT_GROUP_TAG,
          include_in_cross_hook_analysis: false
        }
      )

      test from: :crd_v221_client_unknown_content_receive_request
      test from: :crd_v221_client_unknown_content_attestation_test
    end
  end
end
