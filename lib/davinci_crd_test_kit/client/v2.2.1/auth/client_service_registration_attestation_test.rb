module DaVinciCRDTestKit
  module V221
    class CRDClientServiceRegistrationAttestation < Inferno::Test
      include ClientURLs

      id :crd_v221_client_service_registration_attestation
      title 'Attest to the registration of the Inferno Service by the CRD Client'
      description %(
        During this test, the tester will confirm that Inferno has been registered as a
        trusted CRD Service that can access the CRD Client's FHIR Server, which has also been
        - Associated with a particular payer organization (used to check that the
          hook requests are sent by the client system to the appropriate payers based on
          the Patient's coverage).
        - Granted patient- or user-level read and search access to all US Core resource
          types in the selected US Core version (required to verify the client's support
          of the US Core FHIR API and used to verify the `fhirAuthorization.scopes`
          hook request field).
      )

      # verifies_requirements 'cds-hooks_2.0@174'

      input :inferno_payer_organization_id,
            title: 'Inferno Payer Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              CRD endpoints. This Organization must be referenced as the
              payer on Coverages in hook requests.
            ),
            type: 'text',
            optional: true
      output :attest_true_url
      output :attest_false_url

      def us_core_version
        case suite_options[:us_core_version]
        when CRDClientOptions::US_CORE_3
          'v3.1.1'
        when CRDClientOptions::US_CORE_6
          'v6.1.0'
        when CRDClientOptions::US_CORE_7
          'v7.0.0'
        end
      end

      def us_core_version_resource_types
        case suite_options[:us_core_version]
        when CRDClientOptions::US_CORE_3
          CRDClientOptions::US_CORE_3_RESOURCE_TYPES
        when CRDClientOptions::US_CORE_6, CRDClientOptions::US_CORE_7
          CRDClientOptions::US_CORE_6_7_RESOURCE_TYPES
        end.join('`, `')
      end

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

            I attest that Inferno has been registered as a trusted CRD Service
            able to access data stored on the CRD Client's FHIR Server and that
            Inferno
            - Is associated with the payor Organization resource with id `#{inferno_payer_organization_id}`
            - Has been granted patient- or user-level read and search access scopes for
              all US Core #{us_core_version} resource types (`#{us_core_version_resource_types}`).

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
