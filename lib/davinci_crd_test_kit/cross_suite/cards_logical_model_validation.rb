require_relative 'cards_identification'

module DaVinciCRDTestKit
  module CardsLogicalModelValidation
    include DaVinciCRDTestKit::CardsIdentification

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

    def perform_cards_logical_model_validation(cards, system_actions, response_index = 0)
      if cards.is_a?(Array)
        cards.each_with_index do |card, card_index|
          validate_card_against_logical_model(card, response_index, card_index)
        end
      end

      return unless system_actions.is_a?(Array)

      system_actions.each_with_index do |action, action_index|
        validate_system_action_against_logical_model(action, response_index, action_index)
      end
    end

    def validate_card_against_logical_model(card, response_index, card_index)
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

      conforms_to_logical_model?({ 'cards' => [card] }, logical_model_url(profile_name),
                                 message_prefix: "#{label} (#{card_type || 'uncategorized'}): ")
    end

    def validate_system_action_against_logical_model(action, response_index, action_index)
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

      conforms_to_logical_model?({ 'systemActions' => [action] }, logical_model_url(profile_name),
                                 message_prefix: "#{label} (#{action_type || 'uncategorized'}): ")
    end

    def logical_model_entity_label(response_index, entity_index, kind)
      "Server response #{response_index + 1} #{kind} #{entity_index + 1}"
    end
  end
end
