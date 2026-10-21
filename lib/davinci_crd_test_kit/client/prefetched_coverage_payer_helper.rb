require_relative '../cross_suite/tags'
require_relative 'client_base_urls'
require_relative 'prefetched_coverage_value'

module DaVinciCRDTestKit
  # Checks of the Coverage prefetched in a hook request against the payer Organization registered
  # for the invoked Inferno service. The payer is read by Inferno while processing the hook request.
  # Including tests need the `complete_prefetch_service_organization_id` and
  # `subset_prefetch_service_organization_id` inputs and DaVinciCRDTestKit::MultiRequestMessageHelper.
  module PrefetchedCoveragePayerHelper
    include ClientBaseURLs

    def payer_org_id_for_request(request)
      if prefetch_target(request) == :subset
        subset_prefetch_service_organization_id
      else
        complete_prefetch_service_organization_id
      end
    end

    # The Coverages prefetched in the request: either the prefetched value itself when given as a
    # Coverage, or the Coverages in a prefetched Bundle. A Coverage given outside a Bundle is reported
    # by the prefetch completeness check, so it is still checked here.
    def prefetched_coverages(request_body)
      coverage_value = PrefetchedCoverageValue.find(request_body['prefetch'])
      return [] if coverage_value.nil?
      return [coverage_value] if coverage_value['resourceType'] == 'Coverage'

      Array(coverage_value['entry']).filter_map { |entry| entry['resource'] if entry.is_a?(Hash) }
        .select { |resource| resource.is_a?(Hash) && resource['resourceType'] == 'Coverage' }
    end

    # the Coverage the payer is read from while processing the hook request
    def prefetched_coverage(request_body)
      prefetched_coverages(request_body).first
    end

    # the reference to the Coverage's first payer, or nil when it does not have one as a string
    def coverage_payer_reference(coverage)
      payor = coverage['payor']
      first_payor = payor.first if payor.is_a?(Array)
      reference = first_payor['reference'] if first_payor.is_a?(Hash)
      reference if reference.is_a?(String)
    end

    def load_payer_request_for_hook_request(request_body)
      hook_data_fetch_tag = TagMethods.hook_instance_data_fetch_tag(request_body['hookInstance'])
      load_tagged_requests(PAYER_ORG_FETCH_TAG, hook_data_fetch_tag).first
    end

    # Reports any problem with the payer read for the request and returns the payer resource when one
    # was returned, so that callers can check it further.
    def check_payer_organization(request_body, request_index, expected_payer_org_id)
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

      payer_resource
    end
  end
end
