module DaVinciCRDTestKit
  module V221
    module HookRequestResourceResolution
      def mock_ehr_bundle_resource
        @mock_ehr_bundle_resource ||= JSON.parse(mock_ehr_bundle) if mock_ehr_bundle.present?
      rescue JSON::ParserError
        nil
      end

      def matching_request_for_action(action)
        requests.find do |request|
          response = JSON.parse(request.response_body)
          request.status == 200 && Array(response['systemActions']).any? { |candidate| candidate == action }
        rescue JSON::ParserError
          false
        end
      end

      # Resolve the original resource being updated by a systemAction.
      # - appointment-book: look in context.appointments; if the action targets a ServiceRequest,
      #   follow the Appointment basedOn reference and resolve that from prefetch or mock EHR data
      # - order-sign/order-select: look in context.draftOrders
      # - other hooks: resolve from prefetch or mock EHR data because context may carry only ids/references
      def find_action_source_resource(action, request)
        action_resource = action['resource']
        return unless action_resource.is_a?(Hash)

        target_type = action_resource['resourceType']
        target_id = action_resource['id']
        request_body = parse_request_body(request)
        return unless target_type.present? && target_id.present? && request_body

        hook_context_resource(request_body, target_type, target_id) ||
          fallback_source_resource(request_body, target_type, target_id)
      end

      def find_appointment_book_resource(request_body, target_type, target_id)
        appointments_bundle = request_body.dig('context', 'appointments')
        find_resource_in_bundle(appointments_bundle, target_type, target_id) ||
          appointment_book_service_request(request_body, appointments_bundle, target_id)
      end

      def find_draft_orders_resource(request_body, target_type, target_id)
        draft_orders_bundle = request_body.dig('context', 'draftOrders')
        find_resource_in_bundle(draft_orders_bundle, target_type, target_id)
      end

      def fallback_source_resource(request_body, target_type, target_id)
        find_resource_in_prefetch(request_body, target_type, target_id) ||
          find_resource_in_bundle(mock_ehr_bundle_resource, target_type, target_id)
      end

      def hook_context_resource(request_body, target_type, target_id)
        case tested_hook_name
        when 'appointment-book'
          find_appointment_book_resource(request_body, target_type, target_id)
        when 'order-sign', 'order-select'
          find_draft_orders_resource(request_body, target_type, target_id)
        end
      end

      def appointment_book_service_request(request_body, appointments_bundle_hash, target_id)
        target_type = 'ServiceRequest'
        appointments_bundle = parse_bundle(appointments_bundle_hash)
        appointment = (appointments_bundle&.entry || [])
          .filter_map(&:resource)
          .find { |candidate| appointment_based_on_matches_target?(candidate, target_type, target_id) }
        return unless appointment

        find_resource_in_prefetch(request_body, target_type, target_id) ||
          find_resource_in_bundle(mock_ehr_bundle_resource, target_type, target_id)
      end

      def appointment_based_on_matches_target?(appointment, target_type, target_id)
        Array(appointment.basedOn).any? do |reference|
          reference_parts(reference.reference) == [target_type, target_id]
        end
      end

      def find_resource_in_prefetch(request_body, target_type, target_id)
        Array(request_body['prefetch']&.values).each do |prefetched_value|
          if prefetched_value.is_a?(Hash) &&
             prefetched_value['resourceType'] == target_type &&
             prefetched_value['id'] == target_id
            return FHIR.from_contents(prefetched_value.to_json)
          end

          resource = find_resource_in_bundle(prefetched_value, target_type, target_id)
          return resource if resource
        end

        nil
      end

      def find_resource_by_reference(request_body, reference)
        target_type, target_id = reference_parts(reference)
        return unless target_type.present? && target_id.present?

        find_resource_in_prefetch(request_body, target_type, target_id) ||
          find_resource_in_bundle(mock_ehr_bundle_resource, target_type, target_id)
      end

      def find_resource_in_bundle(bundle_hash, target_type, target_id)
        bundle = parse_bundle(bundle_hash)
        return unless bundle&.entry

        bundle.entry
          .filter_map(&:resource)
          .find { |resource| resource.resourceType == target_type && resource.id == target_id }
      end

      def reference_parts(reference)
        return if reference.blank?

        parts = reference.split('/')
        return unless parts.length >= 2

        [parts[-2], parts[-1]]
      end

      def parse_bundle(bundle_hash)
        bundle = FHIR.from_contents(bundle_hash.to_json)
        bundle if bundle.is_a?(FHIR::Bundle)
      rescue StandardError
        nil
      end

      def parse_request_body(request)
        return unless request&.request_body.present?

        JSON.parse(request.request_body)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
