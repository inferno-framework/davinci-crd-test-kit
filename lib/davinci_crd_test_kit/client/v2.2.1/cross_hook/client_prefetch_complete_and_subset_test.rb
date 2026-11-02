require_relative '../../tagged_request_load_helper'
require_relative '../../cross_hook_helper'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientPrefetchCompleteAndSubsetTest < Inferno::Test
      include TaggedRequestLoadHelper
      include CrossHookHelper
      include ClientURLs

      title 'CRD client can provide both the complete standard prefetch data set and a subset'
      id :crd_v221_client_prefetch_complete_and_subset
      description <<~DESCRIPTION
        The CRD IG requires that CRD clients be able to prefetch a standard set of resources that
        payers are expected to need to evaluate coverage requirements. They are also
        required to be able to prefetch a subset of these standard prefetch requirements
        if a payer requests fewer in their service discovery responses because the payer
        does not always need the complete set of standard prefetch resources to evaluate
        coverage.

        During this test, Inferno will verify that the CRD client has demonstrated requests
        - made against both of Inferno's simulated CRD servers,
          [one of which requests all standard prefetch resources](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Prefetch-Verification#infernos-standard-services)
          while the other [requests only a subset](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Prefetch-Verification#infernos-subset-services).
        - which demonstrate the capability to [distinguish the difference between
          the two prefetch sets](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Client-Prefetch-Verification#demonstrating-prefetch-calculation).

        This test relies on the evaluation performed by the "Hook requests include the
        requested prefetch data" tests present in each hook-specific "Requests" group. One of these groups must
        have been run and resulted in a "Hook requests include the
        requested prefetch data" test that outputs
        "demonstrates_prefetch_subset_distinct_from_complete" and
        "demonstrates_prefetch_complete_distinct_from_subset" as true (does not have to be the
        same test).
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-25-A', 'hl7.fhir.us.davinci-crd_2.2.1@found-25-B'

      run do
        subset_prefetch_requests, complete_prefetch_requests =
          load_requests_for_cross_hook_analysis.partition { |request| prefetch_target(request) == :subset }
        completeness_tests = find_completeness_tests
        check_for_demonstration(subset_prefetch_requests, completeness_tests, :subset)
        check_for_demonstration(complete_prefetch_requests, completeness_tests, :complete)

        skip_if error_messages?,
                'The CRD client did not demonstrate both complete and subset prefetch capability. ' \
                'See Messages for details.'
      end

      def check_for_demonstration(requests, completeness_tests, target_name)
        unless requests.present?
          add_message('error', "No requests made to the service endpoint requesting #{target_name} prefetch data.")
          return
        end

        results_repo = Inferno::Repositories::Results.new
        results = results_repo.current_results_for_test_session_and_runnables(test_session_id,
                                                                              completeness_tests)
        output_name =
          if target_name == :subset
            'demonstrates_prefetch_subset_distinct_from_complete'
          else
            'demonstrates_prefetch_complete_distinct_from_subset'
          end

        demonstrated = results.any? do |result|
          result.outputs.any? do |output|
            output['name'] == output_name &&
              output['value'] == 'true'
          end
        end

        return if demonstrated

        add_message('error', "Requests made to the service endpoint requesting #{target_name} prefetch data " \
                             'did not demonstrate a difference between the two levels of prefetch data.')
      end
    end
  end
end
