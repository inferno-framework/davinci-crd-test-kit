module DaVinciCRDTestKit
  module V221
    class CRDClientServiceRegistrationAttestation < Inferno::Test
      include ClientURLs

      id :crd_v221_client_service_registration_attestation
      title 'CRD client registers Inferno'
      description %(
        Inferno simulates two CRD servers which can be discovered at the following endpoints:
        - Complete Prefetch Service Discovery Endpoint: #{ClientURLs.discovery_url}
        - Subset Prefetch Service Discovery Endpoint: #{ClientURLs.prefetch_subset_discovery_url}

        During this test, the tester will confirm that these two endpoints
        have been registered by the CRD client as trusted CRD servers that can access the CRD client's
        FHIR server and that they have each been
        - Associated with a particular payer organization (used to check that the
          hook requests are sent by the CRD client to the appropriate payers based on
          the Patient's coverage).
        - Granted patient- or user-level read and search access to all US Core resource
          types in the selected US Core version (required to verify the CRD client's support
          of the US Core FHIR API and used to verify the `fhirAuthorization.scope`
          hook request field).

        Testers can make hook requests during this test, but Inferno will never return
        a successful response. Typical error responses include:
        - HTTP 422 (*Unprocessable Content*) - indicates that connectivity succeeded: Inferno recognized
          the request and associated it with this session, but will not return successful hook responses
          during this test.
        - HTTP 500 (*Internal Server Error*) - indicates that connectivity failed: Inferno was not able
          to associate the request with this session.
      )
      attestation
      verifies_requirements 'cds-hooks_3.0.0-ballot@174'

      config options: { hook_requests_unavailable: true }

      input :cds_jwt_iss
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

      def service_configuration_message(discovery_url, payer_id)
        <<~MESSAGE
          - **Discovery Endpoint**: `#{discovery_url}`
          - **Related Payer**: #{payer_message(payer_id)}
          - **Access Scope**: Inferno has been granted patient- or user-level read and search access scopes for
                all US Core #{us_core_version} profiled resource types (`#{us_core_version_resource_types}`).
        MESSAGE
      end

      def payer_message(payer_id)
        if payer_id.present?
          "`#{payer_id}`. These CRD services will be invoked for patients with a coverage issued by " \
            'the payer represented by the Organization resource with that id.'
        else
          'Not configured.'
        end
      end

      run do
        identifier = cds_jwt_iss
        attest_true_url = resume_pass_url_for(identifier)
        attest_false_url = resume_fail_url_for(identifier)
        output(attest_true_url:)
        output(attest_false_url:)
        wait(
          identifier:,
          message: <<~MESSAGE
            **Registration of Inferno as a trusted CRD server**:

            I attest that Inferno's CRD services have been registered as trusted
            within the CRD client and granted the access described below.

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.

            #### Trusted Endpoints Configuration

            *Complete Prefetch Services*:

            #{service_configuration_message(discovery_url, complete_prefetch_service_organization_id)}

            *Subset Prefetch Services*:

            #{service_configuration_message(prefetch_subset_discovery_url, subset_prefetch_service_organization_id)}

            #### Authentication and Identification

            For Inferno to recognize CRD requests and associate them with this session,
            the authentication JWT sent as a Bearer token in the Authorization header
            must have `#{cds_jwt_iss}` as the `iss` claim in the JWT payload.

            #### Responses

            Testers are not required to make a hook request confirming connectivity.
            However, testers may send hook requests to confirm connectivity. Inferno
            will always respond with an error, but the type of error indicates whether
            connectivity was successful:
            - HTTP 422 (*Unprocessable Content*) - indicates that connectivity succeeded: Inferno recognized
              the request and associated it with this session, but will not return successful hook responses
              during this test.
            - HTTP 500 (*Internal Server Error*) - indicates that connectivity failed: Inferno was not able
              to associate the request with this session.
          MESSAGE
        )
      end
    end
  end
end
