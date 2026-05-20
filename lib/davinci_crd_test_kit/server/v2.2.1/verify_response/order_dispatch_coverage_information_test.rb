require_relative 'all_responses_include_coverage_information_test'
require_relative 'hook_request_resource_resolution'

module DaVinciCRDTestKit
  module V221
    class OrderDispatchCoverageInformationTest < AllResponsesIncludeCoverageInformationTest
      include HookRequestResourceResolution

      id :crd_v221_order_dispatch_coverage_information

      input :invoked_hook

      input :mock_ehr_bundle

      def order_resources(hook_call_body)
        references = hook_call_body.dig('context', 'dispatchedOrders')
        resources = []
        unmatched_references = []

        Array(references).each do |reference|
          resource = find_resource_by_reference(hook_call_body, reference)

          if resource.present?
            resources << resource
          else
            unmatched_references << reference
          end
        end

        skip_if unmatched_references.present?,
                'The following `dispatchedOrders` are not included in the Mock EHR Data input or prefetch: ' \
                "#{unmatched_references.join(', ')}"

        resources
      end
    end
  end
end
