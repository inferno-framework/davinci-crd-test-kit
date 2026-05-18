require_relative '../../../cross_suite/prefetch_completeness_checker'
require_relative '../../tagged_request_load_helper'
require_relative '../../multi_request_message_helper'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class HookRequestPrefetchCompleteTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper
      include DaVinciCRDTestKit::MultiRequestMessageHelper

      id :crd_v221_hook_request_prefetch_complete
      title 'Hook requests include the requested prefetch data'
      description %(
        The [CDS service discovery response `prefetch` field](https://cds-hooks.hl7.org/2026Jan/en/#response)
        contains key/value pairs describing additional information needed to render a response. Each key is a
        string that describes the type of data being requested and the corresponding
        value is a FHIR query (read or search) that will return the desired scope.
        See the [Prefetch Template](https://cds-hooks.hl7.org/2026Jan/en/#prefetch-template)
        section for more information about the format of `prefetch` templates.

        [The CRD IG requires client support for prefetch](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#prefetch)
        including the ability to provide all data in and subsets of the [standard prefetch templates](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#standard-prefetch),
        when they are requested by the invoked CRD server. Inferno simulates two CRD servers,
        one at `#{ClientURLs.discovery_url}` requiring the [complete set of standard prefetches](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-v221.json)
        and the other at `#{ClientURLs.prefetch_subset_discovery_url}`
        [requesting a subset of the standard prefetch data set](https://github.com/inferno-framework/davinci-crd-test-kit/blob/main/lib/davinci_crd_test_kit/client/v2.2.1/cds-services-prefetch-subset-v221.json).

        During this test, Inferno will verify that each hook request body includes a `prefetch` field populated with
        valid JSON that contains exactly the requested prefetch keys and data sets described in the service description
        for the invoked service as calculated by Inferno based on the resources provided in the request.
      )
      verifies_requirements 'cds-hooks_3.0.0-ballot@30', 'cds-hooks_3.0.0-ballot@231', 'cds-hooks_3.0.0-ballot@45',
                            'cds-hooks_3.0.0-ballot@46', 'cds-hooks_3.0.0-ballot@47', 'cds-hooks_3.0.0-ballot@232',
                            'cds-hooks_3.0.0-ballot@53', 'cds-hooks_3.0.0-ballot@240',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-29-A', 'hl7.fhir.us.davinci-crd_2.2.1@found-23',
                            'hl7.fhir.us.davinci-crd_2.2.1@found-24', 'hl7.fhir.us.davinci-crd_2.2.1@found-25-A',
                            'hl7.fhir.us.davinci-crd_2.2.1@found-25-B', 'hl7.fhir.us.davinci-crd_2.2.1@found-31'

      # output emitted only if the behavior is detected
      output :demonstrates_fhirpath_collection_as_comma_delimited_string,
             :demonstrates_prefetch_subset_distinct_from_complete,
             :demonstrates_prefetch_complete_distinct_from_subset

      SERVICE_FILENAMES = {
        complete: 'cds-services-v221.json',
        subset: 'cds-services-prefetch-subset-v221.json'
      }.freeze

      def service_path_for_target(target)
        File.join(__dir__, '..', SERVICE_FILENAMES[target])
      end

      def service_path_for_opposite(target)
        opposite = target == :complete ? :subset : :complete
        service_path_for_target(opposite)
      end

      PREFETCH_KEY_COMPARISON_MAP = {
        'patient' => 'pat',
        'encounter' => 'enc',
        'coverage' => 'cov',
        'communicationRequests' => 'comReqs',
        'deviceRequests' => 'devReqs',
        'medicationRequests' => 'medReqs',
        'nutritionOrders' => 'nutOrds',
        'serviceRequests' => 'servReqs',
        'visionPrescriptions' => 'visRxs',
        'devices' => 'devs',
        'medications' => 'meds',
        'practitionerRoles' => 'roles',
        'practitioners' => 'pracs',
        'organizations' => 'orgs',
        'locations' => 'locs'
      }.freeze

      def key_comparison_map_for_target(target)
        if target == :complete
          PREFETCH_KEY_COMPARISON_MAP.invert
        else
          PREFETCH_KEY_COMPARISON_MAP
        end
      end

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          hook_request = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless hook_request.present?

          prefetch_target = if request.url.include?(PREFETCH_SUBSET_PREFIX)
                              :subset
                            else
                              :complete
                            end

          services_path = service_path_for_target(prefetch_target)
          checker = PrefetchCompletenessChecker.new(hook_request, request_index, services_path)
          completeness_errors = checker.check_prefetched_data
          completeness_errors.each do |error|
            add_message('error', error) # NOTE: PrefetchCompletenessChecker adds the (Request #) prefix
          end
          if checker.observed_fhirpath_collection_as_comma_delimited_string
            output demonstrates_fhirpath_collection_as_comma_delimited_string: true
          end
          if completeness_errors.blank? &&
             checker.data_set_different_with_alternate_service?(
               service_path_for_opposite(prefetch_target),
               key_comparison_map_for_target(prefetch_target)
             )
            if prefetch_target == :subset
              output demonstrates_prefetch_subset_distinct_from_complete: true
            else
              output demonstrates_prefetch_complete_distinct_from_subset: true
            end
          end
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Incomplete or invalid prefetched data. " \
                                 'See Messages for details.')
      end
    end
  end
end
