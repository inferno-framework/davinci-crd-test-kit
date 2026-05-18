module DaVinciCRDTestKit
  module V221
    class CRDClientServiceRegistrationAttestation < Inferno::Test
      include ClientURLs

      id :crd_v221_client_service_registration_attestation
      title 'CRD client registers Inferno (Attestation)'
      description %(
        Inferno simulates two CRD servers which can be discovered at the following endpoints:
        - Complete Prefetch Service Discovery Endpoint: #{ClientURLs.discovery_url}
        - Subset Prefetch Service Discovery Endpoint: #{ClientURLs.prefetch_subset_discovery_url}

        During this test, the tester will confirm that these two endpoints
        have been registered by the client as trusted CRD servers that can access the CRD client's
        FHIR server and that they have each been
        - Associated with a particular payer organization (used to check that the
          hook requests are sent by the client system to the appropriate payers based on
          the Patient's coverage).
        - Granted patient- or user-level read and search access to all US Core resource
          types in the selected US Core version (required to verify the client's support
          of the US Core FHIR API and used to verify the `fhirAuthorization.scope`
          hook request field).
      )
      verifies_requirements 'cds-hooks_3.0.0-ballot@174'

      input :complete_prefetch_service_organization_id,
            title: 'Complete Prefetch Service Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              complete prefetch CRD server. This Organization must be referenced as the
              payer on Coverages in hook requests made to services described by the
              `#{ClientURLs.discovery_url}` discovery endpoint.
              The client suite may be run without this input, but it is required
              for the tests to pass.
            ),
            type: 'text',
            optional: true
      input :subset_prefetch_service_organization_id,
            title: 'Subset Prefetch Service Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              subset prefetch CRD server. This Organization must be referenced
              payer on Coverages in hook requests made to services described by the
              `#{ClientURLs.prefetch_subset_discovery_url}` discovery endpoint.
              The client suite may be run without this input, but it is required
              for the tests to pass.
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
            **Registration of Inferno as a trusted CRD server**:

            I attest that the following Inferno CRD servers have been registered as trusted
            within the client system:

            - Complete Prefetch Service Discovery Endpoint: `#{discovery_url}`
              - Services on this CRD server will be invoked for patients with a primary coverage issued by the payer
                represented by the Organization resource with id `#{complete_prefetch_service_organization_id}`.
              - The CRD server has been granted patient- or user-level read and search access scopes for
                all US Core #{us_core_version} profiled resource types (`#{us_core_version_resource_types}`).

            - Subset Prefetch Service Discovery Endpoint: `#{prefetch_subset_discovery_url}`
              - Services on this CRD server will be invoked for patients with a primary coverage issued by the payer
                represented by the Organization resource with id `#{subset_prefetch_service_organization_id}`.
              - The CRD server has been granted patient- or user-level read and search access scopes for
                all US Core #{us_core_version} profiled resource types (`#{us_core_version_resource_types}`).

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
