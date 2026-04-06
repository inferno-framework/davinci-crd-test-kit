require_relative 'hook_request_field_validation'

module DaVinciCRDTestKit
  module SuggestionActionsValidation
    include HookRequestFieldValidation

    def action_fields_validation(action, ig_version: 'v201')
      action_required_fields.each do |field, type|
        validate_presence_and_type(action, field, type, 'Action')
      end

      action_type_field_validation(action, ig_version:)
    end

    def actions_check(actions, contexts = nil, ig_version: 'v201')
      create_actions_resource_types = extract_resource_types_by_action(actions, 'create')

      actions.each do |action|
        case action['type']
        when 'create', 'update'
          create_or_update_action_check(action, contexts, ig_version:)
        when 'delete'
          delete_action_check(action, create_actions_resource_types, contexts)
        end
      end
    end

    def action_resource_type_check(action, expected_resource_types)
      resource_type = if ['create', 'update'].include?(action['type'])
                        FHIR.from_contents(action['resource'].to_json)&.resourceType
                      else
                        action['resourceId']&.split('/')&.first
                      end
      expected_resource_types.include?(resource_type)
    end

    private

    def action_required_fields
      { 'type' => String, 'description' => String }
    end

    def action_type_field_validation(action, ig_version: 'v201')
      return unless action['type']

      allowed_types = ['create', 'update', 'delete']
      type = action['type']
      unless allowed_types.include?(type)
        error_msg = "Action type value `#{type}` is not allowed. Allowed values: #{allowed_types.to_sentence}. " \
                    "In Action `#{action}`"
        add_message('error', error_msg)
        return
      end

      if ['create', 'update'].include?(type)
        action_resource_field_validation(action, type)
      else
        action_resource_id_field_validation(action, ig_version:)
      end
    end

    def action_resource_field_validation(action, type)
      unless action['resource']
        add_message('error', "`Action.resource` must be present for `#{type}` actions: `#{action}`.")
        return
      end

      resource = FHIR.from_contents(action['resource'].to_json)
      return if resource

      add_message('error', "`Action.resource` must be a FHIR resource: `#{action}`.")
    end

    def action_resource_id_field_validation(action, ig_version: 'v201')
      validate_presence_and_type(action, 'resourceId', String, '`delete` Action')
      resource_reference_check(action['resourceId'], 'Action.resourceId', ig_version:)
    end

    def draft_orders_bundle_entry_refs(contexts)
      @draft_orders_bundle_entry_refs ||= contexts.flat_map do |context|
        draft_orders_bundle = parse_fhir_bundle_from_context('draftOrders', context)
        draft_orders_bundle.entry.map { |entry| "#{entry.resource.resourceType}/#{entry.resource.id}" }
      end
    end

    def extract_resource_types_by_action(actions, action_type)
      actions.each_with_object([]) do |act, resource_types|
        resource_types << act['resource']['resourceType'] if act['type'] == action_type
      end
    end

    def create_or_update_action_check(action, contexts, ig_version: 'v201')
      resource = FHIR.from_contents(action['resource'].to_json)
      resource_is_valid?(resource:, profile_url: structure_definition_map(ig_version)[resource.resourceType])
      return unless action['type'] == 'update' && contexts

      ref = "#{resource.resourceType}/#{resource.id}"
      return if draft_orders_bundle_entry_refs(contexts).include?(ref)

      error_msg = "Resource being updated must be from the `draftOrders` entry. #{ref} is not in the " \
                  "`context.draftOrders` of the submitted requests. In Action `#{action}`"
      add_message('error', error_msg)
    end

    def delete_action_check(action, create_actions_resource_types, contexts)
      ref = action['resourceId']
      unless draft_orders_bundle_entry_refs(contexts).include?(ref)
        error_msg = '`Action.resourceId` must reference FHIR resource from the `draftOrders` entry. ' \
                    "#{ref} is not in `draftOrders`. In Action `#{action}`"
        add_message('error', error_msg)
        return
      end

      resource_type = ref.split('/').first
      return if create_actions_resource_types.include?(resource_type)

      error_msg = "There's no `create` action for the proposed order being deleted: `#{ref}`. In Action `#{action}`"
      add_message('error', error_msg)
    end
  end
end
