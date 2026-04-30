module DaVinciCRDTestKit
  module RequestsLogicalModelValidation
    CRD_CDS_HOOK_REQUEST_MODEL_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksRequest'.freeze

    def validate_request_against_logical_model(request_body, request_index, ig_version)
      conforms_to_logical_model?(request_body, "#{CRD_CDS_HOOK_REQUEST_MODEL_URL}|#{ig_version}",
                                 message_prefix: "(Request #{request_index + 1}) ")
      perform_version_specific_additional_verification(request_body, request_index, ig_version)
    end

    private

    def perform_version_specific_additional_verification(request_body, request_index, ig_version)
      case ig_version
      when '2.2.1'
        perform_v221_additional_verification(request_body, request_index)
      end
    end

    def perform_v221_additional_verification(request_body, request_index)
      check_context_resources_for_ids(request_body, request_index)
    end

    # logical models don't explicitly check for resource ids
    def check_context_resources_for_ids(request_body, request_index)
      hook_name = request_body['hook']
      context = request_body['context']

      case hook_name
      when 'appointment-book'
        check_bundle_resources_for_ids(context['appointments'], request_index, 'appointments')
      when 'order-sign', 'order-select'
        check_bundle_resources_for_ids(context['draftOrders'], request_index, 'draftOrders')
      when 'order-dispatch'
        context['fulfillmentTasks']&.each_with_index do |task, index|
          check_resource_for_id(FHIR.from_contents(task.to_json), request_index, 'fulfillmentTasks', index)
        end
      end
    end

    def check_bundle_resources_for_ids(parsed_bundle, request_index, context_field_name)
      return unless parsed_bundle.present?

      bundle = FHIR.from_contents(parsed_bundle.to_json)
      return unless bundle.present?

      bundle.entry&.each_with_index do |entry, index|
        check_resource_for_id(entry.resource, request_index, context_field_name, index)
      end
    end

    def check_resource_for_id(resource, request_index, context_field_name, entry_index = nil)
      return if resource.present? && resource.id.present?

      message = "(Request #{request_index + 1}) " \
                'FHIR resources provided in the hook context must have an id, none found for ' \
                "`context.#{context_field_name}`#{" entry #{entry_index + 1}" if entry_index.present?}."
      add_message('error', message)
    end
  end
end
