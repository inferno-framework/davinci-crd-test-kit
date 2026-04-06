module DaVinciCRDTestKit
  module V220
    class FHIRRequestTest < Inferno::Test
      id :crd_v220_server_fhir_request_test
      title 'Make FHIR requests'
      description %(
        During this test, the server will make FHIR requests aginast
        Inferno's simulated FHIR Server."
      )

      input :token
      input :mock_ehr_bundle, type: 'textarea'

      run do
        wait(
          timeout: 600,
          identifier: token,
          message: <<~MESSAGE
            Send FHIR requests
          MESSAGE
        )
      end
    end
  end
end
