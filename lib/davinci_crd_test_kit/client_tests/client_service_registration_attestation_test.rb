module DaVinciCRDTestKit
  class CRDClientServiceRegistrationAttestation < Inferno::Test
    include URLs

    id :crd_client_service_registration_attestation
    title 'Attest to the registration of the Inferno Service by the CRD Client'
    description %(
        During this test, the tester will confirm that Inferno has been registered as a
        trusted CRD Service that can access the CRD Client's FHIR Server.
      )

    verifies_requirements 'cds-hooks_2.0@174'

    run do
      identifier = SecureRandom.hex(32)
      wait(
        identifier:,
        message: <<~MESSAGE
          **Registration of Inferno as a trusted CRD Service**:

          I attest that Inferno has been registered as a trusted CRD Service that is allowed to access
          data stored on the CRD Client's FHIR Server.

          [Click here](#{resume_pass_url}?token=#{identifier}) if the above statement is **true**.

          [Click here](#{resume_fail_url}?token=#{identifier}) if the above statement is **false**.
        MESSAGE
      )
    end
  end
end
