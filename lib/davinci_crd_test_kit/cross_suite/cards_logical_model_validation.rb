require_relative 'cards_identification'
require_relative 'logical_models_override_helper'

module DaVinciCRDTestKit
  module CardsLogicalModelValidation
    include DaVinciCRDTestKit::CardsIdentification
    include LogicalModelsOverrideHelper

    CRD_LOGICAL_MODEL_BASE = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition'.freeze
    CRD_RESPONSE_BASE_LOGICAL_MODEL = 'CRDHooksResponseBase'.freeze

    CARD_TYPE_TO_LOGICAL_MODEL = {
      DaVinciCRDTestKit::CardsIdentification::ADDITIONAL_ORDERS_RESPONSE_TYPE =>
        'CRDHooksResponse-additionalOrders',
      DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE =>
        'CRDHooksResponse-adjustCoverage',
      DaVinciCRDTestKit::CardsIdentification::EXTERNAL_REFERENCE_RESPONSE_TYPE =>
        'CRDHooksResponse-externalReference',
      DaVinciCRDTestKit::CardsIdentification::FORM_COMPLETION_RESPONSE_TYPE =>
        'CRDHooksResponse-formCompletion',
      DaVinciCRDTestKit::CardsIdentification::INSTRUCTIONS_RESPONSE_TYPE =>
        'CRDHooksResponse-instructions',
      DaVinciCRDTestKit::CardsIdentification::LAUNCH_SMART_APP_RESPONSE_TYPE =>
        'CRDHooksResponse-launchSMART',
      DaVinciCRDTestKit::CardsIdentification::PROPOSE_ALTERNATIVE_REQUEST_RESPONSE_TYPE =>
        'CRDHooksResponse-alternateRequest'
    }.freeze

    ACTION_TYPE_TO_LOGICAL_MODEL = {
      DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFORMATION_RESPONSE_TYPE =>
        'CRDHooksResponse-coverageInformation',
      DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE =>
        'CRDHooksResponse-adjustCoverage',
      DaVinciCRDTestKit::CardsIdentification::FORM_COMPLETION_RESPONSE_TYPE =>
        'CRDHooksResponse-formCompletion'
    }.freeze

    def logical_model_url(profile_name)
      "#{CRD_LOGICAL_MODEL_BASE}/#{profile_name}"
    end

    def perform_cards_logical_model_validation(cards, system_actions, request_body, response_index, ig_version)
      if cards.is_a?(Array)
        cards.each_with_index do |card, card_index|
          validate_card_against_logical_model(card, response_index, request_body, card_index, ig_version)
        end
      end

      return unless system_actions.is_a?(Array)

      system_actions.each_with_index do |action, action_index|
        validate_system_action_against_logical_model(action, response_index, request_body, action_index, ig_version)
      end
    end

    def validate_card_against_logical_model(card, response_index, request_body, card_index, ig_version)
      label = logical_model_entity_label(response_index, card_index, 'card')
      unless card.is_a?(Hash)
        add_message('error', "#{label} is not a JSON object; skipping logical model validation.")
        return
      end

      card_type = identify_card_type(card)
      profile_name = CARD_TYPE_TO_LOGICAL_MODEL[card_type]
      unless profile_name
        add_message('warning',
                    "#{label} could not be categorized as a known CRD response type; " \
                    'validating against the base CRD response logical model.')
        profile_name = CRD_RESPONSE_BASE_LOGICAL_MODEL
      end

      validation_issues = []
      conforms_to_logical_model?({ 'cards' => [card] }, logical_model_url(profile_name),
                                 add_messages_to_runnable: false, validator_response_details: validation_issues)

      error_prefix = "#{label} (#{card_type || 'uncategorized'}): "
      filtered_issues = filter_and_manually_check_card_specific_errors(card, validation_issues, card_type,
                                                                       request_body, error_prefix, ig_version)
      add_filtered_messages(filtered_issues, error_prefix)
    end

    def validate_system_action_against_logical_model(action, response_index, request_body, action_index, ig_version)
      label = logical_model_entity_label(response_index, action_index, 'systemAction')
      unless action.is_a?(Hash)
        add_message('error', "#{label} is not a JSON object; skipping logical model validation.")
        return
      end

      action_type = identify_action_type(action)
      profile_name = ACTION_TYPE_TO_LOGICAL_MODEL[action_type]
      unless profile_name
        add_message('warning',
                    "#{label} could not be categorized as a known CRD response type; " \
                    'validating against the base CRD response logical model.')
        profile_name = CRD_RESPONSE_BASE_LOGICAL_MODEL
      end
      if [DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE,
          DaVinciCRDTestKit::CardsIdentification::FORM_COMPLETION_RESPONSE_TYPE]
          .include?(action_type)
        profile_name = CRD_RESPONSE_BASE_LOGICAL_MODEL
      end

      validation_issues = []
      conforms_to_logical_model?({ 'systemActions' => [action] }, logical_model_url(profile_name),
                                 add_messages_to_runnable: false, validator_response_details: validation_issues)

      error_prefix = "#{label} (#{action_type || 'uncategorized'}): "
      filtered_issues = filter_and_manually_check_action_specific_errors(action, validation_issues, action_type,
                                                                         request_body, error_prefix, ig_version)
      add_filtered_messages(filtered_issues, error_prefix)
    end

    def add_filtered_messages(issues, error_prefix)
      issues.each do |issue|
        next if issue.filtered || logical_model_extension_issue?(issue)

        add_message(issue.severity, "#{error_prefix}#{issue.message}")
      end
    end

    def logical_model_entity_label(response_index, entity_index, kind)
      "Server response #{response_index + 1} #{kind} #{entity_index + 1}"
    end

    # -------------------------------------------------------------------------
    # Validator Filtering and Manual Checks Depending on the Card Type
    # -------------------------------------------------------------------------

    def logical_model_extension_issue?(issue)
      issue.message.match(/\.extension: Unrecognized property/).present?
    end

    def filter_and_manually_check_card_specific_errors(card, validation_issues, card_type, request_body, error_prefix,
                                                       ig_version)
      case card_type
      when DaVinciCRDTestKit::CardsIdentification::FORM_COMPLETION_RESPONSE_TYPE
        filter_and_manually_check_form_completion_errors(card, validation_issues, error_prefix)
      when DaVinciCRDTestKit::CardsIdentification::PROPOSE_ALTERNATIVE_REQUEST_RESPONSE_TYPE
        filter_and_manually_check_propose_alternative_errors(card, validation_issues, request_body,
                                                             error_prefix, ig_version)
      when DaVinciCRDTestKit::CardsIdentification::ADDITIONAL_ORDERS_RESPONSE_TYPE
        filter_and_manually_check_additional_orders_errors(card, validation_issues, request_body,
                                                           error_prefix, ig_version)
      else
        validation_issues
      end
    end

    def filter_and_manually_check_action_specific_errors(action, validation_issues, action_type, request_body,
                                                         error_prefix, ig_version)
      case action_type
      when DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFORMATION_RESPONSE_TYPE
        filter_and_manually_check_coverage_information_errors(action, validation_issues, request_body,
                                                              error_prefix, ig_version)
      when DaVinciCRDTestKit::CardsIdentification::CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE
        filter_and_manually_check_update_coverage_action_errors(action, validation_issues,
                                                                error_prefix, ig_version)
      when DaVinciCRDTestKit::CardsIdentification::FORM_COMPLETION_RESPONSE_TYPE
        filter_and_manually_check_form_completion_action_errors(action, validation_issues,
                                                                error_prefix, ig_version)
      else
        validation_issues
      end
    end

    def filter_and_manually_check_form_completion_errors(card, validation_issues, error_prefix)
      validation_issues.reject do |issue|
        if issue.message.match?(/The type 'Questionnaire' is not valid - must be Task/)
          check_questionnaire_actions(card, issue.message, error_prefix)
          true
        else
          false
        end
      end
    end

    def check_questionnaire_actions(card, error_message, error_prefix)
      extracted_indexes =
        error_message.match(/CDSHooksResponse\.cards\[0\]\.suggestions\[(\d+)\]\.actions\[(\d+)\]\.resource/)
      unless extracted_indexes
        raise 'Unexpected validator error message format in check_questionnaire_actions: ' \
              "'#{error_message}'. This indicates an implementation problem in the test kit — please log a ticket."
      end

      suggestion_index = extracted_indexes[1].to_i
      action_index = extracted_indexes[2].to_i

      message_prefix = "#{error_prefix} Suggestion #{suggestion_index + 1} Actions #{action_index + 1} - "
      resource = FHIR.from_contents(card['suggestions'][suggestion_index]['actions'][action_index]['resource'].to_json)
      resource_is_valid?(resource:, message_prefix:) # no questionnaire profile applied per CRD

      return if resource.id.present?

      add_message('error', "#{message_prefix}Questionnaire must have an id.")
    end

    def filter_and_manually_check_propose_alternative_errors(card, validation_issues, request_body,
                                                             error_prefix, ig_version)
      no_resource_issues = manually_check_action_resources_for_order_profile_conformance(card,
                                                                                         validation_issues,
                                                                                         request_body,
                                                                                         error_prefix,
                                                                                         ig_version)
      no_resource_issues.reject do |issue|
        issue.message.match?(/but is fixed to 'create' in the profile/)
      end
    end

    def filter_and_manually_check_additional_orders_errors(card, validation_issues, request_body,
                                                           error_prefix, ig_version)
      manually_check_action_resources_for_order_profile_conformance(card,
                                                                    validation_issues,
                                                                    request_body,
                                                                    error_prefix,
                                                                    ig_version)
    end

    def manually_check_action_resources_for_order_profile_conformance(card, validation_issues, request_body,
                                                                      error_prefix, ig_version)
      if card['suggestions'].present?
        card['suggestions'].each_with_index do |suggestion, suggestion_index|
          next unless suggestion['actions'].present?

          suggestion['actions'].each_with_index do |action, action_index|
            action_error_prefix = "#{error_prefix}Suggestion #{suggestion_index + 1}, Action #{action_index + 1} - "
            check_action_target(action, request_body, action_error_prefix, ig_version)
          end
        end
      end

      reject_filtered_and_resource_issues(validation_issues)
    end

    def check_action_target(action, request_body, error_prefix, ig_version)
      local_reference?(action['resourceId'], error_prefix) if action['resourceId'].present?
      return unless action['resource'].present?

      check_resource_conformance_to_order_profile(action['resource'], request_body, error_prefix, ig_version)
    end

    def filter_and_manually_check_coverage_information_errors(action, validation_issues, request_body,
                                                              error_prefix, ig_version)
      if action['resource'].present?
        check_resource_conformance_to_order_or_encounter_profile(action['resource'], request_body,
                                                                 error_prefix, ig_version)
      end

      validation_issues.filter do |issue|
        issue.message.match(%r{CDSHooksResponse\.systemActions\[0\]\.resource/[A-Za-z]+/})
      end
    end

    def filter_and_manually_check_update_coverage_action_errors(action, validation_issues,
                                                                error_prefix, ig_version)
      unless action['type'] == 'update'
        add_message('error', "#{error_prefix}action type must be 'update' for a coverage update action response type.")
      end

      if action['resource'].present?
        check_resource_conformance_to_coverage_profile(action['resource'], error_prefix, ig_version)
      end

      validation_issues.filter do |issue|
        issue.message.match(%r{CDSHooksResponse\.systemActions\[0\]\.resource/[A-Za-z]+/})
      end
    end

    def filter_and_manually_check_form_completion_action_errors(action, validation_issues,
                                                                error_prefix, ig_version)
      unless action['type'] == 'create'
        add_message('error', "#{error_prefix}action type must be 'create' for a form completion action response type.")
      end

      if action['resource'].present?
        check_resource_conformance_to_questionnaire_task_profile(action['resource'], error_prefix, ig_version)
      end

      validation_issues.filter do |issue|
        issue.message.match(%r{CDSHooksResponse\.systemActions\[0\]\.resource/[A-Za-z]+/})
      end
    end
  end
end
