require_relative '../../../cross_suite/hook_request_resource_extraction'
require_relative '../../../cross_suite/profiles_and_resource_types'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class ClientOrderTypesSignedTest < Inferno::Test
      include HookRequestResourceExtraction

      title 'Order types observed were signed through the order-sign hook'
      id :crd_v221_client_order_types_signed
      description <<~DESCRIPTION
        CRD clients are required to support the `order-sign` hook for the order types they handle.
        During this test, Inferno checks that every order type it observed appeared as a
        `draftOrder` on an `order-sign` invocation.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@hook-3'

      def requests_repo
        @requests_repo ||= Inferno::Repositories::Requests.new
      end

      # Reads the requests directly rather than going through `load_tagged_requests`, which would
      # also associate every cross hook request with this test's own result.
      def tagged_requests(*tags)
        requests_repo.tagged_requests(test_session_id, tags)
      end

      # The hooks each order type was seen on, so that an unsigned type can say where it did turn up
      # rather than only where it did not.
      def hooks_by_order_type
        tagged_requests(CROSS_HOOK_ANALYSIS_TAG).each_with_object({}) do |request, hooks|
          request_body = parse_request_body(request)
          hook = request_body&.dig('hook')

          each_hook_request_resource(request_body) do |raw_resource|
            resource_type = raw_resource['resourceType']
            next unless ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES.include?(resource_type)

            (hooks[resource_type] ||= Set.new) << hook if hook.present?
          end
        end
      end

      # Only the draftOrders bundle counts, since that is where an order-sign invocation carries the
      # orders being signed. The same resource elsewhere in the request does not demonstrate signing.
      def signed_order_types
        tagged_requests(ORDER_SIGN_TAG, CROSS_HOOK_ANALYSIS_TAG).each_with_object(Set.new) do |request, types|
          draft_orders = parse_request_body(request)&.dig('context', 'draftOrders')

          each_resource_within(draft_orders) do |raw_resource|
            resource_type = raw_resource['resourceType']
            types << resource_type if ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES.include?(resource_type)
          end
        end
      end

      # An order type can turn up on an order-sign request without being in its `draftOrders`, so the
      # hook is named only where it does not contradict the finding.
      def unsigned_message(resource_type, hooks)
        elsewhere = Array(hooks&.to_a) - ['order-sign']
        if elsewhere.blank?
          return "There was an instance of `#{resource_type}` that was observed, but not as a draft order on " \
                 'an `order-sign` invocation. All order types must be signed as a draft order on an ' \
                 'order-sign hook invocation.'
        end

        "There was an instance of `#{resource_type}` that was observed on the " \
          "#{elsewhere.sort.map { |hook| "`#{hook}`" }.to_sentence} " \
          "#{'hook'.pluralize(elsewhere.length)}, but not on an `order-sign` invocation. All order " \
          'types must be signed as a draft order on an order-sign hook invocation.'
      end

      run do
        observed_hooks = hooks_by_order_type
        observed = observed_hooks.keys
        skip_if observed.blank?, 'No order resources were found in the hook requests received.'

        unsigned = observed - signed_order_types.to_a

        unsigned.each do |resource_type|
          add_message('error', unsigned_message(resource_type, observed_hooks[resource_type]))
        end

        assert unsigned.blank?,
               "#{unsigned.length} of the #{observed.length} order type(s) observed were never signed: " \
               "#{unsigned.join(', ')}."

        pass "All #{observed.length} order type(s) observed were signed: #{observed.join(', ')}."
      end
    end
  end
end
