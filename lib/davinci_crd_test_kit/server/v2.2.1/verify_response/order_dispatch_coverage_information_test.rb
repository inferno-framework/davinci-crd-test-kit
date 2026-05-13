require_relative 'all_responses_include_coverage_information_test'

module DaVinciCRDTestKit
  module V221
    class OrderDispatchCoverageInformationTest < AllResponsesIncludeCoverageInformationTest
      id :crd_v221_order_dispatch_coverage_information

      input :invoked_hook

      input :mock_ehr_bundle

      def resource_matches_reference?(reference, resource)
        reference.resource_type == resource.resourceType && reference.reference_id == resource.id
      end

      def mock_ehr_bundle_resources
        FHIR.from_contents(mock_ehr_bundle)
          .entry
          .map(&:resource)
      end

      def prefetch_resources(hook_call_body)
        (hook_call_body['prefetch'] || {})
          .values
          .compact
          .map { |resource_hash| FHIR.from_contents(resource_hash.to_json) }
          .flat_map do |resource|
          if resource.is_a? FHIR::Bundle
            resource.entry.map(&:resource)
          else
            resource
          end
        end
      end

      def order_resources(hook_call_body)
        references =
          hook_call_body
            .dig('context', 'dispatchedOrders')
            .map { |reference| FHIR::Reference.new(reference:) }

        resources =
          (mock_ehr_bundle_resources + prefetch_resources(hook_call_body))
            .select do |resource|
              references.any? { |reference| resource_matches_reference?(reference, resource) }
            end

        unmatched_references =
          references.reject do |reference|
            resources.any? { |resource| resource_matches_reference?(reference, resource) }
          end

        skip_if unmatched_references.present?,
                'The following `dispatchedOrders` are not included in the Mock EHR Data input or prefetch: ' \
                "#{unmatched_references.map(&:reference).join(', ')}"

        resources
      end
    end
  end
end
