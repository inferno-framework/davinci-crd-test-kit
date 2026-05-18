require_relative '../../tagged_request_load_helper'
require_relative '../client_urls'

module DaVinciCRDTestKit
  module V221
    class ClientPrefetchCompleteAndSubsetTest < Inferno::Test
      include TaggedRequestLoadHelper

      title 'Client can provide both the complete standard prefetch data set and a subset'
      id :crd_v221_client_prefetch_complete_and_subset
      description <<~DESCRIPTION
        The CRD IG requires clients to be able to prefetch a standard set of resources that
        payers are expected to need to evaluate coverage requirements. They are also
        required to be able to prefetch a subset of these standard prefetch requirements
        if a payer requests fewer in their service discovery responses because the payer
        does not always need the complete set of standard prefetch resources to evaluate
        coverage.

        During this test, Inferno will verify that the client has demonstrated requests
        - made against both of Inferno's simulated CRD servers,
          one of which requests the all standard prefetch resources while the
          other requests only a subset.
        - which demonstrate the capability to distinguish the difference between
          the two prefetch sets.

        The CRD server that requests only a subset of the standard prefetch data does not request
        resources referenced from the following elements. Request made to each Inferno service
        endpoint with one of these elements populated with a reference to a resource not referenced
        elsewhere will demonstrate the required capability.
          - On an `appointment-book` hook request, an Appointment with a participant entry that
            references a Practitioner or PractitionerRole resource in its actor element
          - On an `encounter-start` or `encounter-discharge` hook request, an Encounter with a
            referenced Location via the `location` element or referenced Organization via the
            `serviceProvider` element.
          - On an `order-select`, `order-sign`, or `order-dispatch` hook request, one of the following order resources:
            - A CommunicationRequest, DeviceRequest, MedicationRequest, or ServiceRequest that references a Practitioner or PractitionerRole resource in its `requester` element, or
            - A NutritionOrder that references a Practitioner or PractitionerRole resource in its `orderer` element
            - A VisionPrescription that references a Practitioner or PractitionerRole resource in its `prescriber` element

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
          requests_to_analyze.partition { |request| request.url.include?(PREFETCH_SUBSET_PREFIX) }
        completeness_tests = find_completeness_tests
        check_for_demonstration(subset_prefetch_requests, completeness_tests, :subset)
        check_for_demonstration(complete_prefetch_requests, completeness_tests, :complete)

        skip_if error_messages?,
                'The client did not demonstrate both complete and subset prefetch capability. See Messages for details.'
      end

      def find_completeness_tests
        hooks_group = self.class.parent.parent.groups.find do |group|
          group.id.to_s.include?('crd_v221_client_hooks')
        end
        hooks_group.groups.map do |group|
          group.groups.flat_map(&:tests).find do |test|
            test.id.to_s.include?('crd_v221_hook_request_prefetch_complete')
          end
        end.compact
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
