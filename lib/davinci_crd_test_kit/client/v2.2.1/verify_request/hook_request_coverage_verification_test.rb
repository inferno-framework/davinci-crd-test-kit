require_relative '../../../cross_suite/tags'
require_relative '../../multi_request_message_helper'
require_relative '../../tagged_request_load_helper'
require_relative '../client_urls'
require_relative '../../prefetched_coverage_payer_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestCoverageVerificationTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include ClientURLs
      include DaVinciCRDTestKit::PrefetchedCoveragePayerHelper

      id :crd_v221_hook_request_coverage_verification
      title 'Prefetched coverages are valid'
      description %(
        During this test, Inferno will verify that the issuing payer Organization id from the `payor` element
        of each hook request's prefetched coverage matches the Organization id associated with the
        invoked simulated CRD server provided by the tester during the "Registration" group.
        Inferno also checks that the Organization resources conform to the
        [CRD Organization](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-organization.html)
        profile.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-26-A', 'hl7.fhir.us.davinci-crd_2.2.1@dev-29-A',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-1'

      input :complete_prefetch_service_organization_id,
            title: 'Complete Prefetch Service Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              complete prefetch CRD server. This Organization must be referenced as the
              payer on Coverages in hook requests made to services described by the `#{ClientURLs.discovery_url}`
              discovery endpoint. The client suite may be run without this input, but it is required
              for the tests to pass.
              Re-run the "Registration" group to provide this detail.
            ),
            type: 'text',
            optional: true,
            locked: true
      input :subset_prefetch_service_organization_id,
            title: 'Subset Prefetch Service Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              subset prefetch CRD server. This Organization must be referenced as the
              payer on Coverages in hook requests made to services described by the
              `#{ClientURLs.prefetch_subset_discovery_url}` discovery endpoint.
              The client suite may be run without this input, but it is required
              for the tests to pass.
              Re-run the "Registration" group to provide this detail.
            ),
            type: 'text',
            optional: true,
            locked: true

      def check_payer_request(request_body, request_index, expected_payer_org_id)
        payer_resource = check_payer_organization(request_body, request_index, expected_payer_org_id)
        check_payer_resource_conformance(payer_resource, request_index) if payer_resource.present?
      end

      def check_payer_resource_conformance(payer_resource, request_index)
        validator_response_details = []
        resource_is_valid?(resource: payer_resource, profile_url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization|2.2.1',
                           add_messages_to_runnable: false, validator_response_details:)

        validator_response_details.each do |issue|
          next if issue.filtered

          add_request_message(issue.severity, issue.message, request_index)
        end
      end

      run do
        hook_requests = load_interaction_group_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body.present?

          unless request_body.is_a?(Hash)
            add_request_message('error', "Request body must be a JSON object, got #{request_body.class}.",
                                request_index)
            next
          end

          expected_payer_org_id = payer_org_id_for_request(request)
          if expected_payer_org_id.blank?
            add_request_message(
              'error',
              'No Inferno Payer Organization id configured for this endpoint; skipping required coverage check.',
              request_index
            )
            next
          end

          coverage = first_prefetched_coverage(request_body)
          unless coverage.present?
            add_request_message('error', 'Request has no coverage.', request_index)
            next
          end

          payer_organization_reference = coverage_payer_reference(coverage)
          if payer_organization_reference.blank?
            add_request_message('error', 'Coverage has no payer reference.', request_index)
            next
          end

          check_payer_request(request_body, request_index, expected_payer_org_id)
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Invalid coverage. " \
                                 'See Messages for details.')
      end
    end
  end
end
