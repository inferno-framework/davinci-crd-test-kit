module DaVinciCRDTestKit
  module V201
    class CRDClientServiceRegistrationAttestation < Inferno::Test
      include ClientURLs

      id :crd_v201_client_service_registration_attestation
      title 'Attest to the registration of the Inferno Service by the CRD client'
      description %(
        During this test, the tester will confirm that Inferno has been registered as a
        trusted CRD server that can access the CRD client's FHIR Server.
      )

      verifies_requirements 'cds-hooks_2.0@174'

      config options: { hook_requests_unavailable: true }

      input :cds_jwt_iss
      output :attest_true_url
      output :attest_false_url

      run do
        identifier = cds_jwt_iss
        attest_true_url = "#{resume_pass_url}?token=#{ERB::Util.url_encode(identifier)}"
        attest_false_url = "#{resume_fail_url}?token=#{ERB::Util.url_encode(identifier)}"
        output(attest_true_url:)
        output(attest_false_url:)
        wait(
          identifier:,
          message: <<~MESSAGE
            **Registration of Inferno as a trusted CRD server**:

            I attest that Inferno has been registered as a trusted CRD server that is allowed to access
            data stored on the CRD client's FHIR Server.

            Hook requests sent while this test is waiting with `#{cds_jwt_iss}` as the `iss` claim of the
            authentication JWT will be recognized and answered with an error confirming the registration.
            They will not be processed as hook invocations.

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
