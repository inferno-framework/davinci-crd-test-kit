require_relative 'logical_models_override_helper'

module DaVinciCRDTestKit
  module RequestsLogicalModelValidation
    include LogicalModelsOverrideHelper

    CRD_CDS_HOOK_REQUEST_MODEL_URL = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksRequest'.freeze
    USER_ID_ALLOWED_RESOURCE_TYPES = [
      'Practitioner', 'PractitionerRole', 'Patient', 'RelatedPerson'
    ].freeze

    PERFORMER_ALLOWED_RESOURCE_TYPES = [
      'Practitioner', 'PractitionerRole'
    ].freeze

    def validate_request_against_logical_model(request_body, request_index, ig_semver)
      if ig_semver == '2.2.1'
        check_logical_model_conformance_no_resource_checks(request_body, request_index, ig_semver)
      else
        conforms_to_logical_model?(request_body, "#{CRD_CDS_HOOK_REQUEST_MODEL_URL}|#{ig_semver}",
                                   message_prefix: "(Request #{request_index + 1}) ")
      end

      perform_version_specific_additional_verification(request_body, request_index, ig_semver)
    end

    private

    # -------------------------------------------------------------------------
    # Additional Validation to cover areas not checked or checked incorrectly by the logical models
    # -------------------------------------------------------------------------

    def perform_version_specific_additional_verification(request_body, request_index, ig_semver)
      case ig_semver
      when '2.2.1'
        perform_v221_additional_verification(request_body, request_index)
      end
    end

    def perform_v221_additional_verification(request_body, request_index)
      check_context_resources_for_ids(request_body, request_index)
      check_relative_references(request_body, request_index)
      check_context_resource_profiles(request_body, request_index, '2.2.1')
    end

    # -------------------------------------------------------------------------
    # Context resources profile check (not working in v2.2.1 logical models)
    # -------------------------------------------------------------------------

    def check_logical_model_conformance_no_resource_checks(request_body, request_index, ig_semver)
      validation_issues = []
      conforms_to_logical_model?(request_body, "#{CRD_CDS_HOOK_REQUEST_MODEL_URL}|#{ig_semver}",
                                 add_messages_to_runnable: false, validator_response_details: validation_issues)

      reject_resource_issues(validation_issues).each do |issue|
        next if issue.filtered

        add_message(issue.severity, "(Request #{request_index + 1}) #{issue.message}")
      end
    end

    def check_context_resource_profiles(request_body, request_index, ig_semver)
      case request_body['hook']
      when 'order-sign', 'order-select'
        draft_orders_conform_to_profiles?(request_body, request_index, ig_semver)
      when 'order-dispatch'
        request_body.dig('context', 'fulfillmentTasks')&.each_with_index do |task, index|
          resource = FHIR.from_contents(task.to_json)
          resource_is_valid?(resource:, profile_url: "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-task-dispatch|#{ig_semver}",
                             message_prefix: "(Request #{request_index + 1}) " \
                                             "context.fulfillmentTasks entry #{index + 1} - ")
        end
      when 'appointment-book'
        check_appointments_profiles(request_body, request_index, ig_semver)
      end
    rescue JSON::ParserError
      nil # no resource to validate - error found elsewhere
    end

    def draft_orders_conform_to_profiles?(request_body, request_index, ig_semver)
      resource = FHIR.from_contents(request_body.dig('context', 'draftOrders')&.to_json)
      resource_is_valid?(resource:, profile_url: "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-bundle-request|#{ig_semver}",
                         message_prefix: "(Request #{request_index + 1}) context.draftOrders - ")
    end

    # -------------------------------------------------------------------------
    # Appointment conformance (requires extra help to decide profile and check profile-based slicing)
    # -------------------------------------------------------------------------

    def check_appointments_profiles(request_body, request_index, ig_semver)
      resource = FHIR.from_contents(request_body.dig('context', 'appointments')&.to_json)
      return unless resource.is_a?(FHIR::Bundle)

      check_bundle_non_entry_resource_conformance(resource,
                                                  "(Request #{request_index + 1}) context.appointments - ",
                                                  ig_semver)

      resource.entry.each_with_index do |entry, entry_index|
        next unless entry.resource.present? # error caught on Bundle validation

        error_prefix = "(Request #{request_index + 1}) context.appointments entry #{entry_index + 1} - "
        check_appointment_conformance(entry.resource, request_body, error_prefix, ig_semver)
      end
    end

    def check_bundle_non_entry_resource_conformance(bundle, error_prefix, ig_semver)
      validation_issues = []
      resource_is_valid?(resource: bundle, profile_url: "http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-bundle-base|#{ig_semver}",
                         add_messages_to_runnable: false, validator_response_details: validation_issues)

      reject_entry_resource_issues(validation_issues).each do |issue|
        add_message(issue.severity, "#{error_prefix}#{issue.message}")
      end
    end

    def reject_entry_resource_issues(issues)
      issues.reject do |issue|
        issue.filtered || issue.location&.match?(/\ABundle\.entry\[\d+\]\.resource/)
      end
    end

    # -------------------------------------------------------------------------
    # Context relative reference checks
    # -------------------------------------------------------------------------

    # verify that context fields required to contain local references (resourceType/id)
    # do contain them and that the resourceType is in the list of expected types.
    def check_relative_references(request_body, request_index)
      # unless order-dispatch, check userId
      # if order-dispatch, check performer and dispatchedOrders list
      # if order-select, check selections

      if request_body['hook'] == 'order-dispatch'
        local_reference?(request_body['context']['performer'],
                         "(Request #{request_index + 1}) context.performer",
                         allowed_resource_types: PERFORMER_ALLOWED_RESOURCE_TYPES)
        request_body['context']['dispatchedOrders'].each_with_index do |order_reference, index|
          local_reference?(order_reference,
                           "(Request #{request_index + 1}) context.dispatchedOrders entry #{index + 1}",
                           allowed_resource_types: ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES)
        end
      else
        local_reference?(request_body['context']['userId'],
                         "(Request #{request_index + 1}) context.userId",
                         allowed_resource_types: USER_ID_ALLOWED_RESOURCE_TYPES)
        if request_body['hook'] == 'order-select'
          request_body['context']['selections'].each_with_index do |order_reference, index|
            error_prefix = "(Request #{request_index + 1}) context.selections entry #{index + 1}"
            next unless local_reference?(order_reference,
                                         error_prefix,
                                         allowed_resource_types: ProfilesAndResourceTypes::ORDER_RESOURCE_TYPES)

            referenced_resource_present_in_bundle?(request_body['context']['draftOrders'], order_reference,
                                                   error_prefix, 'draftOrders')
          end
        end
      end
    end

    # -------------------------------------------------------------------------
    # Context resources include ids
    # -------------------------------------------------------------------------

    # logical models don't explicitly check for resource ids
    def check_context_resources_for_ids(request_body, request_index)
      hook_name = request_body['hook']
      context = request_body['context']
      return unless context.present?

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
