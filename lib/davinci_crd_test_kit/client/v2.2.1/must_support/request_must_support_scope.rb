require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    # The hook requests the request must support tests look at, and the resource types the tester
    # declared the CRD client supports.
    module RequestMustSupportScope
      DECLARED_UNSUPPORTED_REASON =
        'the tester indicated that the CRD client does not support this resource type'.freeze

      # Reads the requests directly rather than going through `load_tagged_requests`, which would
      # also associate every cross hook request with this test's own result. Only the relevant ones
      # are associated, by `associate_requests`.
      def must_support_requests
        @must_support_requests ||=
          Inferno::Repositories::Requests.new.tagged_requests(test_session_id, [CROSS_HOOK_ANALYSIS_TAG])
      end

      def profile_resource_types
        config.options[:profiles].map { |profile| profile[:resource_type] }
      end

      # Attaches the requests that carried the resource types under test to this test's result so
      # the tester can see what was considered. When none did, every considered request is attached,
      # since together they are the evidence that the types were absent.
      def associate_requests(relevant_requests)
        requests.concat(relevant_requests.presence || must_support_requests)
      end

      # nil when the type is required of every CRD client, so no input governs it. A CRD client need not
      # support any order type, so clearing every box means none are expected rather than all.
      def selected_types(resource_type)
        if ClientCrossHookMustSupportGroup::ORDER_TYPE_OPTIONS.any? { |one| one[:value] == resource_type }
          Array(order_types_supported)
        elsif ClientCrossHookMustSupportGroup::SUPPORTING_TYPE_OPTIONS.any? { |one| one[:value] == resource_type }
          Array(supporting_types_supported)
        end
      end

      def declared_unsupported?(resource_type)
        selected_types(resource_type)&.exclude?(resource_type) || false
      end

      # A type is expected unless the tester deselected it; a type no input governs is required of
      # every CRD client. Deselecting a type whose hook was invoked is caught separately, by the must
      # support element tests, as a contradiction.
      def expected?(resource_type)
        !declared_unsupported?(resource_type)
      end

      def required_of_every_client?(resource_type)
        selected_types(resource_type).nil?
      end

      def missing_type_message(resource_type)
        reason = if required_of_every_client?(resource_type)
                   'CRD clients are required to support'
                 else
                   'The tester indicated the CRD client supports'
                 end

        "#{reason} the `#{resource_type}` resource type, but no instances were observed in the hook requests made."
      end
    end
  end
end
