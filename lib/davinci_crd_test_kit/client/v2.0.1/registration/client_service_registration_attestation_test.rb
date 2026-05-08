module DaVinciCRDTestKit
  module V201
    class CRDClientServiceRegistrationAttestation < Inferno::Test
      include ClientURLs

      id :crd_v201_client_service_registration_attestation
      title 'Attest to the registration of the Inferno Service by the CRD Client'
      description %(
        During this test, the tester will confirm that Inferno has been registered as a
        trusted CRD Service that can access the CRD Client's FHIR Server.
      )

      verifies_requirements 'cds-hooks_2.0@174'

      output :attest_true_url
      output :attest_false_url

      run do
        identifier = SecureRandom.hex(32)
        attest_true_url = "#{resume_pass_url}?token=#{identifier}"
        attest_false_url = "#{resume_fail_url}?token=#{identifier}"
        output(attest_true_url:)
        output(attest_false_url:)
        wait(
          identifier:,
          message: <<~MESSAGE
            **Registration of Inferno as a trusted CRD Service**:

            I attest that Inferno has been registered as a trusted CRD Service that is allowed to access
            data stored on the CRD Client's FHIR Server.

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
