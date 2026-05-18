require_relative '../../../cross_suite/tags'
require_relative '../../multi_request_message_helper'
require_relative '../../tagged_request_load_helper'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class HookRequestCoverageVerificationTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include ClientURLs

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

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-29-A', 'hl7.fhir.us.davinci-crd_2.2.1@hook-1'

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
              subset prefetch CRD server. This Organization must be referenced
              payer on Coverages in hook requests made to services described by the
              `#{ClientURLs.prefetch_subset_discovery_url}` discovery endpoint.
              The client suite may be run without this input, but it is required
              for the tests to pass.
              Re-run the "Registration" group to provide this detail.
            ),
            type: 'text',
            optional: true,
            locked: true

      def prefetch_target(request)
        if request.url.include?(PREFETCH_SUBSET_PREFIX)
          :subset
        else
          :complete
        end
      end

      def payer_org_id_for_request(request)
        if prefetch_target(request) == :subset
          subset_prefetch_service_organization_id
        else
          complete_prefetch_service_organization_id
        end
      end

      def load_payer_request_for_hook_request(request_body)
        hook_data_fetch_tag = TagMethods.hook_instance_data_fetch_tag(request_body['hookInstance'])
        load_tagged_requests(PAYER_ORG_FETCH_TAG, hook_data_fetch_tag, DATA_FETCH_TAG).first
      end

      def check_payer_request(request_body, request_index, expected_payer_org_id)
        payer_request = load_payer_request_for_hook_request(request_body)
        unless payer_request.present? && payer_request.status.to_s.starts_with?('2')
          add_request_message('error',
                              "Inferno failed to retrieve the Coverage's payer during hook processing.",
                              request_index)
          return
        end

        payer_resource = FHIR.from_contents(payer_request.response_body)
        unless payer_resource.present?
          add_request_message('error', 'Request for payer resource returned invalid FHIR data.', request_index)
          return
        end

        if payer_resource.resourceType != 'Organization'
          add_request_message('error', 'Payer for the Coverage is not an Organization: ' \
                                       "got '#{payer_resource.resourceType}'", request_index)
        end
        if payer_resource.id != expected_payer_org_id
          add_request_message('error', 'Payer for the Coverage has the wrong id: ' \
                                       "expected '#{expected_payer_org_id}', got '#{payer_resource.id}'.",
                              request_index)
        end

        validator_response_details = []
        resource_is_valid?(resource: payer_resource, profile_url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization|2.2.1',
                           add_messages_to_runnable: false, validator_response_details:)

        validator_response_details.each { |issue| add_request_message(issue.severity, issue.message, request_index) }
      end

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body.present?

          expected_payer_org_id = payer_org_id_for_request(request)
          if expected_payer_org_id.blank?
            add_request_message(
              'error',
              'No Inferno Payer Organization id configured for this endpoint; skipping required coverage check.',
              request_index
            )
            next
          end

          coverage = prefetched_coverage(request_body)
          unless coverage.present?
            add_request_message('warning', 'Request has no coverage.', request_index)
            next
          end

          payer_organization_reference = coverage.dig('payor', 0, 'reference')
          if payer_organization_reference.blank?
            add_request_message('error', 'Coverage has no payer reference.', request_index)
            next
          end

          check_payer_request(request_body, request_index, expected_payer_org_id)
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Invalid coverage. " \
                                 'See Messages for details.')
      end

      def prefetched_coverage(request_body)
        coverage = request_body.dig('prefetch', 'coverage', 'entry', 0, 'resource')
        coverage = request_body.dig('prefetch', 'cov', 'entry', 0, 'resource') unless coverage.present?
        coverage
      end
    end
  end
end
