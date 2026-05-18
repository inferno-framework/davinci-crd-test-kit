require_relative 'client_coverage_info_update_test'

module DaVinciCRDTestKit
  module V221
    class ClientCRDUpdateVerificationGroup < Inferno::TestGroup
      id :crd_v221_client_update_verification
      title 'CRD Update Tests'
      description %(
        This CRD-specific group verifies that the client was able to
        persist updates provided by the payer server as a part of
        decision support responses.
      )
      run_as_group

      test from: :crd_v221_client_coverage_info_update
    end
  end
end
