require_relative 'server_hook_request_validation'
require_relative 'suggestion_actions_validation'

module DaVinciCRDTestKit
  module CardsIdentification
    include DaVinciCRDTestKit::SuggestionActionsValidation
    include DaVinciCRDTestKit::ServerHookRequestValidation

    ADDITIONAL_ORDERS_RESPONSE_TYPE = 'companions_prerequisites'.freeze
    COVERAGE_INFORMATION_RESPONSE_TYPE = 'coverage_information'.freeze
    CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE = 'create_update_coverage_info'.freeze
    EXTERNAL_REFERENCE_RESPONSE_TYPE = 'external_reference'.freeze
    FORM_COMPLETION_RESPONSE_TYPE = 'request_form_completion'.freeze
    INSTRUCTIONS_RESPONSE_TYPE = 'instructions'.freeze
    LAUNCH_SMART_APP_RESPONSE_TYPE = 'launch_smart_app'.freeze
    PROPOSE_ALTERNATIVE_REQUEST_RESPONSE_TYPE = 'propose_alternate_request'.freeze

    ADDITIONAL_ORDERS_EXPECTED_RESOURCE_TYPES = %w[
      CommunicationRequest Device DeviceRequest Medication
      MedicationRequest NutritionOrder ServiceRequest
      VisionPrescription
    ].freeze

    PROPOSE_ALTERNATIVE_REQUEST_EXPECTED_RESOURCE_TYPES = %w[
      Device DeviceRequest Encounter Medication
      MedicationRequest NutritionOrder ServiceRequest
      VisionPrescription
    ].freeze

    def identify_card_type(card) # rubocop:disable Metrics/CyclomaticComplexity
      return nil if card['type'].present? # action, not a card
      return ADDITIONAL_ORDERS_RESPONSE_TYPE if additional_orders_response_type?(card)
      return CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE if create_or_update_coverage_card_response_type?(card)
      return EXTERNAL_REFERENCE_RESPONSE_TYPE if external_reference_response_type?(card)
      return FORM_COMPLETION_RESPONSE_TYPE if form_completion_card_response_type?(card)
      return INSTRUCTIONS_RESPONSE_TYPE if instructions_response_type?(card)
      return LAUNCH_SMART_APP_RESPONSE_TYPE if launch_smart_app_response_type?(card)
      return PROPOSE_ALTERNATIVE_REQUEST_RESPONSE_TYPE if propose_alternative_request_response_type?(card)

      nil
    end

    def identify_action_type(action)
      return nil unless action['type'].present? # card, not an action
      return COVERAGE_INFORMATION_RESPONSE_TYPE if coverage_information_response_type?(action)
      return CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE if create_or_update_coverage_action_response_type?(action)
      return FORM_COMPLETION_RESPONSE_TYPE if form_completion_action_response_type?(action)

      nil
    end

    def additional_orders_response_type?(card, expected_resource_types: ADDITIONAL_ORDERS_EXPECTED_RESOURCE_TYPES)
      card['suggestions']&.all? do |suggestion|
        actions = suggestion['actions']
        actions&.all? do |action|
          action['type'] == 'create' &&
            (expected_resource_types.blank? || action_resource_type_check(action, expected_resource_types))
        end
      end
    end

    def coverage_information_response_type?(action)
      coverage_info_ext_url = 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'
      action.dig('resource', 'extension')&.any? { |extension| extension['url'] == coverage_info_ext_url }
    end

    def create_or_update_coverage_card_response_type?(card)
      card['suggestions']&.one? && card['suggestions'].first['actions']&.one? do |action|
        create_or_update_coverage_action_response_type?(action)
      end
    end

    def create_or_update_coverage_action_response_type?(action)
      ['create', 'update'].include?(action['type']) && action_resource_type_check(action, ['Coverage'])
    end

    def external_reference_response_type?(card)
      card['links']&.all? { |link| link['type'] == 'absolute' }
    end

    def form_completion_card_response_type?(card)
      card['suggestions']&.all? do |suggestion|
        suggestion['actions'].one? { |action| form_completion_action_response_type?(action) }
      end
    end

    def form_completion_action_response_type?(action)
      action['type'] == 'create' &&
        action_resource_type_check(action, ['Task']) &&
        form_completion_task_questionnaire?(action['resource'])
    end

    def form_completion_task_questionnaire?(task_action)
      task_action.dig('code', 'coding')&.any? { |code| code['code'] == 'complete-questionnaire' } &&
        task_action['input']&.any? do |input|
          input.dig('type', 'text') == 'questionnaire' && valid_url?(input['valueCanonical'])
        end
    end

    def instructions_response_type?(card)
      card['links'].blank? && card['suggestions'].blank?
    end

    def launch_smart_app_response_type?(card)
      card['links']&.all? { |link| link['type'] == 'smart' }
    end

    def propose_alternative_request_response_type?(
      card,
      expected_resource_types: PROPOSE_ALTERNATIVE_REQUEST_EXPECTED_RESOURCE_TYPES
    )
      card['suggestions']&.any? do |suggestion|
        actions = suggestion['actions']
        has_update = check_action_type(actions, 'update', expected_resource_types)
        has_delete = check_action_type(actions, 'delete', expected_resource_types)
        has_create = check_action_type(actions, 'create', expected_resource_types)

        has_update || (has_delete && has_create)
      end
    end

    def check_action_type(actions, action_type, expected_resource_types)
      actions&.any? do |action|
        action['type'] == action_type &&
          (expected_resource_types.blank? || action_resource_type_check(action, expected_resource_types))
      end
    end

    def list_card_types_in_requests(hooks_requests)
      sorted_cards = identify_card_types_from_hooks_invocations(hooks_requests)

      present_card_types = sorted_cards['cards'].select { |key, value| key.present? && value.present? }.keys
      present_action_types = sorted_cards['actions'].select { |key, value| key.present? && value.present? }.keys

      present_card_types.map { |type| "#{type}_card" } + present_action_types.map { |type| "#{type}_action" }
    end

    def identify_card_types_from_hooks_invocations(hooks_requests)
      sorted_cards = initialize_sorted_cards_hash

      hooks_requests.each do |request|
        sort_card_types_from_request(request, sorted_cards)
      rescue JSON::ParserError
        next
      end

      sorted_cards
    end

    def sort_card_types_from_request(request, sorted_cards)
      response_body = JSON.parse(request.response_body)
      response_body['cards']&.each do |card|
        sorted_cards['cards'][identify_card_type(card)] << card
      end

      response_body['systemActions']&.each do |action|
        sorted_cards['actions'][identify_action_type(action)] << action
      end
    end

    def initialize_sorted_cards_hash
      {
        'cards' => {
          ADDITIONAL_ORDERS_RESPONSE_TYPE => [],
          CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE => [],
          EXTERNAL_REFERENCE_RESPONSE_TYPE => [],
          FORM_COMPLETION_RESPONSE_TYPE => [],
          INSTRUCTIONS_RESPONSE_TYPE => [],
          LAUNCH_SMART_APP_RESPONSE_TYPE => [],
          PROPOSE_ALTERNATIVE_REQUEST_RESPONSE_TYPE => [],
          nil => [] # unknown type
        },
        'actions' => {
          COVERAGE_INFORMATION_RESPONSE_TYPE => [],
          CREATE_OR_UPDATE_COVERAGE_RESPONSE_TYPE => [],
          FORM_COMPLETION_RESPONSE_TYPE => [],
          nil => [] # unknown type
        }
      }
    end
  end
end
